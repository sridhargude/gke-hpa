from flask import Flask, jsonify, request
import os
import logging
import time
import socket
from datetime import datetime

app = Flask(__name__)

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Get pod information
POD_NAME = os.environ.get('POD_NAME', 'unknown-pod')
POD_NAMESPACE = os.environ.get('POD_NAMESPACE', 'default')
POD_IP = os.environ.get('POD_IP', socket.gethostbyname(socket.gethostname()))

@app.route('/')
def hello():
    """Main endpoint returning Hello World"""
    logger.info(f"Request received on pod {POD_NAME}")
    
    response = {
        "message": "Hello, World!",
        "pod_name": POD_NAME,
        "pod_namespace": POD_NAMESPACE,
        "pod_ip": POD_IP,
        "timestamp": datetime.utcnow().isoformat(),
        "version": "1.0"
    }
    
    return jsonify(response)

@app.route('/health')
def health():
    """Health check endpoint for Kubernetes probes"""
    return jsonify({
        "status": "healthy",
        "pod_name": POD_NAME,
        "timestamp": datetime.utcnow().isoformat()
    }), 200

@app.route('/ready')
def ready():
    """Readiness probe endpoint"""
    return jsonify({
        "status": "ready",
        "pod_name": POD_NAME,
        "timestamp": datetime.utcnow().isoformat()
    }), 200

@app.route('/compute')
def compute():
    """
    CPU-intensive endpoint for load testing and autoscaling demonstration
    This endpoint performs computation to increase CPU usage
    """
    logger.info(f"Compute request received on pod {POD_NAME}")
    
    # Get duration from query parameter, default to 1 second
    duration = float(request.args.get('duration', 1.0))
    duration = min(duration, 60.0)  # Cap at 60 seconds for safety
    
    start_time = time.time()
    result = 0
    
    # Perform CPU-intensive calculation
    while time.time() - start_time < duration:
        # Calculate prime numbers to consume CPU
        for i in range(1000):
            result += sum(j for j in range(2, i) if i % j == 0)
    
    elapsed = time.time() - start_time
    
    logger.info(f"Computation completed on pod {POD_NAME} in {elapsed:.2f}s")
    
    return jsonify({
        "message": "Computation completed",
        "pod_name": POD_NAME,
        "duration_requested": duration,
        "duration_actual": round(elapsed, 2),
        "result": result,
        "timestamp": datetime.utcnow().isoformat()
    })

@app.route('/metrics')
def metrics():
    """
    Basic metrics endpoint
    In production, consider using Prometheus client library
    """
    return jsonify({
        "pod_name": POD_NAME,
        "pod_namespace": POD_NAMESPACE,
        "pod_ip": POD_IP,
        "timestamp": datetime.utcnow().isoformat()
    })

@app.route('/info')
def info():
    """System information endpoint"""
    return jsonify({
        "pod_name": POD_NAME,
        "pod_namespace": POD_NAMESPACE,
        "pod_ip": POD_IP,
        "python_version": os.sys.version,
        "timestamp": datetime.utcnow().isoformat()
    })

@app.errorhandler(404)
def not_found(error):
    """Custom 404 handler"""
    return jsonify({
        "error": "Not found",
        "status": 404,
        "pod_name": POD_NAME
    }), 404

@app.errorhandler(500)
def internal_error(error):
    """Custom 500 handler"""
    logger.error(f"Internal error on pod {POD_NAME}: {error}")
    return jsonify({
        "error": "Internal server error",
        "status": 500,
        "pod_name": POD_NAME
    }), 500

if __name__ == '__main__':
    port = int(os.environ.get('PORT', 8080))
    logger.info(f"Starting Flask app on pod {POD_NAME} at port {port}")
    
    # Run with debug=False in production
    app.run(host='0.0.0.0', port=port, debug=False)