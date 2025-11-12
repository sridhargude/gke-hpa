#!/bin/bash

# Deploy Application Script
# This script deploys the Flask application to GKE using Helm

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    print_step "Checking prerequisites..."
    
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl not found. Please install kubectl."
        exit 1
    fi
    
    if ! command -v helm &> /dev/null; then
        print_error "helm not found. Please install helm."
        exit 1
    fi
    
    print_info "All prerequisites satisfied"
}

# Check cluster connection
check_cluster() {
    print_step "Checking cluster connection..."
    
    if ! kubectl cluster-info &> /dev/null; then
        print_error "Cannot connect to Kubernetes cluster"
        print_error "Please run: gcloud container clusters get-credentials <cluster-name> --region <region>"
        exit 1
    fi
    
    CLUSTER_NAME=$(kubectl config current-context)
    print_info "Connected to cluster: ${CLUSTER_NAME}"
}

# Deploy with Helm
deploy_helm() {
    print_step "Deploying application with Helm..."
    
    cd "$(dirname "$0")/../helm"
    
    # Set default values if not provided
    IMAGE_REPO=${IMAGE_REPO:-"${REGION}-docker.pkg.dev/${PROJECT_ID}/${REPO_NAME}/flask-app"}
    IMAGE_TAG=${IMAGE_TAG:-"v1.0"}
    
    print_info "Image: ${IMAGE_REPO}:${IMAGE_TAG}"
    
    # Install or upgrade Helm release
    helm upgrade --install flask-app ./flask-app \
        --set image.repository="${IMAGE_REPO}" \
        --set image.tag="${IMAGE_TAG}" \
        --wait \
        --timeout 5m
    
    if [ $? -eq 0 ]; then
        print_info "Helm deployment successful"
    else
        print_error "Helm deployment failed"
        exit 1
    fi
}

# Wait for resources
wait_for_resources() {
    print_step "Waiting for resources to be ready..."
    
    # Wait for deployment
    print_info "Waiting for deployment..."
    kubectl wait --for=condition=available --timeout=300s deployment/flask-app
    
    # Wait for service
    print_info "Waiting for LoadBalancer IP..."
    timeout=300
    elapsed=0
    while [ $elapsed -lt $timeout ]; do
        EXTERNAL_IP=$(kubectl get svc flask-app-service -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)
        if [ -n "$EXTERNAL_IP" ]; then
            print_info "LoadBalancer IP: ${EXTERNAL_IP}"
            break
        fi
        sleep 5
        elapsed=$((elapsed + 5))
        echo -n "."
    done
    echo ""
    
    if [ -z "$EXTERNAL_IP" ]; then
        print_warning "LoadBalancer IP not assigned yet. Check status with: kubectl get svc"
    fi
}

# Display status
display_status() {
    print_step "Deployment Status"
    echo ""
    
    print_info "Pods:"
    kubectl get pods -l app=flask-app
    echo ""
    
    print_info "Service:"
    kubectl get svc flask-app-service
    echo ""
    
    print_info "HPA:"
    kubectl get hpa
    echo ""
    
    EXTERNAL_IP=$(kubectl get svc flask-app-service -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)
    
    if [ -n "$EXTERNAL_IP" ]; then
        echo -e "${GREEN}========================================${NC}"
        echo -e "${GREEN}Application deployed successfully!${NC}"
        echo -e "${GREEN}========================================${NC}"
        echo ""
        echo "Access your application at: http://${EXTERNAL_IP}"
        echo ""
        echo "Test endpoints:"
        echo "  - Hello World: curl http://${EXTERNAL_IP}/"
        echo "  - Health Check: curl http://${EXTERNAL_IP}/health"
        echo "  - CPU Load: curl http://${EXTERNAL_IP}/compute"
        echo ""
        echo "Monitor HPA:"
        echo "  kubectl get hpa -w"
        echo ""
    else
        print_warning "LoadBalancer IP not yet assigned. Please wait and check with:"
        print_warning "kubectl get svc flask-app-service"
    fi
}

# Main execution
main() {
    print_info "Starting deployment process..."
    echo ""
    
    check_prerequisites
    check_cluster
    deploy_helm
    wait_for_resources
    display_status
    
    print_info "Deployment complete!"
}

# Run main function
main