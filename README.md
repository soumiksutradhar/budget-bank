# Budget Bank — DevOps Pipeline Forge

A full-stack expense tracking application built primarily to demonstrate a production-grade DevOps pipeline. The application itself is a 3-tier Monthly Expense Tracker, but the focus of this project is the infrastructure and automation surrounding it.

---

## Application Stack

- **Frontend:** Static HTML/JS served via Nginx
- **Backend:** Python Flask REST API
- **Database:** PostgreSQL

---

## Infrastructure & DevOps Stack

- **Cloud:** AWS EC2 (ap-south-1, t2.small)
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

## Why k3s over Minikube or kubeadm

Minikube is a local development tool that requires a hypervisor and desktop environment — unsuitable for a headless EC2 server. kubeadm is the standard Kubernetes installer but requires significant memory overhead, making it impractical on a t2.micro or t2.small instance. k3s is a fully conformant, lightweight Kubernetes distribution designed for exactly this use case — single-node servers with limited resources. It installs as a single binary and runs as a systemd service.

---

## Why Nginx Ingress over Traefik

k3s ships with Traefik as its default ingress controller. Nginx ingress was chosen instead because the routing configuration — specifically path-based rewriting using capture groups — is more straightforward with Nginx annotations. The `nginx.ingress.kubernetes.io/rewrite-target: /$2` annotation strips the `/api` prefix before forwarding requests to Flask, so Flask routes remain clean (`/expenses` instead of `/api/expenses`).

---

## CI/CD Pipeline

The pipeline is defined in `.github/workflows/ci-cd.yml` and triggers on every push to `main`.

**Build job:**
- Checks out code
- Logs into DockerHub
- Builds and pushes API and frontend images

**Deploy job** (runs only if build succeeds):
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

## Why `window.location.origin` for the API base URL

The frontend uses `const API = \`${window.location.origin}/api\`` instead of a hardcoded IP. Since the EC2 public IP changes on every reprovision, hardcoding it would require a frontend rebuild on each infrastructure change. Using `window.location.origin` dynamically resolves to whatever host the page is served from, making the frontend infrastructure-agnostic.

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

## Local Development

Requirements: Docker, Docker Compose

```bash
git clone https://github.com/dopester03/budget-bank
cd budget-bank
docker-compose up --build
```

The app will be available at `http://localhost` with the API at `http://localhost:5000`.

---

## Deployment

Requirements: AWS credentials, Terraform, Ansible, SSH key at `~/.ssh/devops-forge`

```bash
cd infra
./provision.sh
```

This provisions EC2, installs k3s, and configures the Nginx ingress controller. Push to `main` to trigger the CI/CD pipeline and deploy the application.
