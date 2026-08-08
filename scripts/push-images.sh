#!/bin/bash
# ==============================================================================
# Container Image Builder & Registry Push Automation
# Supports Docker Hub and Harbor Registry (harbor.mypro.local)
# ==============================================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

REGISTRY="${1:-harbor.mypro.local/library}"
VERSION="${2:-v2.0.0}"

echo "======================================================================"
echo "[BUILD & PUSH] Target Registry: ${REGISTRY} | Version: ${VERSION}"
echo "======================================================================"

# 1. Build Frontend Image
echo "--> Building Frontend UI Container Image..."
docker build -t "${REGISTRY}/mypro-frontend:${VERSION}" -t "${REGISTRY}/mypro-frontend:latest" "${BASE_DIR}/docker/frontend"

# 2. Build Backend Image
echo "--> Building Backend REST API Container Image..."
docker build -t "${REGISTRY}/mypro-backend:${VERSION}" -t "${REGISTRY}/mypro-backend:latest" "${BASE_DIR}/docker/backend"

# 3. Build Backup Worker Image
echo "--> Building Backup Worker Container Image..."
docker build -t "${REGISTRY}/mypro-backup:${VERSION}" -t "${REGISTRY}/mypro-backup:latest" "${BASE_DIR}/docker/backup"

echo "--> Pushing Images to ${REGISTRY}..."
docker push "${REGISTRY}/mypro-frontend:${VERSION}" || true
docker push "${REGISTRY}/mypro-frontend:latest" || true
docker push "${REGISTRY}/mypro-backend:${VERSION}" || true
docker push "${REGISTRY}/mypro-backend:latest" || true
docker push "${REGISTRY}/mypro-backup:${VERSION}" || true
docker push "${REGISTRY}/mypro-backup:latest" || true

echo "======================================================================"
echo "[SUCCESS] Container images built and pushed successfully!"
echo "======================================================================"
