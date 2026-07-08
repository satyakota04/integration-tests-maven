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
# but can be run locally too. Service URLs default to the ngrok reserved domains.
#
# Optional env (all have defaults):
#   ORDER_SERVICE_URL, INVENTORY_SERVICE_URL, SHIPPING_SERVICE_URL  (ngrok tunnel URLs)
#   TI_DATA_DIR (default ./ti-it), TI_LOG_LEVEL (default 5)
#   TI_SERVICE_ENDPOINT (default dummy), TI_SERVICE_TOKEN (default dummy)
#   HARNESS_* context vars are auto-injected by Harness CI; fallbacks provided for dry-run.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- Ensure required system libs for the native TI agent (.NET NativeAOT) ---
if ! ldconfig -p 2>/dev/null | grep -q libicu; then
  echo "libicu not found — installing (required by native TI agent)..."
  if command -v apt-get >/dev/null 2>&1; then
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -qq || true
    # Try the most common package names across Debian/Ubuntu releases
    apt-get install -y libicu-dev 2>/dev/null \
      || apt-get install -y libicu72 2>/dev/null \
      || apt-get install -y libicu74 2>/dev/null \
      || apt-get install -y libicu 2>/dev/null \
      || echo "WARNING: Could not install libicu via apt-get. Native agent may crash." >&2
  else
    echo "WARNING: No apt-get available to install libicu. Native agent may crash." >&2
  fi
  echo "libicu install check: $(ldconfig -p 2>/dev/null | grep -c libicu) libraries found"
fi

# --- Ensure binaries are executable ---
chmod +x "$SCRIPT_DIR/bin/hcli-linux" 2>/dev/null || true

require_file() {
  if [[ ! -f "$1" ]]; then echo "Missing required file: $1" >&2; exit 1; fi
}

echo "========================================"
echo "CI hcli integration tests"
echo "========================================"

# --- Service URLs (default to ngrok reserved domains) ---
# Full URLs for the test -D* props (Maven tests use these directly)
ORDER_SERVICE_URL="${ORDER_SERVICE_URL:-https://order-kota.ngrok-free.dev}"
INVENTORY_SERVICE_URL="${INVENTORY_SERVICE_URL:-https://inventory-kota.ngrok-free.dev}"
SHIPPING_SERVICE_URL="${SHIPPING_SERVICE_URL:-https://shipping-kota.ngrok-free.dev}"

# Hostnames only for hcli services.yaml (hcli hardcodes http:// prefix)
ORDER_SERVICE_HOST="${ORDER_SERVICE_HOST:-order-kota.ngrok-free.dev}"
INVENTORY_SERVICE_HOST="${INVENTORY_SERVICE_HOST:-inventory-kota.ngrok-free.dev}"
SHIPPING_SERVICE_HOST="${SHIPPING_SERVICE_HOST:-shipping-kota.ngrok-free.dev}"

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

# --- services.yaml for hcli (hostnames only — hcli hardcodes http:// prefix) ---
cat > "$TI_DATA_DIR/services.yaml" <<EOF
services:
  - $ORDER_SERVICE_HOST
  - $INVENTORY_SERVICE_HOST
  - $SHIPPING_SERVICE_HOST
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

# Install harnessti-maven-plugin into local Maven repo (not in Maven Central)
PLUGIN_JAR="$SCRIPT_DIR/bin/maven-plugin/harnessti-maven-plugin-1.0.0-SNAPSHOT.jar"
PLUGIN_POM="$SCRIPT_DIR/bin/maven-plugin/harnessti-maven-plugin-1.0.0-SNAPSHOT.pom"
if [[ -f "$PLUGIN_JAR" && -f "$PLUGIN_POM" ]]; then
  echo "Installing harnessti-maven-plugin into local Maven repo..."
  mvn install:install-file \
    -Dfile="$PLUGIN_JAR" \
    -DpomFile="$PLUGIN_POM" \
    -q
  echo "  Plugin installed."
else
  echo "WARNING: harnessti-maven-plugin not found in bin/maven-plugin/ — build may fail." >&2
fi
echo ""

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
