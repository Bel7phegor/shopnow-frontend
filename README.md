# ShopNow Frontend: React E-Commerce with AWS Infrastructure & DevSecOps Pipeline

React-based e-commerce frontend deployed on AWS with enterprise-grade CI/CD automation, Docker containerization, and comprehensive security scanning across development and production environments.

<details>
<summary><strong>Table of Contents</strong></summary>

- [ShopNow Frontend: React E-Commerce with AWS Infrastructure \& DevSecOps Pipeline](#shopnow-frontend-react-e-commerce-with-aws-infrastructure--devsecops-pipeline)
  - [1. System Architecture](#1-system-architecture)
  - [2. Multi-Environment Strategy](#2-multi-environment-strategy)
    - [Development Environment (`develop` branch)](#development-environment-develop-branch)
    - [Production Environment (`release` branch + version tags)](#production-environment-release-branch--version-tags)
    - [Environment-Specific Configuration](#environment-specific-configuration)
  - [3. Network \& Security (Terraform IaC)](#3-network--security-terraform-iac)
    - [Development Infrastructure](#development-infrastructure)
    - [Production Infrastructure](#production-infrastructure)
    - [Security Groups Configuration](#security-groups-configuration)
    - [Network Isolation](#network-isolation)
  - [4. Repository Structure \& Build Management](#4-repository-structure--build-management)
    - [Dockerfile Strategy](#dockerfile-strategy)
    - [Docker Image Management](#docker-image-management)
    - [GitHub Secrets Configuration](#github-secrets-configuration)
  - [5. DevSecOps Pipeline](#5-devsecops-pipeline)
    - [Development Pipeline](#development-pipeline)
    - [Production Pipeline](#production-pipeline)
    - [Security Assessment](#security-assessment)
    - [Dynamic Security Testing](#dynamic-security-testing)
  - [6. Monitoring \& Operations](#6-monitoring--operations)
    - [CloudWatch Logs](#cloudwatch-logs)
    - [Health Checks](#health-checks)
  - [7. Tech Stack](#7-tech-stack)
    - [Frontend](#frontend)
    - [DevOps \& Infrastructure](#devops--infrastructure)
    - [Security \& Scanning](#security--scanning)
  - [8. Getting Started](#8-getting-started)
    - [Deploy to Development](#deploy-to-development)
    - [Deploy to Production](#deploy-to-production)
  - [9. Implementation Evidence](#9-implementation-evidence)
    - [CI/CD Pipeline Execution](#cicd-pipeline-execution)
    - [Dockerfile](#dockerfile)
    - [Infrastructure as Code](#infrastructure-as-code)
    - [Security Scanning Reports](#security-scanning-reports)
  - [10. Contact Information](#10-contact-information)

</details>

---

## 1. System Architecture

The frontend is deployed across AWS infrastructure with separation of concerns:

* **Compute Layer:** React application containerized with Docker, deployed on EC2 instances (Self-hosted GitHub Runners) for development and production environments.
* **Load Balancing:** Network Load Balancer (NLB) or Application Load Balancer (ALB) integrated with EKS Ingress controller, routing traffic by hostname/path.
* **Container Orchestration:** Kubernetes (EKS) manages frontend deployments with auto-scaling and rolling updates.
* **Bastion Host:** Jump server in public subnet for secure access to EKS cluster and private resources.
* **Self-hosted Runners:** EC2 instances configured as GitHub Actions runners for CI/CD pipeline execution.
* **Logging & Monitoring:** AWS CloudWatch Logs aggregation from all containers/pods.

---

## 2. Multi-Environment Strategy

### Development Environment (`develop` branch)

- **Trigger:** Automatic on every push to `develop` branch
- **Image Tag:** `dev_${COMMIT_SHA}`
- **Deployment:** Direct to Dev ASG via self-hosted runner
- **CloudWatch Logs:** `/ec2/shopnow-frontend` (EC2-based)
- **Recovery Time:** Fast iteration, less strict security gates
- **Infrastructure:** Single NAT Gateway (cost optimized for dev)

### Production Environment (`release` branch + version tags)

- **Trigger:** Manual via version tags (`v1.0.0`, `v1.1.0`, etc.) or `release` branch push
- **Image Tag:** `${VERSION}_${COMMIT_SHA}` + `latest`
- **Deployment:** Full security scanning → zero-downtime K8s deployment
- **CloudWatch Logs:** `/prod/shopnow-frontend` (K8s-based)
- **Security Gates:** Full SAST + DAST scanning before deployment
- **Infrastructure:** Multi-AZ NAT Gateways (high availability)

### Environment-Specific Configuration

| Aspect | Development | Production |
|--------|-------------|-----------|
| **Infrastructure** | EC2 + ASG (terraform) | EKS + Ingress (terraform) |
| **API Endpoint** | `https://api-dev.anphuc.site` | `https://api.sneaker.anphuc.site` |
| **NAT Gateway** | Single (1 AZ) | Multi-AZ (2+ AZs) |
| **Security Scan** | Snyk + Trivy FS | Snyk + Trivy FS + Trivy Image |
| **DAST Scan** | No | Yes (Arachni + ZAP) |
| **Deployment Speed** | 5-10 minutes | 30-35 minutes |
| **Availability** | Single instance | Multi-pod with auto-scaling |

---

## 3. Network & Security (Terraform IaC)

All infrastructure is defined as code in [shopnow-infa](https://github.com/Bel7phegor/shopnow-infa) repository using Terraform. This section outlines the network topology and security configuration provisioned for both environments.

### Development Infrastructure

**Dev Terraform Variables:**
```hcl
environment              = "dev"
vpc_cidr                 = "10.0.0.0/16"
single_nat_gateway       = true  # Cost optimization
enable_eks               = false # EC2-based runners instead
enable_bastion           = true  # SSH jump host
enable_github_runner     = true  # fe-runner-dev label
github_runner_label      = "fe-runner-dev"
nodegroup_desired_size   = 1
```

### Production Infrastructure

**Prod Terraform Variables:**
```hcl
environment              = "prod"
vpc_cidr                 = "10.0.0.0/16"
single_nat_gateway       = false  # Multi-AZ NAT for HA
enable_eks               = true   # EKS cluster
enable_bastion           = true   # Bastion host
enable_github_runner     = true   # fe-runner-prod label
github_runner_label      = "fe-runner-prod"
nodegroup_desired_size   = 2
nodegroup_max_size       = 4
nodegroup_instance_types = ["t3.medium"]
```

### Security Groups Configuration

Security groups enforce network isolation at the instance level:

**EKS Control Plane Security Group**
```hcl
Ingress:
  ├─ Port 443 (HTTPS) from EKS Worker Nodes
  └─ Port 443 (HTTPS) from Bastion Security Group
Egress:
  └─ All traffic to 0.0.0.0/0
```

**EKS Worker Nodes Security Group**
```hcl
Ingress:
  ├─ Port 0-65535 (TCP/UDP) from Self (Node-to-Node)
  ├─ Port 0-65535 (TCP/UDP) from Bastion Security Group
  ├─ Port 80 (HTTP) from 0.0.0.0/0 (NLB/ALB)
  └─ Port 443 (HTTPS) from 0.0.0.0/0 (NLB/ALB)
Egress:
  └─ All traffic to 0.0.0.0/0
```

**Bastion EC2 Security Group**
```hcl
Ingress:
  └─ Port 22 (SSH) from VPC CIDR (10.0.0.0/16)
Egress:
  └─ All traffic to 0.0.0.0/0
```

**Frontend Runner EC2 Security Group (Dev)**
```hcl
Ingress:
  └─ Port 22 (SSH) from Bastion Security Group
Egress:
  ├─ Port 443 (HTTPS) to ECR (ECR push/pull)
  ├─ Port 443 (HTTPS) to GitHub API
  └─ Port 5214 (Backend API) to Backend Runner
```

### Network Isolation

* **Public Subnets:** Bastion host only. Accessible from Internet via SSH (port 22 from VPC only).
* **Private Subnets:** EKS cluster, worker nodes, frontend runners. All outbound traffic routes via NAT Gateway(s).
* **Intra-VPC Communication:** Direct routing via VPC routes. No cross-subnet ACLs (default allow).
* **Internet Access:** NAT Gateway provides outbound Internet access for private resources.
* **SSL/TLS:** AWS Certificate Manager (ACM) manages TLS certificates. NLB/ALB terminates HTTPS.

**Terraform Reference:** [shopnow-infa/vpc.tf](https://github.com/Bel7phegor/shopnow-infa/blob/main/vpc.tf) | [shopnow-infa/sg.tf](https://github.com/Bel7phegor/shopnow-infa/blob/main/sg.tf)

---

## 4. Repository Structure & Build Management

### Dockerfile Strategy

Multi-stage build optimizes final image size:

```dockerfile
# Stage 1: Build (Node 18 Alpine)
FROM node:18-alpine AS builder
  ├─ npm install
  ├─ npm run build (creates optimized production bundle)
  └─ Output: /app/build/

# Stage 2: Runtime (Nginx Alpine)
FROM nginx:alpine
  ├─ Copy build artifacts
  ├─ Configure Nginx for SPA routing
  └─ Output: ~20MB optimized image
```

**Build Arguments:**
- `REACT_APP_BASE_API_URL` - Backend API endpoint (environment-specific)

### Docker Image Management

* **Multi-tagging Strategy:**
  - Versioned tag: `${ECR_REGISTRY}/shopnow-frontend:dev_${SHA}` (traceability)
  - Latest tag: `${ECR_REGISTRY}/shopnow-frontend:latest` (convenience)

* **Registry:**
  - AWS Elastic Container Registry (ECR) as primary storage
  - Private repository, access via IAM roles

### GitHub Secrets Configuration

Required secrets for CI/CD pipeline:

| Secret | Purpose | Example |
|--------|---------|---------|
| `ECR_REGISTRY` | AWS ECR repository URI | `250830191861.dkr.ecr.ap-southeast-3.amazonaws.com` |
| `REACT_APP_BASE_API_URL` | Backend API URL (dev) | `https://api-dev.anphuc.site` |
| `REACT_APP_BASE_API_URL_PROD` | Backend API URL (prod) | `https://api.sneaker.anphuc.site` |
| `SNYK_TOKEN` | Snyk vulnerability scanner | `snyk-**** (from Snyk dashboard)` |
| `FE_PORT` | Frontend container port | `3000:80` |
| `URL_FE` | Frontend URL for DAST scanning | `https://shopnow-prod.anphuc.site` |
| `ROLE_ACCESS` | AWS IAM role ARN (dev) | `arn:aws:iam::ACCOUNT:role/github-fe-shopnow-role` |
| `ROLE_ACCESS_PROD` | AWS IAM role ARN (prod) | `arn:aws:iam::ACCOUNT:role/github-fe-shopnow-prod-role` |

---

## 5. DevSecOps Pipeline

Pipeline automating build → security → deploy lifecycle via GitHub Actions.

### Development Pipeline

**Trigger:** `push` → `develop` branch
**Runner:** `self-hosted, fe-runner-dev` (EC2 in private subnet)

```yaml
dev:
  ├─ Checkout code
  ├─ Configure AWS IAM credentials (OIDC)
  ├─ Build Docker image with dev API URL
  ├─ Push to ECR (dev_${SHA})
  └─ Deploy via self-hosted runner
      ├─ Pull image from ECR
      ├─ Stop/remove old container
      ├─ Run container with CloudWatch logging
      └─ Total time: 10-15 minutes
```

**Deployment:** `docker run` on EC2 instance with:
- CloudWatch Logs driver (log group: `/ec2/shopnow-frontend`)
- Auto-restart policy (`--restart unless-stopped`)
- Port mapping from `3000` → `${FE_PORT}` (e.g., `80`)

### Production Pipeline

**Trigger:** `push` → `release` branch OR `tags` → `v*`
**Runner:** `self-hosted, fe-runner-prod` (EC2 in private subnet)

```yaml
prod:
  ├─ Build Docker image (prod API URL)
  ├─ Push to ECR (${TAG}_${SHA} + latest)
  ├─ Parallel security scanning (3 parallel jobs)
  │   ├─ Snyk: Dependency vulnerabilities
  │   ├─ Trivy FS: Filesystem/config scan
  │   └─ Trivy Image: Docker layer scan
  ├─ Deploy (waits for scanning)
  │   └─ kubectl apply / Helm deploy to EKS Prod cluster
  └─ Post-deployment DAST (2 parallel jobs)
      ├─ Arachni: Web app penetration testing
      └─ ZAP: OWASP Top 10 assessment
      └─ Total time: 30-40 minutes
```

**Deployment:** Kubernetes-native via:
- Image pull from ECR
- Ingress controller routes traffic (`shopnow-prod.anphuc.site`)
- Auto-scaling based on CPU/memory metrics
- Rolling update strategy (maxSurge: 1, maxUnavailable: 0)

### Security Assessment

**Stage 2: SAST & Container Scanning**

* **Snyk Source Code Scan**
  - Scans `package.json` + `package-lock.json` for known vulnerabilities
  - Detects outdated/vulnerable npm dependencies
  - Output: HTML report (30 days retention)

* **Trivy Filesystem Scan**
  - Analyzes repository structure for misconfigurations
  - Detects hardcoded secrets, API keys, credentials
  - Severity: HIGH and CRITICAL only
  - Output: HTML report

* **Trivy Docker Image Scan**
  - Scans Docker layers for OS-level vulnerabilities
  - Checks Nginx base image for known CVEs
  - Prerequisite: `trivy-fs-scan` completed
  - Output: HTML report (1-30 days retention)

### Dynamic Security Testing

**Stage 4: DAST (Post-Deployment)**

* **Arachni Web Security Scan**
  - Automated penetration testing against live frontend
  - Tests XSS, CSRF, SQLi, and other web vulnerabilities
  - Scope: Main domain + all subdomains
  - Output: HTML/ZIP report

* **OWASP ZAP Baseline Scan**
  - Headless security scanning using ZAP container
  - Validates OWASP Top 10 compliance
  - Non-blocking (errors ignored to prevent deployment failure)
  - Output: HTML report

---

## 6. Monitoring & Operations

### CloudWatch Logs

* **Dev Log Group:** `/ec2/shopnow-frontend` (EC2-based)
  - Log Stream: Container stdout/stderr from `docker run`

* **Prod Log Group:** `/prod/shopnow-frontend` (K8s-based)
  - Log Stream: Pod stdout/stderr aggregated from EKS cluster

* **Retention:** 30 days
* **Filter & Alert:** Custom metrics based on error patterns (4xx/5xx errors)

### Health Checks

**Development (EC2-based):**
- Manual health check script (e.g., `curl http://localhost:3000`)
- Runner monitors container status

**Production (K8s-based):**
- Liveness Probe: `/health` endpoint (checks if pod is alive)
- Readiness Probe: `/ready` endpoint (checks if pod can serve traffic)
- Service discovers healthy pods automatically

---

## 7. Tech Stack

### Frontend

- **React 18.2:** UI framework with hooks
- **Redux + Redux-Thunk:** State management
- **React Router v6:** SPA routing
- **Axios:** HTTP client for API calls
- **Bootstrap 5 + Material-UI:** Component libraries
- **React-Toastify:** Toast notifications

### DevOps & Infrastructure

- **Containerization:** Docker, Nginx (reverse proxy)
- **Container Registry:** AWS ECR (Elastic Container Registry)
- **Cloud Platform:** AWS (VPC, EC2, EKS, Route 53, CloudWatch, ACM, IAM)
- **Infrastructure as Code:** Terraform (shopnow-infa)
- **CI/CD:** GitHub Actions (runner: self-hosted EC2)
- **Orchestration:** Kubernetes (EKS) for production

### Security & Scanning

- **SAST:** Snyk (dependency scanning)
- **Container Security:** Aqua Trivy (filesystem + image scanning)
- **DAST:** OWASP ZAP, Arachni (web penetration testing)
- **Secret Management:** GitHub Secrets, AWS IAM roles

---

## 8. Getting Started

### Deploy to Development

```bash
# Push to develop branch
git checkout develop
git commit -m "Feature: Add new component"
git push origin develop

# Pipeline automatically triggers:
# - Build Docker image
# - Push to ECR (dev_${SHA})
# - Deploy to dev runner
```

### Deploy to Production

```bash
# Create release and tag version
git checkout release
git merge develop
git tag v1.1.0
git push origin release --tags

# Pipeline automatically triggers:
# - Security scanning (Snyk + Trivy)
# - Build Docker image
# - Deploy with rolling update on EKS
# - DAST scanning (Arachni + ZAP)
```

---

## 9. Implementation Evidence

### CI/CD Pipeline Execution

**GitHub Actions Workflows:**
- Development: [ci-dev.yml](./.github/workflows/ci-dev.yml)
- Production: [ci-prod.yml](./.github/workflows/ci-prod.yml)

**Workflow Runs:** [Actions Tab](https://github.com/Bel7phegor/shopnow-frontend/actions)

### Dockerfile

[Production-ready multi-stage Dockerfile](./Dockerfile)

```dockerfile
FROM node:18-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
ARG REACT_APP_BASE_API_URL
ENV REACT_APP_BASE_API_URL=$REACT_APP_BASE_API_URL
RUN npm run build

FROM nginx:alpine
COPY --from=builder /app/build /usr/share/nginx/html
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
```

### Infrastructure as Code

**Terraform:** [shopnow-infa](https://github.com/Bel7phegor/shopnow-infa)

**Deployment Architecture:**

**Development Environment:**
- URL: https://shopnow-dev.anphuc.site
- API: https://api-dev.anphuc.site
- Compute: EC2 ASG (self-hosted runner)
- Logs: CloudWatch `/ec2/shopnow-frontend`
- Update Frequency: Every commit to `develop`

**Production Environment:**
- URL: https://shopnow.anphuc.site
- API: https://api.sneaker.anphuc.site
- Compute: EKS cluster (Kubernetes)
- Logs: CloudWatch `/prod/shopnow-frontend`
- Update Frequency: Version tags (v*)

### Security Scanning Reports

All scanning reports are generated and retained for compliance:

| Scan Type | Tool | Trigger | Retention |
|-----------|------|---------|-----------|
| Dependency | Snyk | Every prod build | 30 days |
| Filesystem | Trivy FS | Every prod build | 30 days |
| Docker Image | Trivy Image | Every prod build | 30 days |
| Web App | Arachni | Post-deploy (prod) | 30 days |
| OWASP Top 10 | ZAP | Post-deploy (prod) | 30 days |

---

## 10. Contact Information

**Author:** Bel7phegor (Nguyễn An Phúc)

- **Email:** [nguyenanphuc12032002@gmail.com](mailto:nguyenanphuc12032002@gmail.com)
- **LinkedIn:** [linkedin.com/in/nguyen-an-phuc](https://www.linkedin.com/in/nguyen-an-phuc/)
- **GitHub:** [@Bel7phegor](https://github.com/Bel7phegor)
- **Portfolio:** [anphuc.site](https://anphuc.site)

**Related Projects:**
- Backend: [sneaker-netcore](https://github.com/Bel7phegor/sneaker-netcore) (.NET Core API)
- Infrastructure: [shopnow-infa](https://github.com/Bel7phegor/shopnow-infa) (Terraform IaC)
- Repository Structure: DevSecOps focused e-commerce platform

---

**Objective:** Build and deploy production-grade applications with automated security, compliance, and zero-downtime deployments across multiple cloud environments using Infrastructure as Code.
