#!/bin/bash

# Build and Push Docker Image Script
# This script builds the Flask application Docker image and pushes it to Artifact Registry

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Check if required environment variables are set
if [ -z "$PROJECT_ID" ]; then
    print_error "PROJECT_ID environment variable is not set"
    echo "Usage: export PROJECT_ID=your-gcp-project-id"
    exit 1
fi

if [ -z "$REGION" ]; then
    print_warning "REGION not set, using default: us-central1"
    REGION="us-central1"
fi

if [ -z "$REPO_NAME" ]; then
    print_warning "REPO_NAME not set, using default: flask-app-repo"
    REPO_NAME="flask-app-repo"
fi

# Set version (default to v1.0 if not provided)
VERSION=${1:-v1.0}

# Construct image name
IMAGE_NAME="${REGION}-docker.pkg.dev/${PROJECT_ID}/${REPO_NAME}/flask-app"
FULL_IMAGE_NAME="${IMAGE_NAME}:${VERSION}"

print_info "Building Docker image..."
print_info "Image: ${FULL_IMAGE_NAME}"

# Navigate to app directory
cd "$(dirname "$0")/../app"

# Build the Docker image
docker build  --platform linux/amd64 -t "${FULL_IMAGE_NAME}" .

if [ $? -eq 0 ]; then
    print_info "Docker image built successfully"
else
    print_error "Failed to build Docker image"
    exit 1
fi

# Tag as latest
docker tag "${FULL_IMAGE_NAME}" "${IMAGE_NAME}:latest"

print_info "Configuring Docker authentication..."
gcloud auth configure-docker ${REGION}-docker.pkg.dev --quiet

print_info "Pushing Docker image to Artifact Registry..."
docker push "${FULL_IMAGE_NAME}"

if [ $? -eq 0 ]; then
    print_info "Docker image pushed successfully"
    print_info "Image: ${FULL_IMAGE_NAME}"
else
    print_error "Failed to push Docker image"
    exit 1
fi

# Also push latest tag
docker push "${IMAGE_NAME}:latest"

print_info "Build and push completed successfully!"
print_info ""
print_info "To deploy this image, use:"
print_info "helm upgrade --install flask-app ./helm/flask-app \\"
print_info "  --set image.repository=${IMAGE_NAME} \\"
print_info "  --set image.tag=${VERSION}"