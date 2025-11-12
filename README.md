# GKE Horizontal Pod Autoscaler (HPA) Project

A production-ready implementation of a containerized Flask web application deployed on Google Kubernetes Engine (GKE) with Horizontal Pod Autoscaling, orchestrated entirely through Terraform and Helm.

## 📋 Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Features](#features)
- [Prerequisites](#prerequisites)
- [Project Structure](#project-structure)
- [Quick Start](#quick-start)
- [Detailed Setup](#detailed-setup)
- [Testing Autoscaling](#testing-autoscaling)
- [Monitoring](#monitoring)
- [Troubleshooting](#troubleshooting)
- [Cost Optimization](#cost-optimization)
- [Security Considerations](#security-considerations)
- [CI/CD Integration](#cicd-integration)
- [Cleanup](#cleanup)

## 🎯 Overview

This project demonstrates a complete cloud-native application deployment featuring:

- **Containerized Application**: Python Flask app with health checks and CPU-intensive endpoints
- **Infrastructure as Code**: Full GKE cluster provisioning with Terraform
- **Declarative Deployment**: Helm charts for Kubernetes resource management
- **Autoscaling**: HPA configured for CPU-based scaling (scale up at 50%, scale down at 20%)
- **Observability**: Cloud Monitoring integration for metrics and logging
- **Production-Ready**: Security best practices, resource limits, and proper probes

## 🏗 Architecture

### High-Level Components

```
┌─────────────────────────────────────────────────────────────┐
│                        GCP Project                          │
│  ┌───────────────────────────────────────────────────────┐  │
│  │                    GKE Cluster                        │  │
│  │  ┌─────────────────────────────────────────────────┐  │  │
│  │  │              Control Plane                      │  │  │
│  │  │  - HPA Controller                               │  │  │
│  │  │  - Metrics Server                               │  │  │
│  │  └─────────────────────────────────────────────────┘  │  │
│  │  ┌─────────────────────────────────────────────────┐  │  │
│  │  │              Node Pool                          │  │  │
│  │  │  ┌──────────┐  ┌──────────┐  ┌──────────┐      │  │  │
│  │  │  │  Pod 1   │  │  Pod 2   │  │  Pod 3   │      │  │  │
│  │  │  │  Flask   │  │  Flask   │  │  Flask   │      │  │  │
│  │  │  └──────────┘  └──────────┘  └──────────┘      │  │  │
│  │  └─────────────────────────────────────────────────┘  │  │
│  └───────────────────────────────────────────────────────┘  │
│  ┌───────────────────────────────────────────────────────┐  │
│  │            LoadBalancer (External IP)                 │  │
│  └───────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

### Key Features

- **Terraform-Managed Infrastructure**: VPC, subnets, GKE cluster, node pools, IAM
- **Helm-Deployed Application**: Deployment, Service, HPA, ServiceAccount
- **Autoscaling Behavior**:
  - Minimum replicas: 1
  - Maximum replicas: 3
  - Scale up threshold: CPU > 50%
  - Scale down threshold: CPU < 20%
  - Scale down cooldown: 5 minutes

## ✨ Features

### Application Features
- Simple "Hello, World!" endpoint
- Health check and readiness probes
- CPU-intensive `/compute` endpoint for testing
- Pod information in responses
- Structured logging
- Graceful shutdown

### Infrastructure Features
- Standard GKE cluster (non-Autopilot)
- Custom VPC with secondary IP ranges for pods and services
- Node autoscaling (1-5 nodes)
- Workload Identity enabled
- Cloud Monitoring and Logging integration
- LoadBalancer service type
- Proper IAM roles and service accounts

### Security Features
- Non-root container execution
- Security contexts and pod security policies
- Network isolation with firewall rules
- Workload Identity for GCP API access
- Resource limits and requests

## 📦 Prerequisites

### Required Tools
```bash
# Google Cloud SDK
gcloud version # >= 450.0.0

# Terraform
terraform version # >= 1.5.0

# Kubernetes CLI
kubectl version --client # >= 1.28

# Helm
helm version # >= 3.12

# Docker
docker --version # >= 24.0

# Optional: Load testing tool
go install github.com/rakyll/hey@latest
```

### Required GCP APIs
```bash
gcloud services enable container.googleapis.com
gcloud services enable compute.googleapis.com
gcloud services enable artifactregistry.googleapis.com
gcloud services enable monitoring.googleapis.com
gcloud services enable logging.googleapis.com
```

### Required Permissions
Your GCP account needs:
- `roles/container.admin` - GKE cluster management
- `roles/compute.admin` - Network and compute resources
- `roles/iam.serviceAccountAdmin` - Service account management
- `roles/artifactregistry.admin` - Artifact Registry access

## 📁 Project Structure

```
gke-hpa-project/
├── app/
│   ├── app.py                    # Flask application
│   ├── requirements.txt          # Python dependencies
│   └── Dockerfile                # Container image definition
├── terraform/
│   ├── main.tf                   # Main infrastructure config
│   ├── variables.tf              # Input variables
│   ├── outputs.tf                # Output values
│   ├── provider.tf               # Provider configuration
│   └── terraform.tfvars.example  # Example variables file
├── helm/
│   └── flask-app/
│       ├── Chart.yaml            # Helm chart metadata
│       ├── values.yaml           # Default values
│       └── templates/
│           ├── _helpers.tpl      # Template helpers
│           ├── deployment.yaml   # Deployment manifest
│           ├── service.yaml      # Service manifest
│           ├── hpa.yaml          # HPA manifest
│           └── serviceaccount.yaml # ServiceAccount manifest
├── scripts/
│   ├── build-and-push.sh        # Build and push Docker image
│   ├── deploy.sh                 # Deploy application
│   └── load-test.sh              # Run load tests
└── README.md                     # This file
```

## 🚀 Quick Start

### 1. Clone and Configure

```bash
# Set environment variables
export PROJECT_ID="sgude-gke"
export REGION="us-central1"
export CLUSTER_NAME="gke-hpa-cluster"
export REPO_NAME="flask-app-repo"

# Authenticate
gcloud auth login
gcloud config set project $PROJECT_ID
```

### 2. Create Artifact Registry

```bash
gcloud artifacts repositories create $REPO_NAME \
    --repository-format=docker \
    --location=$REGION \
    --description="Flask app repository"

gcloud auth configure-docker ${REGION}-docker.pkg.dev
```

### 3. Build and Push Image

```bash
cd app
docker build --platform linux/amd64 -t ${REGION}-docker.pkg.dev/${PROJECT_ID}/${REPO_NAME}/flask-app:v1.1 .
docker push ${REGION}-docker.pkg.dev/${PROJECT_ID}/${REPO_NAME}/flask-app:v1.1
```

### 4. Deploy Infrastructure

```bash
cd ../terraform
cp terraform.tfvars.example terraform.tfvars

# Edit terraform.tfvars with your PROJECT_ID
nano terraform.tfvars

terraform init
terraform plan
terraform apply
```

### 5. Configure kubectl

```bash
gcloud container clusters get-credentials $CLUSTER_NAME \
    --region=$REGION \
    --project=$PROJECT_ID
```

### 6. Deploy Application

```bash
cd ../helm
helm install flask-app ./flask-app \
    --set image.repository=${REGION}-docker.pkg.dev/${PROJECT_ID}/${REPO_NAME}/flask-app \
    --set image.tag=v1.1
```

### 7. Verify Deployment

```bash
kubectl get pods
kubectl get svc
kubectl get hpa

# Get LoadBalancer IP
export EXTERNAL_IP=$(kubectl get svc flask-app-service -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "Application URL: http://$EXTERNAL_IP"

# Test the application
curl http://$EXTERNAL_IP/
```

## 📖 Detailed Setup

### Step 1: Infrastructure Provisioning

The Terraform configuration creates:

1. **VPC Network and Subnet**
   - Custom VPC for cluster isolation
   - Subnet with secondary IP ranges for pods and services

2. **GKE Cluster**
   - Regional cluster for high availability
   - Standard mode (not Autopilot) for full control
   - Workload Identity enabled
   - Cloud Monitoring integration

3. **Node Pool**
   - Initial size: 2 nodes
   - Machine type: e2-medium (2 vCPU, 4GB RAM)
   - Autoscaling: 1-5 nodes
   - Auto-repair and auto-upgrade enabled

4. **Service Account and IAM**
   - Custom service account for nodes
   - Minimal required permissions
   - Workload Identity bindings

5. **Firewall Rules**
   - Health check ingress
   - Internal cluster communication

### Step 2: Application Deployment

The Helm chart deploys:

1. **Deployment**
   - Flask application pods
   - Resource requests: 200m CPU, 256Mi memory
   - Resource limits: 500m CPU, 512Mi memory
   - Liveness and readiness probes
   - Pod environment variables

2. **Service**
   - LoadBalancer type
   - Exposes port 80, targets port 8080
   - Health check configuration

3. **HorizontalPodAutoscaler**
   - Targets: 50% CPU utilization
   - Min replicas: 1
   - Max replicas: 3
   - Custom scaling behavior

4. **ServiceAccount**
   - Workload Identity annotations
   - Minimal permissions

## 🧪 Testing Autoscaling

### Manual Testing

```bash
# Get LoadBalancer IP
export EXTERNAL_IP=$(kubectl get svc flask-app-service -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

# Test basic endpoint
curl http://$EXTERNAL_IP/

# Generate CPU load
curl "http://$EXTERNAL_IP/compute?duration=2"

# Watch HPA in real-time
kubectl get hpa -w

# Monitor pods
watch kubectl get pods

# View metrics
kubectl top pods
```

### Automated Load Test

Use the provided script:

```bash
cd scripts
chmod +x load-test.sh
./load-test.sh $EXTERNAL_IP
```

The script performs:
1. **Phase 1** (3 min): Heavy load → triggers scale-up
2. **Phase 2** (2 min): Stabilization period
3. **Phase 3** (2 min): Light load → triggers scale-down
4. **Phase 4** (5 min): Monitor scale-down

### Expected Behavior

| Time | Action | CPU Usage | Pods | Notes |
|------|--------|-----------|------|-------|
| 0:00 | Initial state | Low | 1 | Baseline |
| 0:30 | Load starts | >50% | 1→2 | First scale-up |
| 1:00 | Sustained load | >50% | 2→3 | Second scale-up |
| 3:00 | Load stops | Decreasing | 3 | Cooldown begins |
| 8:00 | Low usage | <20% | 3→2 | First scale-down |
| 13:00 | Continued low | <20% | 2→1 | Second scale-down |

## 📊 Monitoring

### Kubernetes Metrics

```bash
# HPA status
kubectl describe hpa flask-app-hpa

# Pod metrics
kubectl top pods

# Node metrics
kubectl top nodes

# View events
kubectl get events --sort-by='.lastTimestamp'

# Pod logs
kubectl logs -l app=flask-app -f
```

### Cloud Monitoring

Access in GCP Console:
1. Navigate to **Monitoring → Dashboards**
2. Select **GKE** dashboard
3. Filter by cluster name

Key metrics to monitor:
- CPU utilization per pod
- Memory usage
- Request rate
- Response latency
- HPA scaling events

### Custom Queries

```bash
# View HPA decisions
kubectl describe hpa flask-app-hpa | grep -A 5 "Conditions"

# Check pod resource usage
kubectl describe pod <pod-name> | grep -A 5 "Limits"

# View scaling events
kubectl get events --field-selector involvedObject.name=flask-app-hpa
```

## 🔧 Troubleshooting

### HPA Shows "Unknown" for CPU

**Problem**: HPA cannot read CPU metrics

**Solution**:
```bash
# Check if metrics-server is running
kubectl get deployment metrics-server -n kube-system

# View metrics-server logs
kubectl logs -n kube-system -l k8s-app=metrics-server

# Verify resource requests are set
kubectl describe deployment flask-app | grep -A 5 "Requests"
```

### Pods Not Scaling

**Problem**: HPA not triggering scale events

**Diagnosis**:
```bash
# Check HPA configuration
kubectl describe hpa flask-app-hpa

# Verify current CPU usage
kubectl top pods

# Check if CPU is above/below threshold
kubectl get hpa flask-app-hpa
```

**Common causes**:
- Resource requests not set (HPA cannot calculate percentage)
- CPU usage not reaching threshold
- Cooldown period active
- Max replicas already reached

### LoadBalancer Pending

**Problem**: Service stuck in "Pending" state

**Solution**:
```bash
# Check service status
kubectl describe svc flask-app-service

# View GCP load balancer
gcloud compute forwarding-rules list

# Check firewall rules
gcloud compute firewall-rules list
```

### Image Pull Errors

**Problem**: Cannot pull image from Artifact Registry

**Solution**:
```bash
# Verify image exists
gcloud artifacts docker images list ${REGION}-docker.pkg.dev/${PROJECT_ID}/${REPO_NAME}

# Check node service account permissions
kubectl describe pod <pod-name> | grep "Failed"

# Verify IAM roles
gcloud projects get-iam-policy $PROJECT_ID \
    --flatten="bindings[].members" \
    --filter="bindings.members:serviceAccount:<SA_EMAIL>"
```

### High Memory Usage

**Problem**: Pods being OOMKilled

**Solution**:
```bash
# Check pod status
kubectl describe pod <pod-name>

# Increase memory limits in values.yaml
resources:
  limits:
    memory: 1Gi
  requests:
    memory: 512Mi

# Upgrade Helm release
helm upgrade flask-app ./helm/flask-app
```

## 🔄 CI/CD Integration

### GitHub Actions Example

Create `.github/workflows/deploy.yml`:

```yaml
name: Build and Deploy

on:
  push:
    branches: [ main ]

env:
  PROJECT_ID: ${{ secrets.GCP_PROJECT_ID }}
  REGION: us-central1
  CLUSTER_NAME: gke-hpa-cluster
  REPO_NAME: flask-app-repo

jobs:
  deploy:
    runs-on: ubuntu-latest
    
    steps:
    - uses: actions/checkout@v3
    
    - id: auth
      uses: google-github-actions/auth@v1
      with:
        credentials_json: ${{ secrets.GCP_SA_KEY }}
    
    - name: Set up Cloud SDK
      uses: google-github-actions/setup-gcloud@v1
    
    - name: Configure Docker
      run: gcloud auth configure-docker $REGION-docker.pkg.dev
    
    - name: Build and Push
      run: |
        cd app
        IMAGE=$REGION-docker.pkg.dev/$PROJECT_ID/$REPO_NAME/flask-app:$GITHUB_SHA
        docker build -t $IMAGE .
        docker push $IMAGE
    
    - name: Get GKE Credentials
      run: |
        gcloud container clusters get-credentials $CLUSTER_NAME \
          --region $REGION
    
    - name: Deploy to GKE
      run: |
        helm upgrade --install flask-app ./helm/flask-app \
          --set image.repository=$REGION-docker.pkg.dev/$PROJECT_ID/$REPO_NAME/flask-app \
          --set image.tag=$GITHUB_SHA \
          --wait
```

### Cloud Build Example

Create `cloudbuild.yaml`:

```yaml
steps:
# Build Docker image
- name: 'gcr.io/cloud-builders/docker'
  args:
  - 'build'
  - '-t'
  - '${_REGION}-docker.pkg.dev/${PROJECT_ID}/${_REPO_NAME}/flask-app:$SHORT_SHA'
  - './app'

# Push to Artifact Registry
- name: 'gcr.io/cloud-builders/docker'
  args:
  - 'push'
  - '${_REGION}-docker.pkg.dev/${PROJECT_ID}/${_REPO_NAME}/flask-app:$SHORT_SHA'

# Deploy with Helm
- name: 'gcr.io/$PROJECT_ID/helm'
  args:
  - 'upgrade'
  - '--install'
  - 'flask-app'
  - './helm/flask-app'
  - '--set'
  - 'image.repository=${_REGION}-docker.pkg.dev/${PROJECT_ID}/${_REPO_NAME}/flask-app'
  - '--set'
  - 'image.tag=$SHORT_SHA'
  env:
  - 'CLOUDSDK_COMPUTE_REGION=${_REGION}'
  - 'CLOUDSDK_CONTAINER_CLUSTER=${_CLUSTER_NAME}'

substitutions:
  _REGION: 'us-central1'
  _REPO_NAME: 'flask-app-repo'
  _CLUSTER_NAME: 'gke-hpa-cluster'

options:
  logging: CLOUD_LOGGING_ONLY
```

## 🧹 Cleanup

### Remove Application

```bash
# Uninstall Helm release
helm uninstall flask-app

# Verify removal
kubectl get all -l app=flask-app
```

### Destroy Infrastructure

```bash
cd terraform
terraform destroy

# Confirm with 'yes'
```

### Delete Artifact Registry

```bash
gcloud artifacts repositories delete $REPO_NAME \
    --location=$REGION \
    --quiet
```

### Complete Cleanup

```bash
# Delete everything
helm uninstall flask-app
cd terraform && terraform destroy -auto-approve
gcloud artifacts repositories delete $REPO_NAME --location=$REGION --quiet

# Verify no resources remain
gcloud compute instances list
gcloud container clusters list
gcloud compute networks list
```

## 📚 Additional Resources

### Documentation
- [GKE Documentation](https://cloud.google.com/kubernetes-engine/docs)
- [Horizontal Pod Autoscaler](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/)
- [Terraform GCP Provider](https://registry.terraform.io/providers/hashicorp/google/latest/docs)
- [Helm Documentation](https://helm.sh/docs/)

### Best Practices
- [GKE Best Practices](https://cloud.google.com/kubernetes-engine/docs/best-practices)
- [GKE Security Hardening](https://cloud.google.com/kubernetes-engine/docs/how-to/hardening-your-cluster)
- [Cost Optimization for GKE](https://cloud.google.com/kubernetes-engine/docs/best-practices/cost-optimization)

### Tools
- [kubectl Cheat Sheet](https://kubernetes.io/docs/reference/kubectl/cheatsheet/)
- [hey - HTTP load generator](https://github.com/rakyll/hey)
- [k9s - Kubernetes CLI UI](https://k9scli.io/)
- [Lens - Kubernetes IDE](https://k8slens.dev/)

