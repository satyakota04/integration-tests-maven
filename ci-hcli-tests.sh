#!/usr/bin/env bash
# CI-side runner: run the integration tests through hcli with the TI agent attached
# to the test runner, against services exposed over public ngrok tunnels.
#
# Uses pre-built linux-x64 artifacts committed to the repo under bin/:
#   bin/hcli-linux             - hcli binary (linux-x64)
#   bin/java-agent-trampoline.jar  - Java agent (platform-independent)
#   bin/ti-agent.so            - native TI agent (linux-x64)
#
# Designed to run inside the Harness CI pipeline (.harness/integration-tests-hcli.yaml)
# but is parameterized by env vars so it can be dry-run locally too.
#
# Required env:
#   ORDER_SERVICE_URL, INVENTORY_SERVICE_URL, SHIPPING_SERVICE_URL  (ngrok tunnel URLs)
# Optional env:
#   TI_DATA_DIR (default ./ti-it), TI_LOG_LEVEL (default 5)
#   TI_SERVICE_ENDPOINT (default dummy), TI_SERVICE_TOKEN (default dummy)
#   HARNESS_* context vars are auto-injected by Harness CI; fallbacks provided for dry-run.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

require_env() {
  local v="$1"
  if [[ -z "${!v:-}" ]]; then echo "Missing required env: $v" >&2; exit 1; fi
}

require_file() {
  if [[ ! -f "$1" ]]; then echo "Missing required file: $1" >&2; exit 1; fi
}

echo "========================================"
echo "CI hcli integration tests"
echo "========================================"

require_env ORDER_SERVICE_URL
require_env INVENTORY_SERVICE_URL
require_env SHIPPING_SERVICE_URL

# --- Artifacts (committed to repo under bin/) ---
HCLI_BIN="${HCLI_BIN:-$SCRIPT_DIR/bin/hcli-linux}"
AGENT_JAR="${TI_AGENT_JAR:-$SCRIPT_DIR/bin/java-agent-trampoline.jar}"
NATIVE_AGENT="${NATIVE_AGENT:-$SCRIPT_DIR/bin/ti-agent.so}"

require_file "$HCLI_BIN"
require_file "$AGENT_JAR"
require_file "$NATIVE_AGENT"
chmod +x "$HCLI_BIN"

TI_DATA_DIR="${TI_DATA_DIR:-$SCRIPT_DIR/ti-it}"
RUNNER_DIR="$TI_DATA_DIR/runner"
LOG_LEVEL="${TI_LOG_LEVEL:-5}"
mkdir -p "$RUNNER_DIR/native"

echo "hcli:        $HCLI_BIN"
echo "agent jar:   $AGENT_JAR"
echo "native lib:  $NATIVE_AGENT"
echo ""

# --- services.yaml for hcli (ngrok tunnel URLs) ---
cat > "$TI_DATA_DIR/services.yaml" <<EOF
services:
  - $ORDER_SERVICE_URL
  - $INVENTORY_SERVICE_URL
  - $SHIPPING_SERVICE_URL
EOF
echo "services.yaml: $TI_DATA_DIR/services.yaml"

# --- agent configs for the test runner ---
cat > "$RUNNER_DIR/config.ini" <<EOF
outDir: $RUNNER_DIR
logLevel: $LOG_LEVEL
logConsole: false
packageInference: false
instrPackages: com.harness.sample.
EOF

cat > "$RUNNER_DIR/native-config.json" <<EOF
{
  "outdir": "$RUNNER_DIR/native",
  "connectorPath": "$AGENT_JAR",
  "logging": {
    "level": "Information",
    "console": "false",
    "file": "true",
    "filePath": "$RUNNER_DIR/native-agent.log"
  }
}
EOF
echo "config.ini:   $RUNNER_DIR/config.ini"
echo "native cfg:   $RUNNER_DIR/native-config.json"
echo ""

# --- env for hcli + TI agent (Harness CI injects the real HARNESS_* values) ---
export CI_ENABLE_HCLI_FOR_INTEGRATION_TESTS=true
export HARNESS_TI_AGENT_PATH="$NATIVE_AGENT"
export TI_AGENT_CONFIG="$RUNNER_DIR/native-config.json"
export HARNESS_INFRA="${HARNESS_INFRA:-VM}"
export HARNESS_TI_SERVICE_ENDPOINT="${TI_SERVICE_ENDPOINT:-http://localhost:9999}"
export HARNESS_TI_SERVICE_TOKEN="${TI_SERVICE_TOKEN:-dummy-token}"
export HARNESS_ACCOUNT_ID="${HARNESS_ACCOUNT_ID:-test-account}"
export HARNESS_ORG_ID="${HARNESS_ORG_ID:-test-org}"
export HARNESS_PROJECT_ID="${HARNESS_PROJECT_ID:-test-project}"
export HARNESS_PIPELINE_ID="${HARNESS_PIPELINE_ID:-test-pipeline}"
export HARNESS_STAGE_ID="${HARNESS_STAGE_ID:-test-stage}"
export HARNESS_STEP_ID="${HARNESS_STEP_ID:-test-step}"
export HARNESS_PARENT_UNIQUE_ID="${HARNESS_PARENT_UNIQUE_ID:-}"
export HARNESS_BUILD_ID="${HARNESS_BUILD_ID:-test-build-$(date +%s)}"
export HARNESS_EXECUTION_ID="${HARNESS_EXECUTION_ID:-test-exec-$(date +%s)}"
export CI_REPO_LINK="${CI_REPO_LINK:-https://github.com/harness-community/integration-tests-maven.git}"

# --- run integration tests via hcli, agent attached to the test JVM via argLine ---
cd "$SCRIPT_DIR"
TEST_EXIT=0
"$HCLI_BIN" htx \
  --ti-data-dir="$TI_DATA_DIR" \
  --services-file="$TI_DATA_DIR/services.yaml" \
  --language=java \
  --disable-agents \
  -- mvn -f integration-tests/pom.xml test \
     -Dorder.service.url="$ORDER_SERVICE_URL" \
     -Dinventory.service.url="$INVENTORY_SERVICE_URL" \
     -Dshipping.service.url="$SHIPPING_SERVICE_URL" \
     -DargLine="-javaagent:$AGENT_JAR=$RUNNER_DIR/config.ini" \
  || TEST_EXIT=$?

echo ""
if [[ "$TEST_EXIT" -eq 0 ]]; then
  echo "Tests: PASSED"
else
  echo "Tests: FAILED (exit $TEST_EXIT)"
fi

sleep 2

echo ""
echo "========================================"
echo "Call-graph output"
echo "========================================"
echo "Looking in: $RUNNER_DIR"
find "$RUNNER_DIR" -type f -name 'unified-cg-*.ndjson' 2>/dev/null || echo "  (none)"

exit "$TEST_EXIT"
