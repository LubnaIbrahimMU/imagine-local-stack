# Enterprise Kubernetes, GitOps, Vault, Harbor & Monitoring Platform (`mypro`)

A production-grade, CKA-aligned Kubernetes infrastructure platform and GitOps deployment stack. This project builds upon the microservice application architecture of `lab3` and integrates the modular Helm, Argo CD, Vault, Harbor, NGINX Ingress, and Observability architecture patterns from `imagine-infrastructure`.


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
  - HashiCorp Vault (Secrets Management & Sidecar Agent Injection): http://vault.mypro.local
  - Harbor Container Registry (Self-Hosted Registry):               http://harbor.mypro.local
  - Argo CD GitOps Operator (Declarative App-of-Apps Deployment):    http://argocd.mypro.local
  - Prometheus, Grafana, Loki, Node Exporter, cAdvisor Stack:        http://grafana.mypro.local
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
│   └── backup/                         # MySQL/Postgres Automated Backup Worker
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
    ├── reboot-persistence-sync.sh      # Auto-resolves cluster IP and updates /etc/hosts on reboot
    ├── setup-local-cluster.sh          # One-touch cluster bootstrapper
    ├── push-images.sh                  # Builds and pushes images to Harbor / Docker Hub
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

### 3. Deploy Environments via Helm
```bash
make dev-up   # Deploy to namespace 'dev' (app.dev.mypro.local)
make uat-up   # Deploy to namespace 'uat' (app.uat.mypro.local)
make prd-up   # Deploy to namespace 'prd' (app.prd.mypro.local)
```

### 4. Build & Push Images
```bash
make push-images
```

---

## 🔐 Secrets Management with HashiCorp Vault

Vault is installed in namespace `vault`. The automated script `infrastructure/vault/vault-init.sh` performs:
1. Unsealing Vault using stored keys (`infrastructure/vault/vault-keys.json`).
2. Enabling the KV-v2 secrets engine at `secret/`.
3. Writing environment secrets (`secret/data/dev/database`, `secret/data/uat/database`, `secret/data/prd/database`).
4. Configuring Kubernetes ServiceAccount authentication.
5. Sourcing credentials directly into backend pods via Vault Agent Sidecar annotations (`/vault/secrets/db-config`).

---

## 📊 Monitoring & Observability Stack

The monitoring stack includes:
- **Node Exporter**: Collects host hardware and kernel metrics (CPU, RAM, Disk I/O).
- **cAdvisor**: Collects container-level resource consumption, memory working set size, and CPU throttle percentages.
- **Prometheus & Grafana**: Pre-configured dashboards accessible at `http://grafana.mypro.local`.
- **Loki & Promtail**: Collects pod log stdout/stderr streams.
- **Alertmanager**: Triggers alerts on container crashes, memory throttling, and database downtime.

---

## 📖 Operational Manual & Cheat Sheet

For an exhaustive list of CKA operational commands, Vault CLI commands, Harbor registry instructions, HPA stress testing, and network policy debugging, refer to [CHEATSHEET.md](CHEATSHEET.md).
