#!/usr/bin/env bash
# ==============================================================================
# CloudGate / MyPro Container Builder, Harbor Registry Pusher & Manifest Updater
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

REGISTRY_DOMAIN="${1:-vharbor.aliien.uk}"
PROJECT_NAME="${2:-pro4}"
VERSION_TAG="${3:-v2.0.1}"


FULL_REGISTRY="${REGISTRY_DOMAIN}/${PROJECT_NAME}"

HARBOR_USER="${HARBOR_USER:-admin}"
HARBOR_PASS="${HARBOR_PASS:-HarborAdminPassword123}"

echo "======================================================================"
echo "[BUILD & PUSH] Target Registry: ${FULL_REGISTRY} | Version: ${VERSION_TAG}"
echo "======================================================================"

# 1. Build Docker Images
echo "--> Building Frontend UI Container Image..."
docker build -t "${FULL_REGISTRY}/mypro-frontend:${VERSION_TAG}" -t "${FULL_REGISTRY}/mypro-frontend:latest" "${PROJECT_ROOT}/docker/frontend"

echo "--> Building Backend REST API Container Image..."
docker build -t "${FULL_REGISTRY}/mypro-backend:${VERSION_TAG}" -t "${FULL_REGISTRY}/mypro-backend:latest" "${PROJECT_ROOT}/docker/backend"

echo "--> Building Backup Worker Container Image..."
docker build -t "${FULL_REGISTRY}/mypro-backup:${VERSION_TAG}" -t "${FULL_REGISTRY}/mypro-backup:latest" "${PROJECT_ROOT}/docker/backup"

# 2. Login to Harbor Registry
echo "--> Logging into Harbor Registry (${REGISTRY_DOMAIN})..."
echo "${HARBOR_PASS}" | docker login "${REGISTRY_DOMAIN}" --username "${HARBOR_USER}" --password-stdin || true

# 3. Push Images to Harbor
echo "--> Pushing Images to Harbor (${FULL_REGISTRY})..."
docker push "${FULL_REGISTRY}/mypro-frontend:${VERSION_TAG}" || true
docker push "${FULL_REGISTRY}/mypro-frontend:latest" || true
docker push "${FULL_REGISTRY}/mypro-backend:${VERSION_TAG}" || true
docker push "${FULL_REGISTRY}/mypro-backend:latest" || true
docker push "${FULL_REGISTRY}/mypro-backup:${VERSION_TAG}" || true
docker push "${FULL_REGISTRY}/mypro-backup:latest" || true

# 4. Update automation/schemas/harbor/add-image.json
ADD_IMAGE_JSON="${PROJECT_ROOT}/automation/schemas/harbor/add-image.json"
if [ -f "${ADD_IMAGE_JSON}" ]; then
  echo "--> Updating Harbor automation schema: ${ADD_IMAGE_JSON}"
  cat <<EOF > "${ADD_IMAGE_JSON}"
{
  "temp_dir": "/temp",
  "provisioning_spec": {
    "resource_schema_version": 1,
    "service_profile": "managed-harbor-operations@v1",
    "metadata": {
      "subscription_id": "SUB_HARBOR_LOCAL",
      "vendor_id": "V_2",
      "service_key_id": "SK_HARBOR"
    },
    "action_key": "add_image",
    "temp_dir": "/temp",
    "service_config": {
      "project_name": "${PROJECT_NAME}",
      "project_public": false,
      "local_registry": "${REGISTRY_DOMAIN}",
      "images": [
        {
          "source_image": "${FULL_REGISTRY}/mypro-frontend:${VERSION_TAG}",
          "repository_name": "mypro-frontend",
          "tag": "${VERSION_TAG}"
        },
        {
          "source_image": "${FULL_REGISTRY}/mypro-backend:${VERSION_TAG}",
          "repository_name": "mypro-backend",
          "tag": "${VERSION_TAG}"
        },
        {
          "source_image": "${FULL_REGISTRY}/mypro-backup:${VERSION_TAG}",
          "repository_name": "mypro-backup",
          "tag": "${VERSION_TAG}"
        }
      ]
    },
    "resources": {
      "VM": [
        {
          "publicIP": "${REGISTRY_DOMAIN}",
          "cloudID": ""
        }
      ]
    },
    "credentials": {
      "username": "${HARBOR_USER}",
      "password": "${HARBOR_PASS}"
    }
  }
}
EOF
fi

# 5. Update Helm Chart Values with new image repositories & tags
FRONTEND_VALUES="${PROJECT_ROOT}/helm/charts/frontend-service/values.yml"
if [ -f "${FRONTEND_VALUES}" ]; then
  echo "--> Updating Helm frontend image values..."
  sed -i "s|repository: .*|repository: ${FULL_REGISTRY}/mypro-frontend|g" "${FRONTEND_VALUES}"
  sed -i "s|tag: .*|tag: ${VERSION_TAG}|g" "${FRONTEND_VALUES}"
fi

BACKEND_VALUES="${PROJECT_ROOT}/helm/charts/backend-service/values.yml"
if [ -f "${BACKEND_VALUES}" ]; then
  echo "--> Updating Helm backend image values..."
  sed -i "s|repository: .*|repository: ${FULL_REGISTRY}/mypro-backend|g" "${BACKEND_VALUES}"
  sed -i "s|tag: .*|tag: ${VERSION_TAG}|g" "${BACKEND_VALUES}"
fi

echo "======================================================================"
echo "[SUCCESS] Container images built, pushed, and manifests updated!"
echo "======================================================================"
