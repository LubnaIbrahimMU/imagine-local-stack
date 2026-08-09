import json
import logging
import os
import socket
from contextlib import contextmanager
from datetime import datetime

import mysql.connector
import redis
import boto3
from botocore.exceptions import ClientError
from flask import Flask, jsonify, request
from mysql.connector import Error
from prometheus_flask_exporter import PrometheusMetrics


# Sourced Vault credentials if injected at /vault/secrets/db-config
VAULT_SECRET_PATH = "/vault/secrets/db-config"
if os.path.exists(VAULT_SECRET_PATH):
    try:
        with open(VAULT_SECRET_PATH, "r") as f:
            for line in f:
                if "=" in line and not line.strip().startswith("#"):
                    k, v = line.strip().split("=", 1)
                    k = k.replace("export ", "").strip()
                    os.environ[k] = v.strip('"\'')
    except Exception as e:
        print(f"Notice: Failed to load Vault secret file {VAULT_SECRET_PATH}: {e}")

HOSTNAME = socket.gethostname()
logging.basicConfig(
    level=os.getenv("LOG_LEVEL", "INFO"),
    format=f"[%(asctime)s] %(levelname)s in %(module)s ({HOSTNAME}): %(message)s"
)
logger = logging.getLogger(__name__)

app = Flask(__name__)
metrics = PrometheusMetrics(app, path="/metrics")
metrics.info("backend_info", "Backend service information", version="2.0.0", hostname=HOSTNAME)

DB_PRIMARY_CONFIG = {
    "host": os.getenv("DB_HOST", "db-primary"),
    "port": int(os.getenv("DB_PORT", "3306")),
    "database": os.getenv("DB_NAME", "appdb"),
    "user": os.getenv("DB_USER", "appuser"),
    "password": os.getenv("DB_PASSWORD", "app_password"),
    "connection_timeout": int(os.getenv("DB_CONNECTION_TIMEOUT", "3")),
}

DB_STANDBY_CONFIG = {
    "host": os.getenv("DB_STANDBY_HOST", "db-standby"),
    "port": int(os.getenv("DB_STANDBY_PORT", "3306")),
    "database": os.getenv("DB_NAME", "appdb"),
    "user": os.getenv("DB_USER", "appuser"),
    "password": os.getenv("DB_PASSWORD", "app_password"),
    "connection_timeout": int(os.getenv("DB_CONNECTION_TIMEOUT", "3")),
}

REDIS_HOST = os.getenv("REDIS_HOST", "redis")
REDIS_PORT = int(os.getenv("REDIS_PORT", "6379"))
CACHE_TTL_SECONDS = int(os.getenv("CACHE_TTL", "30"))
REQUIRE_API_KEY = os.getenv("REQUIRE_API_KEY", "false").lower() == "true"
ALLOWED_API_KEY = os.getenv("API_KEY", "secret-api-key-12345")

redis_client = None
try:
    redis_client = redis.Redis(host=REDIS_HOST, port=REDIS_PORT, db=0, socket_timeout=2, decode_responses=True)
    redis_client.ping()
    logger.info(f"Connected to Redis cache at {REDIS_HOST}:{REDIS_PORT}")
except Exception as r_err:
    logger.warning(f"Could not connect to Redis cache at {REDIS_HOST}:{REDIS_PORT}: {r_err}")
    redis_client = None

MINIO_ENDPOINT = os.getenv("MINIO_ENDPOINT", "http://minio.minio.svc.cluster.local:9000")
MINIO_ACCESS_KEY = os.getenv("MINIO_ACCESS_KEY")
MINIO_SECRET_KEY = os.getenv("MINIO_SECRET_KEY")
MINIO_BUCKET = os.getenv("MINIO_BUCKET", "app-backups")

minio_client = None
try:
    minio_client = boto3.client(
        "s3",
        endpoint_url=MINIO_ENDPOINT,
        aws_access_key_id=MINIO_ACCESS_KEY,
        aws_secret_access_key=MINIO_SECRET_KEY,
        config=boto3.session.Config(signature_version="s3v4")
    )
    try:
        minio_client.head_bucket(Bucket=MINIO_BUCKET)
    except Exception:
        try:
            minio_client.create_bucket(Bucket=MINIO_BUCKET)
            logger.info(f"Auto-created MinIO bucket '{MINIO_BUCKET}'")
        except Exception as b_err:
            logger.warning(f"Notice: Bucket setup warning for '{MINIO_BUCKET}': {b_err}")

    logger.info(f"Configured MinIO storage client for bucket '{MINIO_BUCKET}' at {MINIO_ENDPOINT}")
except Exception as minio_err:
    logger.warning(f"Could not initialize MinIO storage client for {MINIO_ENDPOINT}: {minio_err}")
    minio_client = None




@contextmanager
def db_cursor(dictionary=False):
    active_node = "primary"
    connection = None
    try:
        connection = mysql.connector.connect(**DB_PRIMARY_CONFIG)
    except Error as primary_err:
        logger.warning(f"Primary DB ({DB_PRIMARY_CONFIG['host']}) unreachable: {primary_err}. Attempting failover to Standby DB ({DB_STANDBY_CONFIG['host']})...")
        try:
            connection = mysql.connector.connect(**DB_STANDBY_CONFIG)
            active_node = "standby"
            logger.info(f"Successfully connected to Standby DB ({DB_STANDBY_CONFIG['host']})")
        except Error as standby_err:
            logger.error(f"Both Primary and Standby DBs failed! Primary err: {primary_err}, Standby err: {standby_err}")
            raise standby_err

    cursor = connection.cursor(dictionary=dictionary)
    try:
        yield connection, cursor, active_node
    finally:
        cursor.close()
        connection.close()


def serialize_user(row):
    user = dict(row)
    created_at = user.get("created_at")
    if isinstance(created_at, datetime):
        user["created_at"] = created_at.isoformat()
    return user


def invalidate_user_cache():
    if not redis_client:
        return
    try:
        keys = redis_client.keys("cache:users:*")
        if keys:
            redis_client.delete(*keys)
            logger.info(f"Invalidated {len(keys)} Redis cache keys")
    except Exception as e:
        logger.warning(f"Redis cache invalidation failed: {e}")


@app.after_request
def set_instance_headers(response):
    response.headers["X-Backend-Server"] = HOSTNAME
    response.headers["X-App-Version"] = "v2"
    return response


@app.before_request
def check_api_key():
    if not REQUIRE_API_KEY:
        return None
    if request.path in ["/health", "/metrics", "/"]:
        return None
    api_key = request.headers.get("X-API-Key") or request.args.get("api_key")
    if not api_key or api_key != ALLOWED_API_KEY:
        logger.warning(f"Unauthorized API key access attempt from {request.remote_addr}")
        return jsonify({"error": "unauthorized", "message": "Invalid or missing X-API-Key header"}), 401


@app.route("/")
def home():
    return jsonify({
        "service": "backend-api",
        "version": "v2.0.0",
        "server_instance": HOSTNAME,
        "status": "running",
        "redis_connected": redis_client is not None,
        "vault_secret_loaded": os.path.exists(VAULT_SECRET_PATH),
        "docs": {
            "users": "/api/users",
            "health": "/health",
            "metrics": "/metrics",
        }
    })


@app.route("/health")
def health():
    db_status = "unreachable"
    active_node = "none"
    try:
        with db_cursor() as (_conn, cursor, node):
            cursor.execute("SELECT 1")
            cursor.fetchone()
            db_status = "reachable"
            active_node = node
    except Exception as exc:
        logger.warning(f"Health check DB probe failed: {exc}")

    redis_ok = False
    if redis_client:
        try:
            redis_ok = redis_client.ping()
        except Exception:
            redis_ok = False

    status_code = 200 if db_status == "reachable" else 503
    return jsonify({
        "status": "healthy" if status_code == 200 else "unhealthy",
        "server_instance": HOSTNAME,
        "database": db_status,
        "active_db_node": active_node,
        "redis_cache": "connected" if redis_ok else "unavailable"
    }), status_code


@app.route("/api/users", methods=["GET"])
def list_users():
    cache_key = "cache:users:all"
    if redis_client:
        try:
            cached_data = redis_client.get(cache_key)
            if cached_data:
                res_json = json.loads(cached_data)
                res_json["cached"] = True
                res_json["server"] = HOSTNAME
                response = jsonify(res_json)
                response.headers["X-Cache-Status"] = "HIT"
                return response
        except Exception as c_err:
            logger.warning(f"Redis get cache failed: {c_err}")

    with db_cursor(dictionary=True) as (_conn, cursor, active_node):
        cursor.execute("SELECT id, name, email, created_at FROM users ORDER BY id")
        users = [serialize_user(row) for row in cursor.fetchall()]

    result = {
        "data": users,
        "count": len(users),
        "cached": False,
        "server": HOSTNAME,
        "active_db_node": active_node
    }

    if redis_client:
        try:
            redis_client.setex(cache_key, CACHE_TTL_SECONDS, json.dumps(result))
        except Exception as c_err:
            logger.warning(f"Redis set cache failed: {c_err}")

    response = jsonify(result)
    response.headers["X-Cache-Status"] = "MISS"
    return response


@app.route("/api/users/<int:user_id>", methods=["GET"])
def get_user(user_id):
    cache_key = f"cache:users:{user_id}"
    if redis_client:
        try:
            cached_data = redis_client.get(cache_key)
            if cached_data:
                res_json = json.loads(cached_data)
                res_json["cached"] = True
                res_json["server"] = HOSTNAME
                response = jsonify(res_json)
                response.headers["X-Cache-Status"] = "HIT"
                return response
        except Exception as c_err:
            logger.warning(f"Redis get user cache failed: {c_err}")

    with db_cursor(dictionary=True) as (_conn, cursor, active_node):
        cursor.execute("SELECT id, name, email, created_at FROM users WHERE id = %s", (user_id,))
        row = cursor.fetchone()

    if row is None:
        return jsonify({"error": "user not found", "server": HOSTNAME}), 404

    user = serialize_user(row)
    result = {
        "data": user,
        "cached": False,
        "server": HOSTNAME,
        "active_db_node": active_node
    }

    if redis_client:
        try:
            redis_client.setex(cache_key, CACHE_TTL_SECONDS, json.dumps(result))
        except Exception as c_err:
            logger.warning(f"Redis set user cache failed: {c_err}")

    response = jsonify(result)
    response.headers["X-Cache-Status"] = "MISS"
    return response


@app.route("/api/users", methods=["POST"])
def create_user():
    payload = request.get_json(silent=True) or {}
    name = str(payload.get("name", "")).strip()
    email = str(payload.get("email", "")).strip().lower()

    if not name or not email or "@" not in email:
        return jsonify({"error": "Valid name and email are required", "server": HOSTNAME}), 400

    try:
        with db_cursor(dictionary=True) as (connection, cursor, active_node):
            cursor.execute("INSERT INTO users (name, email) VALUES (%s, %s)", (name, email))
            connection.commit()
            cursor.execute("SELECT id, name, email, created_at FROM users WHERE id = %s", (cursor.lastrowid,))
            user = serialize_user(cursor.fetchone())
            invalidate_user_cache()
            return jsonify({"data": user, "server": HOSTNAME, "active_db_node": active_node}), 201
    except Error as exc:
        if getattr(exc, "errno", None) == 1062:
            return jsonify({"error": "email already exists"}), 409
        return jsonify({"error": "database operation failed", "details": str(exc)}), 500


@app.route("/api/users/<int:user_id>", methods=["PUT", "PATCH"])
def update_user(user_id):
    payload = request.get_json(silent=True) or {}
    name = payload.get("name")
    email = payload.get("email")

    if not name and not email:
        return jsonify({"error": "No fields to update"}), 400

    fields, values = [], []
    if name:
        fields.append("name = %s")
        values.append(str(name).strip())
    if email:
        fields.append("email = %s")
        values.append(str(email).strip().lower())

    values.append(user_id)

    try:
        with db_cursor(dictionary=True) as (connection, cursor, active_node):
            cursor.execute(f"UPDATE users SET {', '.join(fields)} WHERE id = %s", tuple(values))
            connection.commit()
            if cursor.rowcount == 0:
                return jsonify({"error": "user not found"}), 404
            cursor.execute("SELECT id, name, email, created_at FROM users WHERE id = %s", (user_id,))
            user = serialize_user(cursor.fetchone())
            invalidate_user_cache()
            return jsonify({"data": user, "server": HOSTNAME, "active_db_node": active_node})
    except Error as exc:
        return jsonify({"error": "database operation failed", "details": str(exc)}), 500


@app.route("/api/users/<int:user_id>", methods=["DELETE"])
def delete_user(user_id):
    try:
        with db_cursor() as (connection, cursor, _active_node):
            cursor.execute("DELETE FROM users WHERE id = %s", (user_id,))
            connection.commit()
            deleted = cursor.rowcount

        if deleted == 0:
            return jsonify({"error": "user not found"}), 404

        invalidate_user_cache()
        return "", 204
    except Error as exc:
        return jsonify({"error": "database operation failed", "details": str(exc)}), 500


# ==============================================================================
# MinIO Object Storage Integration Endpoints
# ==============================================================================
@app.route("/api/storage/files", methods=["GET"])
def list_storage_files():
    if not minio_client:
        return jsonify({"error": "MinIO storage unconfigured or unreachable"}), 503
    try:
        response = minio_client.list_objects_v2(Bucket=MINIO_BUCKET)
        files = []
        if "Contents" in response:
            for obj in response["Contents"]:
                files.append({
                    "filename": obj["Key"],
                    "size": obj["Size"],
                    "last_modified": obj["LastModified"].isoformat()
                })
        return jsonify({"bucket": MINIO_BUCKET, "files": files, "count": len(files)})
    except Exception as exc:
        logger.error(f"Failed to list MinIO files: {exc}")
        return jsonify({"error": "MinIO storage operation failed", "details": str(exc)}), 500


@app.route("/api/storage/upload", methods=["POST"])
def upload_storage_file():
    if not minio_client:
        return jsonify({"error": "MinIO storage unconfigured or unreachable"}), 503

    payload = request.get_json(silent=True) or {}
    filename = payload.get("filename") or request.args.get("filename")
    content = payload.get("content")

    if 'file' in request.files:
        uploaded_file = request.files['file']
        filename = filename or uploaded_file.filename
        content = uploaded_file.read()
    elif content is not None:
        if isinstance(content, str):
            content = content.encode("utf-8")

    if not filename or content is None:
        return jsonify({"error": "filename and file content are required"}), 400

    try:
        minio_client.put_object(
            Bucket=MINIO_BUCKET,
            Key=filename,
            Body=content
        )
        logger.info(f"Uploaded file '{filename}' to MinIO bucket '{MINIO_BUCKET}'")
        return jsonify({
            "message": "File uploaded successfully to MinIO",
            "bucket": MINIO_BUCKET,
            "filename": filename,
            "size": len(content)
        }), 201
    except Exception as exc:
        logger.error(f"Failed to upload file '{filename}' to MinIO: {exc}")
        return jsonify({"error": "MinIO upload failed", "details": str(exc)}), 500


@app.route("/api/storage/files/<path:filename>", methods=["GET"])
def get_storage_file(filename):
    if not minio_client:
        return jsonify({"error": "MinIO storage unconfigured or unreachable"}), 503
    try:
        obj = minio_client.get_object(Bucket=MINIO_BUCKET, Key=filename)
        body_content = obj["Body"].read().decode("utf-8", errors="replace")
        return jsonify({
            "bucket": MINIO_BUCKET,
            "filename": filename,
            "content": body_content,
            "content_type": obj.get("ContentType", "text/plain")
        })
    except ClientError as ce:
        if ce.response["Error"]["Code"] == "NoSuchKey":
            return jsonify({"error": "file not found in MinIO bucket"}), 404
        return jsonify({"error": "MinIO read failed", "details": str(ce)}), 500
    except Exception as exc:
        return jsonify({"error": "MinIO read failed", "details": str(exc)}), 500


@app.route("/api/storage/files/<path:filename>", methods=["DELETE"])
def delete_storage_file(filename):
    if not minio_client:
        return jsonify({"error": "MinIO storage unconfigured or unreachable"}), 503
    try:
        minio_client.delete_object(Bucket=MINIO_BUCKET, Key=filename)
        return jsonify({"message": f"File '{filename}' deleted from MinIO", "bucket": MINIO_BUCKET})
    except Exception as exc:
        return jsonify({"error": "MinIO delete failed", "details": str(exc)}), 500



if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)

