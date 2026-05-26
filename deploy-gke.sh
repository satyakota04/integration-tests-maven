#!/bin/bash
set -e

# Check required environment variable
if [ -z "$DOCKER_USER" ]; then
  echo "ERROR: DOCKER_USER environment variable must be set"
  echo "Usage: DOCKER_USER=your-dockerhub-username ./deploy-gke.sh"
  exit 1
fi

# Get git short SHA for image tagging
GIT_SHA=$(git rev-parse --short HEAD)

echo "==> Building Maven artifacts..."
mvn clean package -DskipTests

echo ""
echo "==> Building and pushing Docker images..."

# Build and push shipping-service
cd shipping-service
docker build --platform linux/amd64 -t ${DOCKER_USER}/shipping-service:${GIT_SHA} -t ${DOCKER_USER}/shipping-service:latest .
docker push ${DOCKER_USER}/shipping-service:${GIT_SHA}
docker push ${DOCKER_USER}/shipping-service:latest
cd ..

# Build and push inventory-service
cd inventory-service
docker build --platform linux/amd64 -t ${DOCKER_USER}/inventory-service:${GIT_SHA} -t ${DOCKER_USER}/inventory-service:latest .
docker push ${DOCKER_USER}/inventory-service:${GIT_SHA}
docker push ${DOCKER_USER}/inventory-service:latest
cd ..

# Build and push order-service
cd order-service
docker build --platform linux/amd64 -t ${DOCKER_USER}/order-service:${GIT_SHA} -t ${DOCKER_USER}/order-service:latest .
docker push ${DOCKER_USER}/order-service:${GIT_SHA}
docker push ${DOCKER_USER}/order-service:latest
cd ..

echo ""
echo "==> Applying Kubernetes manifests..."

# Create namespace
kubectl apply -f k8s/namespace.yaml

# Substitute DOCKER_USER and GIT_SHA in manifests and apply
export GIT_SHA
for manifest in k8s/*.yaml; do
  if [ "$manifest" != "k8s/namespace.yaml" ]; then
    envsubst < "$manifest" | kubectl apply -f -
  fi
done

echo ""
echo "==> Waiting for deployments to be ready..."
kubectl rollout status deployment/shipping-service -n integration-tests
kubectl rollout status deployment/inventory-service -n integration-tests
kubectl rollout status deployment/order-service -n integration-tests

echo ""
echo "==> Deployment complete!"
echo "To view pods: kubectl get pods -n integration-tests"
echo "To run tests: ./run-it-gke.sh"
