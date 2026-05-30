# ShopNow Frontend: React E-Commerce with AWS Infrastructure & DevSecOps Pipeline

React-based e-commerce frontend deployed on AWS with enterprise-grade CI/CD automation, Docker containerization, and comprehensive security scanning across multi-cloud environments.

---

## 1. System Architecture & Network Topology

The frontend architecture is designed with strict separation of concerns, high availability, and network isolation using Terraform IaC.

* **Compute Layer:** Containerized React SPA deployed on **AWS EKS (Kubernetes)** for Production (multi-pod auto-scaling) and **AWS EC2 ASG** for Development.
* **Traffic Routing:** Internal and external traffic managed via AWS Load Balancer Controller (ALB) terminating HTTPS via AWS Certificate Manager (ACM).
* **Network Isolation (Private/Public Subnets):**
  * *Public Subnets:* Only the Bastion Host (SSH Jump Server) is exposed to the internet.
  * *Private Subnets:* EKS Cluster, Worker Nodes, and self-hosted GitHub Actions Runners communicate entirely inside private subnets, routing outbound traffic via NAT Gateways.

### Security Groups Configuration (Traffic Matrix)
* **EKS Control Plane:** Ingress HTTPS (443) allowed only from Worker Nodes and Bastion Host.
* **EKS Worker Nodes:** Ingress HTTP/HTTPS (80/443) allowed from ALB; Node-to-Node communication unrestricted.
* **Bastion EC2:** Ingress SSH (22) restricted to corporate VPC CIDR (`10.0.0.0/16`).
* **Frontend Dev Runner:** Ingress SSH (22) from Bastion only. Outbound allowed to ECR, GitHub API, and Backend Runner (Port 5214).

---

## 2. Multi-Environment Infrastructure Strategy

All infrastructure is provisioned via Terraform as Code in [github.com/Bel7phegor/shopnow-infa](https://github.com/Bel7phegor/shopnow-infa). 

### Environment Cross-Reference Matrix

| Technical Aspect | Development Environment (`develop`) | Production Environment (`v*` Tags / `release`) |
| :--- | :--- | :--- |
| **Target Infrastructure** | AWS EC2 + Auto Scaling Group | AWS EKS (Kubernetes Cluster) |
| **Application Domain URL**| `https://shopnow-dev.anphuc.site` | `https://shopnow.anphuc.site` |
| **Backend API Endpoint** | `https://api-dev.anphuc.site` | `https://api.sneaker.anphuc.site` |
| **Trigger Mechanism** | Automatic on every `push` | Manual approval triggered via Git tags |
| **Docker Image Tagging** | `dev_${COMMIT_SHA}` | `${VERSION}_${COMMIT_SHA}` + `latest` |
| **NAT Gateway Strategy** | Single NAT (Cost-Optimized) | Multi-AZ NAT Gateways (High-Availability) |
| **Deployment Strategy** | Container replacement on EC2 | Zero-Downtime Rolling Update (K8s Ingress) |
| **Log Management** | CloudWatch Group: `/ec2/shopnow-frontend` | CloudWatch Group: `/prod/shopnow-frontend` |
| **Security Gates** | Lightweight (Snyk + Trivy FS) | Comprehensive (SAST + Container + DAST) |

### Infrastructure Deployment Variables (Terraform)

```hcl
# Development Variables (dev.tfvars)
environment             = "dev"
vpc_cidr                = "10.0.0.0/16"
single_nat_gateway      = true
enable_eks              = false
enable_github_runner    = true
github_runner_label     = "fe-runner-dev"
nodegroup_desired_size  = 1

# Production Variables (prod.tfvars)
environment             = "prod"
vpc_cidr                = "10.0.0.0/16"
single_nat_gateway      = false
enable_eks              = true
nodegroup_desired_size  = 3
nodegroup_max_size      = 4
nodegroup_instance_types = ["t3.medium"]
```

---

## 3. Build Management & Containerization

A multi-stage Dockerfile is utilized to optimize image size, ensuring that development dependencies are excluded from the final lightweight production image (~20MB).

```dockerfile
# Stage 1: Build Environment
FROM node:18-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
ARG REACT_APP_BASE_API_URL
ENV REACT_APP_BASE_API_URL=$REACT_APP_BASE_API_URL
RUN npm run build

# Stage 2: Optimized Nginx Production Runtime
FROM nginx:alpine
COPY --from=builder /app/build /usr/share/nginx/html
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
```
* **Image Registry:** Private AWS Elastic Container Registry (ECR), integrated with secure OpenID Connect (OIDC) IAM Roles (no static AWS hardcoded credentials).

---

## 4. DevSecOps CI/CD Pipelines

The pipelines utilize a **Shift-Left Security** approach, embedding automated vulnerability assessment gates before and after code changes hit production.

### Workflow Lifecycles

#### A. Development Pipeline (`ci-dev.yml`)
1. **Trigger:** Code push to `develop` branch.
2. **Execution:** Self-hosted EC2 runner pulls code → Builds Docker Image with Dev API configuration → Pushes to ECR → Deploys directly to EC2 via `docker run` with CloudWatch logs logging driver enabled.

#### B. Production Pipeline (`ci-prod.yml`)
1. **Trigger:** Git version tag creation (`v*`).
2. **Build Stage:** Builds production-optimized Docker image.
3. **Security Gate (Parallel Execution):**
   * **Snyk Code Scan:** Analyzes `package.json` for flawed third-party npm libraries.
   * **Trivy FS Scan:** Scans repository filesystem for hardcoded secrets/API keys.
   * **Trivy Image Scan:** Deep scans OS layers within the Docker container for known CVEs.
4. **Orchestrated Deploy:** Requires successful scan results. Executes Helm upgrade / `kubectl apply` on EKS cluster with atomic rollbacks.
5. **Post-Deploy DAST (Parallel Execution):**
   * **OWASP ZAP Scan:** Validates OWASP Top 10 compliance on the live URL.
   * **Arachni Penetration Testing:** Executes dynamic security testing across subdomains.

---

## 5. Tech Stack Matrix

* **Frontend Engine:** React 18.2 (Hooks, SPA architecture), Redux + Redux-Thunk (State Management), React Router v6, Axios, Bootstrap 5 & Material-UI.
* **DevOps Infrastructure:** AWS (EKS, EC2, VPC, Route 53, CloudWatch, ACM, IAM OIDC), Terraform IaC, Docker, Helm, GitHub Actions.
* **SecOps Testing Tools:** Snyk (SAST), Aqua Trivy (Container & Secret Scanner), OWASP ZAP (DAST), Arachni (Dynamic Penetration Testing).

---

## 6. Compliance & Implementation Evidence

All security scans and deployments generate verifiable artifacts for compliance and audit reporting.

### Security Scan Evidence Logs (30-day Retention)

| Assessment Domain | Scanner Tool | Live Artifact / Workflow Run Link |
| :--- | :--- | :--- |
| **Third-Party Dependencies** | Snyk SAST | [Snyk Scan Report Artifact](https://github.com/Bel7phegor/shopnow-frontend/actions/runs/26025690453/artifacts/7054479523) |
| **Repository Secret Leakage**| Trivy FS | [Trivy Filesystem Report](https://github.com/Bel7phegor/shopnow-frontend/actions/runs/26025690453/artifacts/7054460074) |
| **Container OS Vulnerabilities**| Trivy Image | [Trivy Container Layer Report](https://github.com/Bel7phegor/shopnow-frontend/actions/runs/26025690453/artifacts/7054474332) |
| **Web Application Security** | OWASP ZAP | [ZAP Dynamic Baseline Report](https://github.com/Bel7phegor/shopnow-frontend/actions/runs/26025690453/artifacts/7054574910) |
| **Dynamic Penetration Test** | Arachni | [Arachni Dynamic Scan ZIP Archive](https://github.com/Bel7phegor/shopnow-frontend/actions/runs/26025690453/artifacts/7054573714) |

* **Live Workflows Tracker:** Check [GitHub Actions Workflow Runs](https://github.com/Bel7phegor/shopnow-frontend/actions) for real-time compliance validation.

---

## 7. Contact & Project Context

**Author:** Nguyễn An Phúc (Bel7phegor)
* **Profiles:** [LinkedIn](https://www.linkedin.com/in/nguyen-an-phuc) | [GitHub](https://github.com/Bel7phegor) | [Portfolio](https://anphuc.site)
* **Email:** [nguyenanphuc12032002@gmail.com](mailto:nguyenanphuc12032002@gmail.com)

**E-Commerce Project Subsystems:**
* **Backend Monorepo:** [.NET Core Microservices Platform](https://github.com/Bel7phegor/sneaker-netcore)
* **Global Infrastructure:** [Terraform Cloud Automation Core](https://github.com/Bel7phegor/shopnow-infa)