# ShopNow Frontend: React E-Commerce with AWS Infrastructure & DevSecOps Pipeline

React-based e-commerce frontend deployed on AWS with enterprise-grade CI/CD automation, Docker containerization, and comprehensive security scanning across multi-cloud environments.

<details>
<summary><strong>Table of Contents</strong></summary>

- [ShopNow Frontend: React E-Commerce with AWS Infrastructure \& DevSecOps Pipeline](#shopnow-frontend-react-e-commerce-with-aws-infrastructure--devsecops-pipeline)
  - [1. System Architecture \& Network Topology](#1-system-architecture--network-topology)
    - [Security Groups Configuration (Traffic Matrix)](#security-groups-configuration-traffic-matrix)
  - [2. Multi-Environment Infrastructure Strategy](#2-multi-environment-infrastructure-strategy)
    - [Environment Cross-Reference Matrix](#environment-cross-reference-matrix)
  - [3. Build Management \& Containerization](#3-build-management--containerization)
  - [4. DevSecOps CI/CD Pipelines](#4-devsecops-cicd-pipelines)
    - [4.1. Pipeline Flow Chart](#41-pipeline-flow-chart)
    - [4.2. Workflow Lifecycles](#42-workflow-lifecycles)
      - [A. Development Pipeline (`ci-dev.yml`)](#a-development-pipeline-ci-devyml)
      - [B. Production Pipeline (`ci-prod.yml`)](#b-production-pipeline-ci-prodyml)
    - [4.3. Advanced Kubernetes Templating with Helm](#43-advanced-kubernetes-templating-with-helm)
  - [5. Tech Stack Matrix](#5-tech-stack-matrix)
  - [6. Compliance \& Implementation Evidence](#6-compliance--implementation-evidence)
    - [6.1. CI/CD Pipeline Automation (Pipeline Execution)](#61-cicd-pipeline-automation-pipeline-execution)
    - [6.2. System Traffic Routing Configuration (Traffic Routing)](#62-system-traffic-routing-configuration-traffic-routing)
    - [6.3. Multi-Environment Log Management (CloudWatch Logs)](#63-multi-environment-log-management-cloudwatch-logs)
    - [6.4. Container Image Storage (Private Registry)](#64-container-image-storage-private-registry)
    - [6.5. Application User Interface \& SSL Security (User Interface \& HTTPS)](#65-application-user-interface--ssl-security-user-interface--https)
    - [6.6. Comprehensive Security Scan Reports](#66-comprehensive-security-scan-reports)
  - [7. Contact \& Project Context](#7-contact--project-context)

</details>

---

## 1. System Architecture & Network Topology

The frontend architecture is designed with strict separation of concerns, high availability, and network isolation using Terraform IaC.

<div align="center">
  <img src="img/AWS-Architecture.png" width="650" alt="DevSecOps Workflow Architecture">
  <br>
  <em>AWS Architecture Modeling</em>
</div>

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

All infrastructure is provisioned via Terraform as Code in [Bel7phegor/shopnow-infa](https://github.com/Bel7phegor/shopnow-infa). 

### Environment Cross-Reference Matrix

| Technical Aspect | Development Environment (`develop`) | Production Environment (`v*` Tags / `release`) |
| :--- | :--- | :--- |
| **Target Infrastructure** | AWS EC2 + Auto Scaling Group | AWS EKS (Kubernetes Cluster) |
| **Application Domain URL**| `https://shopnow-dev.anphuc.site` | `https://shopnow.anphuc.site` |
| **Backend API Endpoint** | `https://api-dev.anphuc.site` | `https://api-shopnow.anphuc.site` |
| **Trigger Mechanism** | Automatic on every `push` | Manual approval triggered via Git tags |
| **Docker Image Tagging** | `dev_${COMMIT_SHA}` | `${VERSION}_${COMMIT_SHA}` + `latest` |
| **NAT Gateway Strategy** | Single NAT (Cost-Optimized) | Multi-AZ NAT Gateways (High-Availability) |
| **Deployment Strategy** | Container replacement on EC2 | Zero-Downtime Rolling Update (K8s Ingress) |
| **Log Management** | CloudWatch Group: `/ec2/shopnow-frontend` | CloudWatch Group: `/prod/shopnow-frontend` |
| **Security Gates** | Lightweight (Snyk + Trivy FS) | Comprehensive (SAST + Container + DAST) |

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

### 4.1. Pipeline Flow Chart
<div align="center">
  <img src="img/DevSevOps-Flow.png" width="650" alt="DevSecOps Workflow Architecture">
  <br>
  <em>End-to-End DevSecOps Workflow Architecture Modeling</em>
</div>

### 4.2. Workflow Lifecycles

#### A. Development Pipeline [(`ci-dev.yml`)](https://github.com/Bel7phegor/shopnow-frontend/actions/workflows/ci-dev.yml)
1. **Trigger:** Code push to `develop` branch.
2. **Execution:** Self-hosted EC2 runner pulls code → Builds Docker Image with Dev API configuration → Pushes to ECR → Deploys directly to EC2 via `docker run` with CloudWatch logs logging driver enabled.

#### B. Production Pipeline [(`ci-prod.yml`)](https://github.com/Bel7phegor/shopnow-frontend/actions/workflows/ci-prod.yml)
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


### 4.3. Advanced Kubernetes Templating with Helm
To maintain high reusability and clean infrastructure-as-code blueprints across separate environments, the Kubernetes manifests for this application are fully parameterized via the global [Bel7phegor/templates-helm-k8s](https://github.com/Bel7phegor/templates-helm-k8s) centralized repository.

* **Centralized Logic:** Instead of hardcoding YAML manifests per repository, a reusable Helm base template governs deployments, multi-AZ ingress routing, cluster IP allocations, and Horizontal Pod Autoscalers (HPA).
* **Decoupled Values Configuration:** The `values.yaml` inside the `shopnow-helm` subsystem overrides this master layout, injecting target variables unique to the production or staging boundaries during the execution of `helm upgrade --install`.
## 5. Tech Stack Matrix

| Layer | Technologies & Tools |
| :--- | :--- |
| **Frontend Engine** | React 18.2 (Hooks, SPA Architecture), Redux & Redux-Thunk, React Router v6, Axios, Bootstrap 5, Material-UI |
| **Cloud Infrastructure** | AWS (EKS, EC2, VPC, Route 53, CloudWatch, ACM, IAM OIDC), Terraform IaC |
| **Deployment & Orchestration** | Docker (Multi-stage Build), Helm Charts, GitHub Actions Pipelines |
| **DevSecOps Scanners** | Snyk (SAST), Aqua Trivy (FS & Container Scan), OWASP ZAP (DAST), Arachni Framework |

---

## 6. Compliance & Implementation Evidence

The technical evidence below logs the actual operation, deployment metrics, and security assessment results of the Frontend component running on AWS.

### 6.1. CI/CD Pipeline Automation (Pipeline Execution)

**Live Workflows Tracker:** Check [GitHub Actions Production Workflow](https://github.com/Bel7phegor/shopnow-frontend/actions/runs/26713547479) Runs for real-time compliance validation.

<div align="center">
  <img src="img/pipeline-success.png" width="650" alt="GitHub Actions Pipeline Success Status">
  <br>
  <em>GitHub Actions automated execution of the end-to-end Build, Test, and Deploy workflow</em>
</div> <br>

**Technical Description:** The pipeline workflow is triggered automatically following a Shift-Left security architecture. All package assembly phases and parallel security validation gates display a successful "Passed" status before completing the final infrastructure update.

### 6.2. System Traffic Routing Configuration (Traffic Routing)
<div align="center">
  <img src="img/alb-routing.png" width="650" alt="AWS Application Load Balancer Path Routing">
  <br>
  <em>Target Group routing and health status configuration mapping on AWS Application Load Balancer</em>
</div> <br>

**Technical Description:** Inbound client traffic is captured and filtered through the AWS Application Load Balancer (ALB). The ALB executes Host-based and Path-based routing rules to direct, isolate, and optimize traffic load across active production pods and target services.

### 6.3. Multi-Environment Log Management (CloudWatch Logs)
<div align="center">
  <img src="img/cloudwatch-logs.png" width="650" alt="AWS CloudWatch Multi-Environment Logging Group">
  <br>
  <em>Isolated centralized streams on AWS CloudWatch logs for Development and Production environments</em>
</div> <br>

**Technical Description:** Application runtime telemetry is bifurcated into environment-specific log groups (`/ec2/shopnow-frontend` for Dev container execution and `/prod/shopnow-frontend` via AWS FluentBit for containerised EKS workloads). This preserves operational isolation, log structural immutability, and simplifies audit forensic tracking.

### 6.4. Container Image Storage (Private Registry)
<div align="center">
  <img src="img/ecr-registry.png" width="650" alt="AWS Elastic Container Registry Private Repository">
  <br>
  <em>Secure hosting environment via AWS Elastic Container Registry (ECR) Private Repository</em>
</div> <br>

**Technical Description:** Immutable release artifacts (Docker container images) are pushed directly into the secure AWS ECR Private Registry using short-lived IAM OIDC Token authentication, entirely mitigating the leakage risk of static AWS credentials.

### 6.5. Application User Interface & SSL Security (User Interface & HTTPS)
<div align="center">
  <img src="img/website-ssl.png" width="650" alt="ShopNow Frontend Interface with Valid SSL Certificate">
  <br>
  <em>Live Client Interface running securely over an encrypted HTTPS connection</em>
</div> <br>

**Technical Description:** The user-facing single page application runs stably on its designated custom domain. Transport Layer Security (TLS/SSL) is actively enforced via certificates provisioned and auto-renewed by AWS Certificate Manager (ACM) to preserve end-to-end data integrity.

### 6.6. Comprehensive Security Scan Reports
<p align="center">
  <img src="img/Aranchi-scan-website.png" alt="Aranchi scan website" width="350">
  <img src="img/Snyk-scan-code.png" alt="CI/CD Pipeline Status" width="350">
  <img src="img/ZAP-scan-website.png" alt="CI/CD Pipeline Status" width="350">
</p> 

Detailed compliance scanning data is automatically exported into readable HTML formats, serving as strict Quality Control gates for system audits:

| Assessment Domain | Scanner Tool | Live Artifact / Workflow Run Link |
| :--- | :--- | :--- |
| **Third-Party Dependencies** | Snyk SAST | [Snyk Scan Report Artifact](https://github.com/Bel7phegor/shopnow-frontend/actions/runs/26721740846/artifacts/7319313847) |
| **Repository Secret Leakage**| Trivy FS | [Trivy Filesystem Report](https://github.com/Bel7phegor/shopnow-frontend/actions/runs/26721740846/artifacts/7319309333) |
| **Container OS Vulnerabilities**| Trivy Image | [Trivy Container Layer Report](https://github.com/Bel7phegor/shopnow-frontend/actions/runs/26721740846/artifacts/7319327430) |
| **Web Application Security** | OWASP ZAP | [ZAP Dynamic Baseline Report](https://github.com/Bel7phegor/shopnow-frontend/actions/runs/26721740846/artifacts/7319340250) |
| **Dynamic Penetration Test** | Arachni | [Arachni Dynamic Scan ZIP Archive](https://github.com/Bel7phegor/shopnow-frontend/actions/runs/26721740846/artifacts/7319341287) |

---

## 7. Contact & Project Context

**Author:** Nguyễn An Phúc (Bel7phegor)
* **Profiles:** [LinkedIn: nguyen-an-phuc](https://www.linkedin.com/in/nguyen-an-phuc) | [GitHub: Bel7phegor](https://github.com/Bel7phegor) | [Portfolio: anphuc.site](https://anphuc.site)
* **Email:** [nguyenanphuc12032002@gmail.com](mailto:nguyenanphuc12032002@gmail.com)

**E-Commerce Project Subsystems:**
* **Frontend React:** [Bel7phegor/shopnow-frontend](https://github.com/Bel7phegor/shopnow-frontend)
* **Backend Java microsevices:** [Bel7phegor/shopnow-backend](https://github.com/Bel7phegor/shopnow-backend)
* **Terraform Cloud Automation Infrastructure:** [Bel7phegor/shopnow-infa](https://github.com/Bel7phegor/shopnow-infa)
* **Kubernetes Helm Templates:** [Bel7phegor/shopnow-helm](https://github.com/Bel7phegor/shopnow-helm)