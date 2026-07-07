#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "========================================"
echo "Integration Tests - All Services"
echo "========================================"
echo ""

# Clean old logs
echo "Cleaning old logs..."
rm -rf /tmp/ti-it/order /tmp/ti-it/inventory /tmp/ti-it/shipping
mkdir -p /tmp/ti-it/{order,inventory,shipping}

# Build services if needed
echo ""
echo "[1/5] Building services..."
if [[ ! -f "/Users/satya/Git/order-service/target/order-service-1.0-SNAPSHOT.jar" ]] || \
   [[ ! -f "/Users/satya/Git/inventory-service/target/inventory-service-1.0-SNAPSHOT.jar" ]] || \
   [[ ! -f "/Users/satya/Git/shipping-service/target/shipping-service-1.0-SNAPSHOT.jar" ]]; then
  echo "Building services from ~/Git repos..."
  mvn -f /Users/satya/Git/order-service/pom.xml clean install -DskipTests
  mvn -f /Users/satya/Git/inventory-service/pom.xml clean install -DskipTests
  mvn -f /Users/satya/Git/shipping-service/pom.xml clean install -DskipTests
else
  echo "✓ Service JARs already built"
fi

# Check agents are built
AGENT_JAR="/Users/satya/Git/ti-agents/ti-agent/src/java/java-agent-trampoline/build/libs/java-agent-trampoline.jar"
NATIVE_AGENT="/Users/satya/Git/ti-agents/ti-agent/src/ti.agent/bin/Release/net8.0/osx-arm64/native/ti-agent.dylib"

if [[ ! -f "$AGENT_JAR" ]]; then
  echo "❌ Missing Java agent. Run: ./build-ti-agent.sh"
  exit 1
fi

if [[ ! -f "$NATIVE_AGENT" ]]; then
  echo "❌ Missing native agent. Run: ./build-native-agent.sh"
  exit 1
fi

echo "✓ Agents ready"

# Start services in background
echo ""
echo "[2/5] Starting services..."

"$SCRIPT_DIR/run-shipping.sh" > /tmp/ti-it/shipping/console.log 2>&1 &
SHIPPING_PID=$!
echo "  Shipping (port 8083) - PID $SHIPPING_PID"

sleep 3

"$SCRIPT_DIR/run-inventory.sh" > /tmp/ti-it/inventory/console.log 2>&1 &
INVENTORY_PID=$!
echo "  Inventory (port 8082) - PID $INVENTORY_PID"

sleep 3

"$SCRIPT_DIR/run-order.sh" > /tmp/ti-it/order/console.log 2>&1 &
ORDER_PID=$!
echo "  Order (port 8081) - PID $ORDER_PID"

# Wait for services to be ready
echo ""
echo "[3/5] Waiting for services to be ready..."
MAX_WAIT=60
ELAPSED=0

until curl -sf http://localhost:8083/eta/TEST-SKU >/dev/null 2>&1; do
  sleep 1
  ELAPSED=$((ELAPSED + 1))
  if [[ $ELAPSED -ge $MAX_WAIT ]]; then
    echo "❌ Shipping service failed to start"
    kill $ORDER_PID $INVENTORY_PID $SHIPPING_PID 2>/dev/null || true
    exit 1
  fi
done
echo "  ✓ Shipping ready"

until curl -sf http://localhost:8082/stock/TEST-SKU >/dev/null 2>&1; do
  sleep 1
  ELAPSED=$((ELAPSED + 1))
  if [[ $ELAPSED -ge $MAX_WAIT ]]; then
    echo "❌ Inventory service failed to start"
    kill $ORDER_PID $INVENTORY_PID $SHIPPING_PID 2>/dev/null || true
    exit 1
  fi
done
echo "  ✓ Inventory ready"

until curl -sf -X POST http://localhost:8081/orders \
  -H "Content-Type: application/json" \
  -d '{"sku":"TEST","quantity":1}' >/dev/null 2>&1; do
  sleep 1
  ELAPSED=$((ELAPSED + 1))
  if [[ $ELAPSED -ge $MAX_WAIT ]]; then
    echo "❌ Order service failed to start"
    kill $ORDER_PID $INVENTORY_PID $SHIPPING_PID 2>/dev/null || true
    exit 1
  fi
done
echo "  ✓ Order ready"

echo ""
echo "✓ All services running!"
echo ""

# Run integration tests
echo "[4/5] Running integration tests..."
if mvn -f "$SCRIPT_DIR/integration-tests/pom.xml" test; then
  TEST_RESULT="✓ Tests PASSED"
  TEST_EXIT=0
else
  TEST_RESULT="❌ Tests FAILED"
  TEST_EXIT=1
fi

# Check classification
echo ""
echo "[5/5] Checking class classification..."
sleep 2  # Give agents time to flush logs
"$SCRIPT_DIR/check-all-classification.sh"

# Cleanup
echo ""
echo "========================================"
echo "Stopping services..."
echo "========================================"
kill $ORDER_PID 2>/dev/null && echo "  Stopped order-service" || true
kill $INVENTORY_PID 2>/dev/null && echo "  Stopped inventory-service" || true
kill $SHIPPING_PID 2>/dev/null && echo "  Stopped shipping-service" || true

echo ""
echo "========================================"
echo "Summary"
echo "========================================"
echo "Test Result: $TEST_RESULT"
echo ""
echo "Logs available at:"
echo "  /tmp/ti-it/order/native-agent.log"
echo "  /tmp/ti-it/inventory/native-agent.log"
echo "  /tmp/ti-it/shipping/native-agent.log"
echo ""
echo "Call graphs available at:"
echo "  /tmp/ti-it/order/cg_*.json"
echo "  /tmp/ti-it/inventory/cg_*.json"
echo "  /tmp/ti-it/shipping/cg_*.json"

exit $TEST_EXIT
