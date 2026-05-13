#!/bin/bash
set -e

echo "========================================"
echo "Multi-Service Integration Test Runner"
echo "========================================"

# Build all services
echo ""
echo "[1/4] Building all services..."
mvn clean package -DskipTests

# Start shipping service (port 8083)
echo ""
echo "[2/4] Starting shipping-service on port 8083..."
java -jar shipping-service/target/shipping-service-1.0-SNAPSHOT.jar &
SHIPPING_PID=$!
sleep 3

# Start inventory service (port 8082)
echo ""
echo "[3/4] Starting inventory-service on port 8082..."
java -jar inventory-service/target/inventory-service-1.0-SNAPSHOT.jar &
INVENTORY_PID=$!
sleep 5

# Start order service (port 8081)
echo ""
echo "[4/4] Starting order-service on port 8081..."
java -jar order-service/target/order-service-1.0-SNAPSHOT.jar &
ORDER_PID=$!
sleep 5

# Verify services are running
echo ""
echo "Verifying services..."
curl -s http://localhost:8083/eta/TEST-SKU > /dev/null && echo "✓ Shipping service (8083) is ready"
curl -s http://localhost:8082/stock/TEST-SKU > /dev/null && echo "✓ Inventory service (8082) is ready"
curl -s -X POST http://localhost:8081/orders -H "Content-Type: application/json" -d '{"sku":"TEST","quantity":1}' > /dev/null && echo "✓ Order service (8081) is ready"

# Run integration tests
echo ""
echo "========================================"
echo "Running Integration Tests"
echo "========================================"
cd integration-tests
mvn test

# Capture test result
TEST_EXIT_CODE=$?

# Cleanup
echo ""
echo "========================================"
echo "Cleaning up services..."
echo "========================================"
kill $ORDER_PID 2>/dev/null || true
kill $INVENTORY_PID 2>/dev/null || true
kill $SHIPPING_PID 2>/dev/null || true

echo "✓ All services stopped"

# Exit with test result
exit $TEST_EXIT_CODE
