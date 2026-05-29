# Budget Bank — Forging a DevOps Pipeline

A simple expense tracking application built primarily to demonstrate a production-grade DevOps pipeline. The application itself is 3-tier, but the focus of this project is the infrastructure and automation surrounding it.

---

## Application Stack

- **Frontend:** Static HTML/JS served via Nginx
- **Backend:** Python Flask REST API
- **Database:** PostgreSQL

---

## Infrastructure & DevOps Stack

- **Cloud:** AWS EC2 (t2.small)
- **Provisioning:** Terraform
- **Configuration Management:** Ansible
- **Containerization:** Docker
- **Orchestration:** Kubernetes (k3s)
- **CI/CD:** GitHub Actions
- **Image Registry:** DockerHub

---

## Architecture

```
GitHub Push
    → GitHub Actions (CI/CD)
        → Build Docker images → Push to DockerHub
        → SSH into EC2 → kubectl apply manifests
            → k3s Kubernetes Cluster
                → Nginx Ingress Controller
                    → /api  → Flask API pod
                    → /     → Frontend pod
                → PostgreSQL pod (persistent volume)
```

---

## Infrastructure Provisioning

Terraform provisions the EC2 instance with a security group allowing ports 22 (SSH) and 80 (HTTP). Ansible then configures the instance by installing k3s and the Nginx ingress controller.

A single script `infra/provision.sh` orchestrates the full provisioning flow — runs Terraform, captures the public IP, updates the Ansible inventory, and runs the playbook.

---

## CI/CD Pipeline

The pipeline is defined in `.github/workflows/ci-cd.yml` and triggers on every push to `main`.

**Build job:**
- Checks out code
- Logs into DockerHub
- Builds and pushes API and frontend images

**Deploy job** (depends on build job):
- Copies k8s manifests to EC2 via SCP
- SSHes into EC2 and runs `kubectl apply`
- Restarts API and frontend deployments to pull latest images

Postgres is intentionally excluded from rollout restarts — it is stateful and its image does not change between deployments.

---

## Kubernetes Manifests

| File | Resources |
|------|-----------|
| `postgres-deployment.yaml` | PersistentVolumeClaim, Deployment, ClusterIP Service (`db`) |
| `api-deployment.yaml` | Deployment, ClusterIP Service |
| `frontend-deployment.yaml` | Deployment, ClusterIP Service |
| `ingress.yaml` | Nginx Ingress with path rewriting |

The PostgreSQL service is named `db` to match the connection string `postgresql://postgres:postgres@db:5432/expensedb` used by Flask. Service names become DNS hostnames inside the cluster.

---

## Repository Structure

```
budget-bank/
├── app/
│   ├── api/                  # Flask app, Dockerfile
│   └── frontend/             # index.html, Dockerfile
├── infra/
│   ├── main.tf               # EC2, security group, key pair
│   ├── variables.tf
│   ├── outputs.tf
│   ├── playbook.yaml         # k3s + Nginx ingress install
│   ├── inventory.ini
│   └── provision.sh          # Single provisioning script
├── k8s/
│   ├── postgres-deployment.yaml
│   ├── api-deployment.yaml
│   ├── frontend-deployment.yaml
│   └── ingress.yaml
├── docker-compose.yaml       # Local development
└── .github/
    └── workflows/
        └── ci-cd.yml
```

---
