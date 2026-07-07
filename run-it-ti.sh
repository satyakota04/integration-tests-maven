#!/usr/bin/env bash
# Run ONLY the integration tests with the TI agent attached to the forked
# test JVM (via surefire argLine). Assumes you have already started the
# 3 services yourself (run-shipping.sh / run-inventory.sh / run-order.sh).
# At the end it prints the call-graph file location for the test runner.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- Agent artifacts (built from the ti-agents repo) ---
AGENT_JAR="${TI_AGENT_JAR:-/Users/satya/Git/ti-agents/ti-agent/src/java/java-agent-trampoline/build/libs/java-agent-trampoline.jar}"
NATIVE_AGENT_PATH="${HARNESS_TI_AGENT_PATH:-/Users/satya/Git/ti-agents/ti-agent/src/ti.agent/bin/Release/net8.0/osx-arm64/native/ti-agent.dylib}"

TI_BASE="${TI_BASE:-/tmp/ti-it}"
RUNNER_DIR="$TI_BASE/runner"
LOG_LEVEL="${TI_LOG_LEVEL:-5}"

require_file() {
  if [[ ! -f "$1" ]]; then
    echo "Missing file: $1" >&2
    exit 1
  fi
}

emit_cg() {
  local label="$1"
  local dir="$2"
  local found=0
  if [[ -d "$dir" ]]; then
    while IFS= read -r -d '' f; do
      echo "  $label: $f"
      found=1
    done < <(find "$dir" -type f \( -name 'cg_*.json' -o -name 'cg_*.csv' \) -print0 2>/dev/null)
  fi
  if [[ "$found" -eq 0 ]]; then
    echo "  $label: (no cg files found under $dir)"
  fi
}

echo "========================================"
echo "Integration Tests - TI agent on test runner"
echo "========================================"
echo ""

# --- Pre-flight: agent artifacts ---
require_file "$AGENT_JAR"
require_file "$NATIVE_AGENT_PATH"
echo "Agent jar:      $AGENT_JAR"
echo "Native agent:   $NATIVE_AGENT_PATH"
echo ""

# --- Write the test-runner agent config ---
echo "Writing test-runner agent config..."
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
echo "  Native agent log:    $RUNNER_DIR/native-agent.log"
echo "  Call-graph output:   $RUNNER_DIR/native/cg_*.{json,csv}"
echo ""

# --- Run integration tests with the agent attached to the forked test JVM ---
echo "Running integration tests (agent attached to forked test JVM via argLine)..."
export HARNESS_TI_AGENT_PATH="$NATIVE_AGENT_PATH"
export TI_AGENT_CONFIG="$RUNNER_DIR/native-config.json"

# Surefire's argLine parameter is bound to the -DargLine property; the forked
# test JVM (default forkCount=1) inherits these env vars, so the native agent
# can be located and configured.
TEST_EXIT=0
mvn -f "$SCRIPT_DIR/integration-tests/pom.xml" test \
  -DargLine="-javaagent:$AGENT_JAR=$RUNNER_DIR/config.ini" \
  || TEST_EXIT=$?

echo ""
if [[ "$TEST_EXIT" -eq 0 ]]; then
  echo "Tests: PASSED"
else
  echo "Tests: FAILED (exit $TEST_EXIT)"
fi

# Give the agent a moment to flush before reading the output dir.
sleep 2

# --- Emit call-graph location ---
echo ""
echo "========================================"
echo "Call-graph output location"
echo "========================================"
emit_cg "test-runner" "$RUNNER_DIR/native"
echo ""

exit "$TEST_EXIT"
