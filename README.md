# Enterprise Kubernetes, GitOps, Vault, Harbor & Monitoring Platform (`mypro`)

A production-grade, CKA-aligned Kubernetes infrastructure platform and GitOps deployment stack. This project integrates modular Helm charts, Argo CD GitOps pipelines, HashiCorp Vault, External Secrets Operator (ESO), Harbor Registry, MinIO Object Storage, NGINX Ingress, and Observability monitoring.

---

## 🌐 Quick Service Access & URLs Dashboard

| Service | Environment / Scope | Hostname / URL | Default Credentials / Auth | Description |
| :--- | :--- | :--- | :--- | :--- |
| 🚢 **Harbor Container Registry** | Platform | [`https://vharbor.aliien.uk`](https://vharbor.aliien.uk) | `admin` / `HarborAdminPassword123` | Self-hosted OCI Image Registry (`pro4` project) |
| 🔐 **HashiCorp Vault UI** | Security | [`http://vault.mypro.local`](http://vault.mypro.local) | Root Token: `root` | Central KV-v2 Secret Engine & Service Account Auth |
| 🐙 **Argo CD GitOps UI** | Operations | [`http://argocd.mypro.local`](http://argocd.mypro.local) | `admin` / `ArgoAdminPassword123` | Declarative App-of-Apps GitOps Controller |
| 🪣 **MinIO Console UI** | Storage | [`http://minio.mypro.local`](http://minio.mypro.local) | `admin` / `NewRootPassword123$` | S3-Compatible Local Object Storage Console |
| 📈 **Grafana Observability** | Monitoring | [`http://grafana.mypro.local`](http://grafana.mypro.local) | `admin` / `admin` | Pre-configured System, Pod & Log Dashboards |
| 🔍 **Prometheus Metrics** | Monitoring | [`http://prometheus.mypro.local`](http://prometheus.mypro.local) | Direct Access | Real-time Time Series Metrics Query Engine |
| 🎨 **Frontend UI (DEV)** | Development | [`http://app.dev.mypro.local`](http://app.dev.mypro.local) | N/A | Development Web Interface (Namespace: `dev`) |
| 🧪 **Frontend UI (UAT)** | Staging / UAT | [`http://app.uat.mypro.local`](http://app.uat.mypro.local) | N/A | Staging Web Interface (Namespace: `uat`) |
| 🚀 **Frontend UI (PRD)** | Production | [`http://app.prd.mypro.local`](http://app.prd.mypro.local) | N/A | Production Web Interface (Namespace: `prd`) |

---

## 🏛️ System Architecture

```text
                                       +----------------------------------------+
                                       |      NGINX Ingress Controller          |
                                       |   (Host Routing, SSL/TLS, Rate Limit)  |
                                       +-------------------+--------------------+
                                                           |
          +------------------------------------------------+------------------------------------------------+
          |                                                |                                                |
+---------v---------+                            +---------v---------+                            +---------v---------+
|  Dev Environment  |                            |  UAT Environment  |                            |  Prd Environment  |
| app.dev.mypro.local|                           | app.uat.mypro.local|                           | app.prd.mypro.local|
+---------+---------+                            +---------+---------+                            +---------+---------+
          |                                                |                                                |
          +------------------------------------------------+------------------------------------------------+
                                                           |
                                  +------------------------+------------------------+
                                  |                                                 |
                       +----------v----------+                           +----------v----------+
                       |    Frontend App     |                           |  Backend REST API   |
                       | (Node/Express :3000)|                           |  (Flask v2 :5000)   |
                       +---------------------+                           +----------+----------+
                                                                                    |
                                                   +--------------------------------+--------------------------------+
                                                   |                                |                                |
                                        +----------v----------+          +----------v----------+          +----------v----------+
                                        |    Redis Cache      |          |    MySQL Primary    |          |    MySQL Standby    |
                                        |  (30s TTL Caching)  |          | (StatefulSet :3306) |          |  (Auto-Failover)    |
                                        +---------------------+          +----------+----------+          +---------------------+
                                                                                    |
                                                                         +----------v----------+
                                                                         | Automated Backup    |
                                                                         | (CronJob / PVC)     |
                                                                         +---------------------+

-----------------------------------------------------------------------------------------------------------------------------
PLATFORM SERVICES:
  - Harbor Container Registry (Self-Hosted Registry):               https://vharbor.aliien.uk
  - HashiCorp Vault (Secrets Management & Sidecar Agent Injection): http://vault.mypro.local
  - Argo CD GitOps Operator (Declarative App-of-Apps Deployment):    http://argocd.mypro.local
  - MinIO Object Storage (S3-Compatible Local Storage):             http://minio.mypro.local
  - Prometheus & Grafana Observability Stack:                       http://grafana.mypro.local
-----------------------------------------------------------------------------------------------------------------------------
```

---

## 📁 Repository Directory Structure

```text
mypro/
├── Makefile                            # Master Makefile with one-word management targets
├── README.md                           # Comprehensive Platform Documentation
├── CHEATSHEET.md                       # Comprehensive CKA & DevOps Operations Manual
├── .gitignore                          # Standard git exclusions for keys, certs, and logs
├── docker/                             # Application Containers & Source Code
│   ├── frontend/                       # Express Node.js UI Service v2.0.0
│   ├── backend/                        # Flask v2 REST API (DB Failover, Redis, Vault Secret Integration)
│   └── backup/                         # MySQL Automated Backup Worker
├── helm/                               # Enterprise Helm Engineering
│   ├── charts/
│   │   ├── frontend-service/           # Deployment, Service, HPA, PDB, Ingress, SecurityContext, NetPol
│   │   ├── backend-service/            # Deployment with Vault Agent Annotations, HPA, PDB, NetPol
│   │   ├── db-service/                 # Primary & Standby StatefulSets, PVC, Init SQL, Backup CronJob
│   │   ├── redis-service/              # Cache Deployment, Service, NetPol
│   │   └── umbrella-app/               # Master Umbrella Parent Chart
│   └── values/
│       ├── values-dev.yml             # Development environment overrides
│       ├── values-uat.yml             # Staging UAT environment overrides
│       └── values-prd.yml             # Production high-availability overrides
├── gitops/                             # Argo CD Declarative Pipeline
│   ├── argo-app-of-apps/
│   │   └── argo.yml                    # Master App-of-Apps controller manifest
│   ├── app-projects/                   # Dev, UAT, PRD ArgoCD AppProjects
│   └── apps/                           # Dev, UAT, PRD ArgoCD Application definitions
├── infrastructure/                     # Platform Services & Monitoring
│   ├── nginx-ingress/                  # NGINX Ingress Controller Helm configuration & installer
│   ├── vault/                          # HashiCorp Vault Helm config, init script & HCL policies
│   ├── harbor/                         # Self-Hosted Harbor Registry config & setup script
│   └── monitoring/                     # Prometheus, Grafana, Node Exporter, cAdvisor, Loki, Promtail
└── scripts/                            # Operational & Reboot Automation
    ├── build-and-push-images.sh        # Builds and pushes container images to Harbor with Git SHA tags
    ├── reboot-persistence-sync.sh      # Auto-resolves cluster IP and updates /etc/hosts on reboot
    ├── setup-local-cluster.sh          # One-touch cluster bootstrapper
    ├── test-failover.sh                # DB Failover and pod disruption budget test suite
    └── backup-restore-db.sh            # Backup CronJob runner & PVC archive inspector
```

---

## ⚡ Quickstart Guide

### 1. One-Touch Environment Setup
```bash
make setup
```
This script initializes your local Kubernetes cluster, deploys NGINX Ingress Controller, installs and unseals HashiCorp Vault, deploys Harbor Registry, sets up Argo CD, and synchronizes your `/etc/hosts` domain mappings.

### 2. Machine Reboot Persistence Fix
If you restart your computer and local domains (`*.mypro.local`) break due to local IP shifts:
```bash
make reboot-fix
```

### 3. Build & Push Images to Harbor
```bash
./scripts/build-and-push-images.sh
```

### 4. Deploy Environments via Helm
```bash
make dev-up   # Deploy to namespace 'dev' (http://app.dev.mypro.local)
make uat-up   # Deploy to namespace 'uat' (http://app.uat.mypro.local)
make prd-up   # Deploy to namespace 'prd' (http://app.prd.mypro.local)
```

---

## 🔐 Secrets Management with HashiCorp Vault & ESO

Vault is installed in namespace `vault`. The automated script `infrastructure/vault/seed-vault-secrets.sh` performs:
1. Unsealing Vault using stored keys (`infrastructure/vault/vault-keys.json`).
2. Enabling the KV-v2 secrets engine at `secret/`.
3. Seeding environment secrets (`secret/data/dev/database`, `secret/data/dev/minio`, `secret/data/dev/app`).
4. Sourcing credentials directly into Kubernetes secrets via External Secrets Operator (ESO) and Vault Agent.

---

## 📊 Monitoring & Observability Stack

The monitoring stack includes:
- **Node Exporter**: Collects host hardware and kernel metrics (CPU, RAM, Disk I/O).
- **cAdvisor**: Collects container-level resource consumption, memory working set size, and CPU throttle percentages.
- **Prometheus & Grafana**: Pre-configured dashboards accessible at [`http://grafana.mypro.local`](http://grafana.mypro.local).
- **Loki & Promtail**: Collects pod log stdout/stderr streams.
- **Alertmanager**: Triggers alerts on container crashes, memory throttling, and database downtime.

