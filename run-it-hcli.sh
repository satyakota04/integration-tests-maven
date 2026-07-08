#!/usr/bin/env bash
# Run integration tests via hcli with TI agent attached (local agent, no download).
# Assumes services are already running (run-shipping.sh, run-inventory.sh, run-order.sh).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- hcli binary (built from HCli repo) ---
HCLI_BIN="${HCLI_BIN:-/Users/satya/Git/HCli/hcli}"

# --- Agent artifacts (built from ti-agents repo) ---
AGENT_JAR="${TI_AGENT_JAR:-/Users/satya/Git/ti-agents/ti-agent/src/java/java-agent-trampoline/build/libs/java-agent-trampoline.jar}"
NATIVE_AGENT_PATH="${HARNESS_TI_AGENT_PATH:-/Users/satya/Git/ti-agents/ti-agent/src/ti.agent/bin/Release/net8.0/osx-arm64/native/ti-agent.dylib}"

TI_BASE="${TI_BASE:-/tmp/ti-it-hcli}"
TI_DATA_DIR="$TI_BASE"
RUNNER_DIR="$TI_BASE/runner"
LOG_LEVEL="${TI_LOG_LEVEL:-5}"

require_file() {
  if [[ ! -f "$1" ]]; then
    echo "Missing file: $1" >&2
    exit 1
  fi
}

echo "========================================"
echo "Integration Tests - hcli + TI agent"
echo "========================================"
echo ""

# --- Pre-flight checks ---
require_file "$AGENT_JAR"
require_file "$NATIVE_AGENT_PATH"
if [[ ! -f "$HCLI_BIN" ]]; then
  echo "hcli binary not found at $HCLI_BIN"
  echo "Build it with: cd /Users/satya/Git/HCli && make build"
  exit 1
fi

echo "hcli binary:    $HCLI_BIN"
echo "Agent jar:      $AGENT_JAR"
echo "Native agent:   $NATIVE_AGENT_PATH"
echo "TI data dir:    $TI_DATA_DIR"
echo ""

# --- Create services.yaml for hcli ---
mkdir -p "$TI_DATA_DIR"
cat > "$TI_DATA_DIR/services.yaml" <<EOF
services:
  - localhost:8081
  - localhost:8082
  - localhost:8083
EOF
echo "Created services.yaml: $TI_DATA_DIR/services.yaml"
echo ""

# --- Write agent configs manually (skip hcli agent download) ---
echo "Writing agent configs..."
mkdir -p "$RUNNER_DIR/native"
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
echo "  Java agent config:   $RUNNER_DIR/config.ini"
echo "  Native agent config: $RUNNER_DIR/native-config.json"
echo ""

# --- Set required env vars for hcli + integration tests ---
export CI_ENABLE_HCLI_FOR_INTEGRATION_TESTS=true
export HARNESS_TI_AGENT_PATH="$NATIVE_AGENT_PATH"
export TI_AGENT_CONFIG="$RUNNER_DIR/native-config.json"
export CI_REPO_LINK="https://github.com/harness-community/integration-tests-maven.git"
export HARNESS_ACCOUNT_ID="test-account"
export HARNESS_ORG_ID="test-org"
export HARNESS_PROJECT_ID="test-project"
export HARNESS_PIPELINE_ID="test-pipeline"
export HARNESS_BUILD_ID="test-build-$(date +%s)"
export HARNESS_STAGE_ID="test-stage"
export HARNESS_STEP_ID="test-step"
export HARNESS_PARENT_UNIQUE_ID=""
export HARNESS_EXECUTION_ID="test-exec-$(date +%s)"

# For VM mode (HTTP upload to ti-service) - set dummy endpoint for local testing
export HARNESS_INFRA="VM"
export HARNESS_TI_SERVICE_ENDPOINT="http://localhost:9999"  # dummy - will fail gracefully
export HARNESS_TI_SERVICE_TOKEN="dummy-token"

echo "Environment:"
echo "  CI_ENABLE_HCLI_FOR_INTEGRATION_TESTS=true"
echo "  HARNESS_INFRA=$HARNESS_INFRA"
echo "  HARNESS_BUILD_ID=$HARNESS_BUILD_ID"
echo "  HARNESS_EXECUTION_ID=$HARNESS_EXECUTION_ID"
echo ""

# --- Run integration tests via hcli ---
echo "Running integration tests via hcli (no agent download, manual config)..."
cd "$SCRIPT_DIR"

TEST_EXIT=0
"$HCLI_BIN" htx \
  --ti-data-dir="$TI_DATA_DIR" \
  --services-file="$TI_DATA_DIR/services.yaml" \
  --language=java \
  --disable-agents \
  -- mvn -f integration-tests/pom.xml test \
     -DargLine="-javaagent:$AGENT_JAR=$RUNNER_DIR/config.ini" \
  || TEST_EXIT=$?

echo ""
if [[ "$TEST_EXIT" -eq 0 ]]; then
  echo "Tests: PASSED"
else
  echo "Tests: FAILED (exit $TEST_EXIT)"
fi

# Give the agent a moment to flush
sleep 2

# --- Show call-graph locations ---
echo ""
echo "========================================"
echo "Call-graph output"
echo "========================================"

echo "Looking in: $RUNNER_DIR"
if [[ -d "$RUNNER_DIR" ]]; then
  echo ""
  echo "Unified IT CG files:"
  find "$RUNNER_DIR" -type f -name 'unified-cg-*.ndjson' 2>/dev/null || echo "  (none)"
else
  echo "Runner directory not found: $RUNNER_DIR"
fi

echo ""
exit "$TEST_EXIT"
