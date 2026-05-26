#!/bin/bash
set -e

# Store port-forward PIDs for cleanup
PIDS=()

# Cleanup function - kills port-forwards and deletes K8s resources
cleanup() {
  echo ""
  echo "==> Cleaning up..."

  # Kill port-forward processes
  for pid in "${PIDS[@]}"; do
    if kill -0 "$pid" 2>/dev/null; then
      echo "Killing port-forward process $pid"
      kill "$pid" 2>/dev/null || true
    fi
  done

  # Delete Kubernetes resources
  echo "Tearing down GKE deployments..."
  kubectl delete -f k8s/ --ignore-not-found=true

  echo "Cleanup complete."
}

# Register cleanup to run on exit (success or failure)
trap cleanup EXIT

echo "==> Starting port-forwards to GKE services..."

# Port-forward order-service
kubectl port-forward -n integration-tests svc/order-service 8081:8081 &
PID=$!
PIDS+=($PID)
echo "Port-forwarding order-service on localhost:8081 (PID: $PID)"

# Port-forward inventory-service
kubectl port-forward -n integration-tests svc/inventory-service 8082:8082 &
PID=$!
PIDS+=($PID)
echo "Port-forwarding inventory-service on localhost:8082 (PID: $PID)"

# Port-forward shipping-service
kubectl port-forward -n integration-tests svc/shipping-service 8083:8083 &
PID=$!
PIDS+=($PID)
echo "Port-forwarding shipping-service on localhost:8083 (PID: $PID)"

echo ""
echo "==> Waiting for port-forwards to be ready..."
sleep 5

# Verify connectivity
for port in 8081 8082 8083; do
  for i in {1..10}; do
    if nc -z localhost $port 2>/dev/null; then
      echo "Port $port is ready"
      break
    fi
    if [ $i -eq 10 ]; then
      echo "ERROR: Port $port did not become available"
      exit 1
    fi
    sleep 1
  done
done

echo ""
echo "==> Running integration tests..."
mvn test -pl integration-tests

echo ""
echo "==> Tests completed successfully!"
