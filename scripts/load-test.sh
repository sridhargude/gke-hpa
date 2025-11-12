#!/bin/bash

# Load Test Script
# This script generates load on the Flask application to trigger HPA

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
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

print_result() {
    echo -e "${CYAN}[RESULT]${NC} $1"
}

# Check if target URL is provided
if [ -z "$1" ]; then
    # Try to get LoadBalancer IP from kubectl
    EXTERNAL_IP=$(kubectl get svc flask-app-service -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)
    
    if [ -z "$EXTERNAL_IP" ]; then
        print_error "No target URL provided and cannot determine LoadBalancer IP"
        echo "Usage: $0 <target-url>"
        echo "Example: $0 http://34.123.45.67"
        exit 1
    else
        TARGET_URL="http://${EXTERNAL_IP}"
        print_info "Using LoadBalancer IP: ${EXTERNAL_IP}"
    fi
else
    TARGET_URL=$1
fi

# Check if hey is installed
if ! command -v hey &> /dev/null; then
    print_warning "hey is not installed. Installing..."
    
    if command -v go &> /dev/null; then
        go install github.com/rakyll/hey@latest
        print_info "hey installed successfully"
    else
        print_error "Go is not installed. Please install Go or 'hey' manually."
        print_info "Alternative: Use Apache Bench (ab) or curl in a loop"
        echo ""
        echo "Example with curl:"
        echo "while true; do curl ${TARGET_URL}/compute?duration=2; done"
        exit 1
    fi
fi

# Function to monitor HPA
monitor_hpa() {
    print_step "Opening HPA monitor in background..."
    
    # Start HPA monitoring in background
    (
        echo ""
        echo "========================================="
        echo "HPA Status (Ctrl+C to stop)"
        echo "========================================="
        kubectl get hpa -w
    ) &
    
    HPA_PID=$!
    echo $HPA_PID > /tmp/hpa_monitor.pid
}

# Function to monitor pods
monitor_pods() {
    print_step "Pod status:"
    kubectl get pods -l app=flask-app
}

# Cleanup function
cleanup() {
    print_info "Stopping monitors..."
    if [ -f /tmp/hpa_monitor.pid ]; then
        kill $(cat /tmp/hpa_monitor.pid) 2>/dev/null || true
        rm /tmp/hpa_monitor.pid
    fi
}

trap cleanup EXIT

# Test basic connectivity
print_step "Testing connectivity to ${TARGET_URL}..."
if curl -s -f "${TARGET_URL}/health" > /dev/null; then
    print_info "Application is reachable"
else
    print_error "Cannot reach application at ${TARGET_URL}"
    exit 1
fi

echo ""
echo "========================================="
echo "Load Test Configuration"
echo "========================================="
echo "Target URL: ${TARGET_URL}/compute"
echo "Duration: 5 minutes"
echo "Concurrent requests: 50"
echo "Expected behavior:"
echo "  - Initial: 1 pod"
echo "  - Scale up when CPU > 50%"
echo "  - Max: 3 pods"
echo "  - Scale down when CPU < 20%"
echo "========================================="
echo ""

read -p "Press Enter to start load test (Ctrl+C to cancel)..."

# Show initial state
print_step "Initial state:"
monitor_pods
echo ""
kubectl get hpa
echo ""

# Start HPA monitoring
monitor_hpa

sleep 2

# Phase 1: Generate heavy load
print_step "Phase 1: Generating heavy load (3 minutes)..."
print_info "This should trigger scale-up..."
echo ""

hey -z 3m -c 10000 "${TARGET_URL}/compute?duration=60" > /tmp/load_test_phase1.txt 2>&1 &
LOAD_PID=$!

# Monitor during load
for i in {1..36}; do
    sleep 5
    echo -e "${CYAN}[$(date +%H:%M:%S)]${NC} Load test running... (${i}/36)"
    
    # Show pod status every 30 seconds
    if [ $((i % 6)) -eq 0 ]; then
        echo ""
        print_step "Current pod status:"
        monitor_pods
        echo ""
    fi
done

wait $LOAD_PID

print_result "Phase 1 complete. Check results:"
cat /tmp/load_test_phase1.txt
echo ""

# Phase 2: Let it stabilize
print_step "Phase 2: Stabilization period (2 minutes)..."
print_info "Pods should remain scaled up..."
echo ""

for i in {1..24}; do
    sleep 5
    echo -e "${CYAN}[$(date +%H:%M:%S)]${NC} Monitoring... (${i}/24)"
    
    if [ $((i % 6)) -eq 0 ]; then
        echo ""
        print_step "Current pod status:"
        monitor_pods
        echo ""
    fi
done

# Phase 3: Light load
print_step "Phase 3: Light load (2 minutes)..."
print_info "This should trigger scale-down after cooldown period..."
echo ""

hey -z 2m -c 5 "${TARGET_URL}/" > /tmp/load_test_phase3.txt 2>&1 &
LOAD_PID=$!

for i in {1..24}; do
    sleep 5
    echo -e "${CYAN}[$(date +%H:%M:%S)]${NC} Light load running... (${i}/24)"
    
    if [ $((i % 6)) -eq 0 ]; then
        echo ""
        print_step "Current pod status:"
        monitor_pods
        echo ""
    fi
done

wait $LOAD_PID

print_result "Phase 3 complete."
echo ""

# Phase 4: Monitor scale-down
print_step "Phase 4: Monitoring scale-down (5 minutes)..."
print_info "Scale-down should occur after cooldown period (default: 5 minutes)..."
echo ""

for i in {1..60}; do
    sleep 5
    echo -e "${CYAN}[$(date +%H:%M:%S)]${NC} Waiting for scale-down... (${i}/60)"
    
    if [ $((i % 12)) -eq 0 ]; then
        echo ""
        print_step "Current pod status:"
        monitor_pods
        echo ""
    fi
done

# Final status
echo ""
echo "========================================="
echo "Load Test Complete!"
echo "========================================="
echo ""

print_step "Final Status:"
monitor_pods
echo ""
kubectl get hpa
echo ""

print_info "Load test summary:"
echo "  - Phase 1 results: /tmp/load_test_phase1.txt"
echo "  - Phase 3 results: /tmp/load_test_phase3.txt"
echo ""

print_info "To view detailed HPA events:"
echo "  kubectl describe hpa flask-app-hpa"
echo ""

print_info "To view pod logs:"
echo "  kubectl logs -l app=flask-app --tail=50"