#!/usr/bin/env bash
# ==============================================================================
# CloudGate / MyPro Container Builder, Harbor Registry Pusher & Manifest Updater
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

REGISTRY_DOMAIN="${1:-vharbor.aliien.uk}"
PROJECT_NAME="${2:-pro4}"
GIT_SHA=$(git rev-parse --short HEAD 2>/dev/null || echo "latest")
VERSION_TAG="${3:-${GIT_SHA}}"

FULL_REGISTRY="${REGISTRY_DOMAIN}/${PROJECT_NAME}"

HARBOR_USER="${HARBOR_USER:-admin}"

# Prefer an explicitly supplied password, then the password installed in the
# live Harbor release, Vault, and finally the local bootstrap secrets file.
HARBOR_PASS="${HARBOR_PASS:-}"
if [ -z "${HARBOR_PASS}" ]; then
  HARBOR_PASS=$(kubectl get secret harbor-core -n harbor \
    -o jsonpath='{.data.HARBOR_ADMIN_PASSWORD}' 2>/dev/null | base64 -d || true)
fi
if [ -z "${HARBOR_PASS:-}" ]; then
  HARBOR_PASS=$(kubectl exec -n vault vault-0 -- \
    vault kv get -field=admin-password secret/dev/harbor 2>/dev/null || true)
fi
if [ -z "${HARBOR_PASS:-}" ] && [ -f "${PROJECT_ROOT}/infrastructure/vault/secrets.json" ]; then
  HARBOR_PASS=$(jq -r '.harbor.admin_password // empty' \
    "${PROJECT_ROOT}/infrastructure/vault/secrets.json")
fi
if [ -z "${HARBOR_PASS:-}" ]; then
  echo "[ERROR] Could not resolve the Harbor admin password." >&2
  echo "Set HARBOR_PASS or initialize Harbor/Vault before pushing images." >&2
  exit 1
fi

echo "======================================================================"
echo "[BUILD & PUSH] Target Registry: ${FULL_REGISTRY} | Tag (Git SHA): ${VERSION_TAG}"
echo "======================================================================"

# 1. Build Docker Images
echo "--> Building Frontend UI Container Image (${VERSION_TAG})..."
docker build -t "${FULL_REGISTRY}/mypro-frontend:${VERSION_TAG}" -t "${FULL_REGISTRY}/mypro-frontend:latest" "${PROJECT_ROOT}/docker/frontend"

echo "--> Building Backend REST API Container Image (${VERSION_TAG})..."
docker build -t "${FULL_REGISTRY}/mypro-backend:${VERSION_TAG}" -t "${FULL_REGISTRY}/mypro-backend:latest" "${PROJECT_ROOT}/docker/backend"

echo "--> Building Backup Worker Container Image (${VERSION_TAG})..."
docker build -t "${FULL_REGISTRY}/mypro-backup:${VERSION_TAG}" -t "${FULL_REGISTRY}/mypro-backup:latest" "${PROJECT_ROOT}/docker/backup"

# 2. Login to Harbor Registry
echo "--> Logging into Harbor Registry (${REGISTRY_DOMAIN})..."
echo "${HARBOR_PASS}" | docker login "${REGISTRY_DOMAIN}" --username "${HARBOR_USER}" --password-stdin

# A fresh Harbor installation does not create application projects
# automatically. Ensure the target project exists before Docker pushes.
echo "--> Ensuring Harbor project '${PROJECT_NAME}' exists..."
PROJECT_STATUS=$(curl --silent --show-error --insecure \
  --user "${HARBOR_USER}:${HARBOR_PASS}" \
  --output /dev/null --write-out '%{http_code}' \
  "https://${REGISTRY_DOMAIN}/api/v2.0/projects/${PROJECT_NAME}")
case "${PROJECT_STATUS}" in
  200)
    ;;
  404)
    curl --silent --show-error --fail --insecure \
      --user "${HARBOR_USER}:${HARBOR_PASS}" \
      --header 'Content-Type: application/json' \
      --data "{\"project_name\":\"${PROJECT_NAME}\",\"public\":false}" \
      "https://${REGISTRY_DOMAIN}/api/v2.0/projects"
    ;;
  *)
    echo "[ERROR] Harbor project lookup returned HTTP ${PROJECT_STATUS}." >&2
    exit 1
    ;;
esac

# 3. Push Images to Harbor
echo "--> Pushing Images to Harbor (${FULL_REGISTRY})..."
docker push "${FULL_REGISTRY}/mypro-frontend:${VERSION_TAG}"
docker push "${FULL_REGISTRY}/mypro-frontend:latest"
docker push "${FULL_REGISTRY}/mypro-backend:${VERSION_TAG}"
docker push "${FULL_REGISTRY}/mypro-backend:latest"
docker push "${FULL_REGISTRY}/mypro-backup:${VERSION_TAG}"
docker push "${FULL_REGISTRY}/mypro-backup:latest"

# 4. Update automation/schemas/harbor/add-image.json (Optional schema update)
# ADD_IMAGE_JSON="${PROJECT_ROOT}/automation/schemas/harbor/add-image.json"
# if [ -f "${ADD_IMAGE_JSON}" ]; then
#   echo "--> Updating Harbor automation schema: ${ADD_IMAGE_JSON}"
#   cat <<EOF > "${ADD_IMAGE_JSON}"
# {
#   "temp_dir": "/temp",
#   "provisioning_spec": {
#     "resource_schema_version": 1,
#     "service_profile": "managed-harbor-operations@v1",
#     "metadata": {
#       "subscription_id": "SUB_HARBOR_LOCAL",
#       "vendor_id": "V_2",
#       "service_key_id": "SK_HARBOR"
#     },
#     "action_key": "add_image",
#     "temp_dir": "/temp",
#     "service_config": {
#       "project_name": "${PROJECT_NAME}",
#       "project_public": false,
#       "local_registry": "${REGISTRY_DOMAIN}",
#       "images": [
#         {
#           "source_image": "${FULL_REGISTRY}/mypro-frontend:${VERSION_TAG}",
#           "repository_name": "mypro-frontend",
#           "tag": "${VERSION_TAG}"
#         },
#         {
#           "source_image": "${FULL_REGISTRY}/mypro-backend:${VERSION_TAG}",
#           "repository_name": "mypro-backend",
#           "tag": "${VERSION_TAG}"
#         },
#         {
#           "source_image": "${FULL_REGISTRY}/mypro-backup:${VERSION_TAG}",
#           "repository_name": "mypro-backup",
#           "tag": "${VERSION_TAG}"
#         }
#       ]
#     },
#     "resources": {
#       "VM": [
#         {
#           "publicIP": "${REGISTRY_DOMAIN}",
#           "cloudID": ""
#         }
#       ]
#     },
#     "credentials": {
#       "username": "${HARBOR_USER}",
#       "password": "${HARBOR_PASS}"
#     }
#   }
# }
# EOF
# fi


# 5. Update Helm Chart Values with new image repositories & tags
FRONTEND_VALUES="${PROJECT_ROOT}/helm/charts/frontend-service/values.yaml"
if [ -f "${FRONTEND_VALUES}" ]; then
  echo "--> Updating Helm frontend image values..."
  sed -i "s|repository: .*|repository: ${FULL_REGISTRY}/mypro-frontend|g" "${FRONTEND_VALUES}"
  sed -i "s|tag: .*|tag: \"${VERSION_TAG}\"|g" "${FRONTEND_VALUES}"
fi

BACKEND_VALUES="${PROJECT_ROOT}/helm/charts/backend-service/values.yaml"
if [ -f "${BACKEND_VALUES}" ]; then
  echo "--> Updating Helm backend image values..."
  sed -i "s|repository: .*|repository: ${FULL_REGISTRY}/mypro-backend|g" "${BACKEND_VALUES}"
  sed -i "s|tag: .*|tag: \"${VERSION_TAG}\"|g" "${BACKEND_VALUES}"
fi

DB_VALUES="${PROJECT_ROOT}/helm/charts/db-service/values.yaml"
if [ -f "${DB_VALUES}" ]; then
  echo "--> Updating Helm db-service backup image value..."
  sed -i "s|image: .*|image: ${FULL_REGISTRY}/mypro-backup:${VERSION_TAG}|g" "${DB_VALUES}"
fi

# Argo CD renders the committed dependency archives under umbrella-app/charts.
# Repackage them after changing subchart values so GitOps sees the new tags.
echo "--> Rebuilding umbrella Helm dependencies..."
helm dependency update --skip-refresh "${PROJECT_ROOT}/helm/charts/umbrella-app"

echo "======================================================================"
echo "[SUCCESS] Container images built with Git SHA '${VERSION_TAG}', pushed to Harbor, and Helm values updated!"
echo "======================================================================"
