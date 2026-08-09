.PHONY: help setup dev-up uat-up prd-up reboot-fix vault-init harbor-setup minio-setup push-images test-failover test-backup clean tls-setup

SHELL := /bin/bash

help: ## Display available management commands
	@echo "========================================================================="
	@echo "         MYPRO ENTERPRISE KUBERNETES & GITOPS PLATFORM MAKEFILE          "
	@echo "========================================================================="
	@echo "Usage: make <target>"
	@echo ""
	@echo "Target Commands:"
	@echo "  setup         Bootstrap local K8s cluster, NGINX Ingress, Vault, Harbor, MinIO, ArgoCD"
	@echo "  tls-setup     Generate and apply TLS certificates for all HTTPS namespaces"
	@echo "  reboot-fix    Auto-resolve cluster Ingress IP & update /etc/hosts after reboot"
	@echo "  vault-init    Initialize, unseal, enable KV v2, and setup K8s auth in Vault"
	@echo "  harbor-setup  Deploy self-hosted Harbor container registry on K8s"
	@echo "  minio-setup   Deploy self-hosted MinIO Object Storage on K8s"
	@echo "  push-images   Build and push frontend/backend/backup images to Harbor & DockerHub"
	@echo "  dev-up        Deploy Development environment via Helm"
	@echo "  uat-up        Deploy Staging UAT environment via Helm"
	@echo "  prd-up        Deploy Production environment via Helm"
	@echo "  test-failover Trigger DB primary pod deletion to test active standby failover"
	@echo "  test-backup   Execute manual DB backup CronJob run & verify PVC archive"
	@echo "  clean         Tear down local environment namespaces"
	@echo "========================================================================="

setup:
	@./scripts/setup-local-cluster.sh

tls-setup:
	@chmod +x ./infrastructure/cert-manager/generate-tls-secrets.sh && ./infrastructure/cert-manager/generate-tls-secrets.sh

reboot-fix:
	@./scripts/reboot-persistence-sync.sh

vault-init:
	@./infrastructure/vault/vault-init.sh

vault-sync:
	@./infrastructure/vault/seed-vault-secrets.sh

eso-setup:
	@chmod +x ./infrastructure/vault/install-external-secrets.sh && ./infrastructure/vault/install-external-secrets.sh

argocd-install:
	@chmod +x ./infrastructure/argocd/install-argocd.sh && ./infrastructure/argocd/install-argocd.sh

metrics-server-setup:
	@chmod +x ./infrastructure/metrics-server/install-metrics-server.sh && ./infrastructure/metrics-server/install-metrics-server.sh

harbor-setup:
	@./infrastructure/harbor/harbor-setup.sh

minio-setup:
	@chmod +x ./infrastructure/minio/minio-setup.sh && ./infrastructure/minio/minio-setup.sh

push-images:
	# @./scripts/push-images.sh
	@chmod +x ./scripts/build-and-push-images.sh && ./scripts/build-and-push-images.sh

deploy-dev:
	@./scripts/run-app.sh deploy

run-app:
	@./scripts/run-app.sh deploy


# deploy-uat:
# 	@helm upgrade --install mypro-uat ./helm/charts/umbrella-app -n uat --create-namespace -f ./helm/values/values-uat.yml

# deploy-prd:
# 	@helm upgrade --install mypro-prd ./helm/charts/umbrella-app -n prd --create-namespace -f ./helm/values/values-prd.yml

test-failover:
	@./scripts/test-failover.sh dev

test-backup:
	@./scripts/backup-restore-db.sh dev

view-backup:
	@./scripts/backup-restore-db.sh dev

view-db-users:
	@kubectl exec -n dev app-mypro-dev-db-primary-0 -- mysql -u appuser -papp_password_123 appdb -e "SELECT * FROM users;"

clean:
	@kubectl delete namespace dev uat prd --ignore-not-found=true

