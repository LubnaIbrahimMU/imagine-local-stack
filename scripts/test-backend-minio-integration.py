#!/usr/bin/env python3
"""
Test MinIO Object Storage Integration via Backend API / Boto3 Storage SDK
"""
import os
import sys
import boto3
from botocore.exceptions import ClientError

MINIO_ENDPOINT = os.getenv("MINIO_ENDPOINT", "http://localhost:9000")
MINIO_ACCESS_KEY = os.getenv("MINIO_ACCESS_KEY", "admin")
MINIO_SECRET_KEY = os.getenv("MINIO_SECRET_KEY", "MinioAdminPassword123")
MINIO_BUCKET = os.getenv("MINIO_BUCKET", "minioooo")

print(f"=== Testing MinIO Object Storage Integration ===")
print(f"Endpoint:   {MINIO_ENDPOINT}")
print(f"Bucket:     {MINIO_BUCKET}")
print(f"AccessKey:  {MINIO_ACCESS_KEY}")

minio_client = boto3.client(
    "s3",
    endpoint_url=MINIO_ENDPOINT,
    aws_access_key_id=MINIO_ACCESS_KEY,
    aws_secret_access_key=MINIO_SECRET_KEY,
    config=boto3.session.Config(signature_version="s3v4")
)

# 1. Ensure Bucket Exists
try:
    minio_client.head_bucket(Bucket=MINIO_BUCKET)
    print(f"[+] Bucket '{MINIO_BUCKET}' exists and is accessible.")
except ClientError:
    minio_client.create_bucket(Bucket=MINIO_BUCKET)
    print(f"[+] Created bucket '{MINIO_BUCKET}'.")

# 2. Upload Test Object
test_file = "alien.txt"
test_content = b"Hello v\nCloudGate MinIO Backend Object Storage Test File\n"
minio_client.put_object(Bucket=MINIO_BUCKET, Key=test_file, Body=test_content)
print(f"[+] Successfully uploaded '{test_file}' ({len(test_content)} bytes) to MinIO!")

# 3. List Bucket Contents
response = minio_client.list_objects_v2(Bucket=MINIO_BUCKET)
print(f"[+] Objects in bucket '{MINIO_BUCKET}':")
if "Contents" in response:
    for item in response["Contents"]:
        print(f"    - {item['Key']} ({item['Size']} bytes)")

# 4. Read Test Object Back
obj = minio_client.get_object(Bucket=MINIO_BUCKET, Key=test_file)
downloaded_text = obj["Body"].read().decode("utf-8")
print(f"[+] Downloaded content of '{test_file}':\n{downloaded_text}")

print("=== MinIO Object Storage Verification Passed Successfully! ===")
