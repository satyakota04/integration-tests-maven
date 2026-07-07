#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$SCRIPT_DIR"

AGENT_JAR="${TI_AGENT_JAR:-/Users/satya/Git/ti-agents/ti-agent/src/java/java-agent-trampoline/build/libs/java-agent-trampoline.jar}"
TI_BASE="${TI_BASE:-/tmp/ti-it}"
TI_LOG_LEVEL="${TI_LOG_LEVEL:-5}"
INSTR_PACKAGES="${INSTR_PACKAGES:-com.harness.sample.}"

usage() {
  cat <<EOF
Usage: $(basename "$0") <command>

Commands:
  build-agent      Build java-agent-trampoline.jar from /Users/satya/Git/ti-agents
  prepare          Build integration-tests-maven jars and write TI config files
  start-shipping   Start shipping-service with TI javaagent (run in its own terminal)
  start-inventory  Start inventory-service with TI javaagent (run in its own terminal)
  start-order      Start order-service with TI javaagent (run in its own terminal)
  wait             Wait until all service endpoints respond on 8081/8082/8083
  test             Run integration tests (run in a separate terminal)
  status           Print health/status for the 3 services
  stop             Stop all 3 services started on local machine

Environment overrides:
  TI_AGENT_JAR     Default: $AGENT_JAR
  TI_BASE          Default: $TI_BASE
  TI_LOG_LEVEL     Default: $TI_LOG_LEVEL
  INSTR_PACKAGES   Default: $INSTR_PACKAGES
EOF
}

require_file() {
  if [[ ! -f "$1" ]]; then
    echo "Missing file: $1" >&2
    exit 1
  fi
}

write_config() {
  local svc="$1"
  local out_dir="$TI_BASE/$svc"
  mkdir -p "$out_dir"
  cat > "$out_dir/config.ini" <<EOF
outDir: $out_dir
logLevel: $TI_LOG_LEVEL
logConsole: true
packageInference: true
instrPackages: $INSTR_PACKAGES
EOF
}

build_agent() {
  sh "/Users/satya/Git/ti-agents/ti-agent/tools/gradlew" \
    -p "/Users/satya/Git/ti-agents/ti-agent/src/java" \
    :java-agent-trampoline:build -x test --no-daemon
}

prepare() {
  mvn -f "$REPO_DIR/pom.xml" clean package -DskipTests
  write_config shipping
  write_config inventory
  write_config order
  require_file "$AGENT_JAR"
  require_file "$REPO_DIR/shipping-service/target/shipping-service-1.0-SNAPSHOT.jar"
  require_file "$REPO_DIR/inventory-service/target/inventory-service-1.0-SNAPSHOT.jar"
  require_file "$REPO_DIR/order-service/target/order-service-1.0-SNAPSHOT.jar"
  echo "Prepared."
  echo "Config files:"
  echo "  $TI_BASE/shipping/config.ini"
  echo "  $TI_BASE/inventory/config.ini"
  echo "  $TI_BASE/order/config.ini"
}

start_shipping() {
  require_file "$AGENT_JAR"
  require_file "$TI_BASE/shipping/config.ini"
  require_file "$REPO_DIR/shipping-service/target/shipping-service-1.0-SNAPSHOT.jar"
  exec java "-javaagent:$AGENT_JAR=$TI_BASE/shipping/config.ini" \
    -jar "$REPO_DIR/shipping-service/target/shipping-service-1.0-SNAPSHOT.jar"
}

start_inventory() {
  require_file "$AGENT_JAR"
  require_file "$TI_BASE/inventory/config.ini"
  require_file "$REPO_DIR/inventory-service/target/inventory-service-1.0-SNAPSHOT.jar"
  exec java "-javaagent:$AGENT_JAR=$TI_BASE/inventory/config.ini" \
    -jar "$REPO_DIR/inventory-service/target/inventory-service-1.0-SNAPSHOT.jar"
}

start_order() {
  require_file "$AGENT_JAR"
  require_file "$TI_BASE/order/config.ini"
  require_file "$REPO_DIR/order-service/target/order-service-1.0-SNAPSHOT.jar"
  exec java "-javaagent:$AGENT_JAR=$TI_BASE/order/config.ini" \
    -jar "$REPO_DIR/order-service/target/order-service-1.0-SNAPSHOT.jar"
}

wait_ready() {
  until curl -sf http://localhost:8083/eta/TEST-SKU >/dev/null; do sleep 1; done
  until curl -sf http://localhost:8082/stock/TEST-SKU >/dev/null; do sleep 1; done
  until curl -sf -X POST http://localhost:8081/orders -H "Content-Type: application/json" -d '{"sku":"TEST","quantity":1}' >/dev/null; do sleep 1; done
  echo "All services are ready."
}

run_tests() {
  mvn -f "$REPO_DIR/integration-tests/pom.xml" test
}

status() {
  set +e
  echo -n "shipping (8083): "
  curl -sf http://localhost:8083/eta/TEST-SKU >/dev/null && echo "UP" || echo "DOWN"
  echo -n "inventory (8082): "
  curl -sf http://localhost:8082/stock/TEST-SKU >/dev/null && echo "UP" || echo "DOWN"
  echo -n "order (8081): "
  curl -sf -X POST http://localhost:8081/orders -H "Content-Type: application/json" -d '{"sku":"TEST","quantity":1}' >/dev/null && echo "UP" || echo "DOWN"
  set -e
}

stop_all() {
  pkill -f "shipping-service-1.0-SNAPSHOT.jar" 2>/dev/null || true
  pkill -f "inventory-service-1.0-SNAPSHOT.jar" 2>/dev/null || true
  pkill -f "order-service-1.0-SNAPSHOT.jar" 2>/dev/null || true
  echo "Stopped shipping/inventory/order services (if running)."
}

case "${1:-}" in
  build-agent) build_agent ;;
  prepare) prepare ;;
  start-shipping) start_shipping ;;
  start-inventory) start_inventory ;;
  start-order) start_order ;;
  wait) wait_ready ;;
  test) run_tests ;;
  status) status ;;
  stop) stop_all ;;
  ""|-h|--help|help) usage ;;
  *)
    echo "Unknown command: $1" >&2
    usage
    exit 1
    ;;
esac
