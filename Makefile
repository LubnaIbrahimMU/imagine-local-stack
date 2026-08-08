.PHONY: help setup dev-up uat-up prd-up reboot-fix vault-init harbor-setup push-images test-failover test-backup clean

SHELL := /bin/bash

help: ## Display available management commands
	@echo "========================================================================="
	@echo "         MYPRO ENTERPRISE KUBERNETES & GITOPS PLATFORM MAKEFILE          "
	@echo "========================================================================="
	@echo "Usage: make <target>"
	@echo ""
	@echo "Target Commands:"
	@echo "  setup         Bootstrap local K8s cluster, NGINX Ingress, Vault, Harbor, ArgoCD"
	@echo "  reboot-fix    Auto-resolve cluster Ingress IP & update /etc/hosts after reboot"
	@echo "  vault-init    Initialize, unseal, enable KV v2, and setup K8s auth in Vault"
	@echo "  harbor-setup  Deploy self-hosted Harbor container registry on K8s"
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

reboot-fix:
	@./scripts/reboot-persistence-sync.sh

vault-init:
	@./infrastructure/vault/vault-init.sh

harbor-setup:
	@./infrastructure/harbor/harbor-setup.sh

push-images:
	@./scripts/push-images.sh

dev-up:
	@helm upgrade --install mypro-dev ./helm/charts/umbrella-app -n dev --create-namespace -f ./helm/values/values-dev.yaml

uat-up:
	@helm upgrade --install mypro-uat ./helm/charts/umbrella-app -n uat --create-namespace -f ./helm/values/values-uat.yaml

prd-up:
	@helm upgrade --install mypro-prd ./helm/charts/umbrella-app -n prd --create-namespace -f ./helm/values/values-prd.yaml

test-failover:
	@./scripts/test-failover.sh dev

test-backup:
	@./scripts/backup-restore-db.sh dev

clean:
	@kubectl delete namespace dev uat prd --ignore-not-found=true
