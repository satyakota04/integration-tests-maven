#!/usr/bin/env bash
# CI-side runner: run the integration tests through released hcli with the QA
# TI agent downloaded and attached automatically (JAVA_TOOL_OPTIONS).
#
# Services are expected over public ngrok tunnels (or override via env).
# No local agent jars/so, no manual config.ini / argLine — hcli handles that.
#
# Designed to run inside the Harness CI pipeline (.harness/integration-tests-hcli.yaml).
#
# Optional env (all have defaults):
#   ORDER_SERVICE_URL, INVENTORY_SERVICE_URL, SHIPPING_SERVICE_URL
#   ORDER_SERVICE_HOST, INVENTORY_SERVICE_HOST, SHIPPING_SERVICE_HOST
#   HCLI_BIN (default: bin/hcli-linux, then PATH), HARNESS_TI_DATA_DIR
#   HARNESS_* context vars are injected by the Harness CI pipeline.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "========================================"
echo "CI hcli integration tests (QA agents)"
echo "========================================"

# --- libicu required by native TI agent (NativeAOT / ti-agent.so) ---
if ! ldconfig -p 2>/dev/null | grep -q libicu; then
  echo "libicu not found — installing (required by native TI agent)..."
  if command -v apt-get >/dev/null 2>&1; then
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -qq || true
    apt-get install -y libicu-dev 2>/dev/null \
      || apt-get install -y libicu72 2>/dev/null \
      || apt-get install -y libicu74 2>/dev/null \
      || apt-get install -y libicu 2>/dev/null \
      || echo "WARNING: Could not install libicu via apt-get. Native agent may crash." >&2
  else
    echo "WARNING: No apt-get available to install libicu. Native agent may crash." >&2
  fi
fi

# --- hcli (committed linux binary, PATH, or HCLI_BIN override) ---
if [[ -z "${HCLI_BIN:-}" ]]; then
  if [[ -x "$SCRIPT_DIR/bin/hcli-linux" ]]; then
    HCLI_BIN="$SCRIPT_DIR/bin/hcli-linux"
  else
    HCLI_BIN="$(command -v hcli || true)"
  fi
fi
if [[ -z "$HCLI_BIN" || ! -x "$HCLI_BIN" ]]; then
  echo "hcli not found. Set HCLI_BIN or place bin/hcli-linux in the repo." >&2
  exit 1
fi
chmod +x "$HCLI_BIN" 2>/dev/null || true

# --- Service URLs (default to ngrok reserved domains) ---
ORDER_SERVICE_URL="${ORDER_SERVICE_URL:-https://order-kota.ngrok-free.dev}"
INVENTORY_SERVICE_URL="${INVENTORY_SERVICE_URL:-https://inventory-kota.ngrok-free.dev}"
SHIPPING_SERVICE_URL="${SHIPPING_SERVICE_URL:-https://shipping-kota.ngrok-free.dev}"

# Hostnames only for hcli services.yaml (hcli hardcodes http:// prefix)
ORDER_SERVICE_HOST="${ORDER_SERVICE_HOST:-order-kota.ngrok-free.dev}"
INVENTORY_SERVICE_HOST="${INVENTORY_SERVICE_HOST:-inventory-kota.ngrok-free.dev}"
SHIPPING_SERVICE_HOST="${SHIPPING_SERVICE_HOST:-shipping-kota.ngrok-free.dev}"

TI_DATA_DIR="${TI_DATA_DIR:-$SCRIPT_DIR/ti-it}"
mkdir -p "$TI_DATA_DIR"

echo "hcli:         $HCLI_BIN"
echo "Agent source: QA (HARNESS_TI_QA_ENV=QA_ENV_ENABLED, CI_ENABLE_RUNTESTV2_JAVA_V2_FF=true)"
echo ""

# --- services.yaml for hcli (hostnames only — hcli hardcodes http:// prefix) ---
cat > "$TI_DATA_DIR/services.yaml" <<EOF
services:
  - $ORDER_SERVICE_HOST
  - $INVENTORY_SERVICE_HOST
  - $SHIPPING_SERVICE_HOST
EOF
echo "services.yaml: $TI_DATA_DIR/services.yaml"
echo ""

# Pipeline supplies HARNESS_* (incl. HARNESS_PIPELINE_ID → --setup-agents).
# No --language: download all agents incl. Unified (dotnet QA zip with trampoline + ti-agent.so).
# CI_ENABLE_RUNTESTV2_JAVA_V2_FF: Unified wires JAVA_TOOL_OPTIONS to the trampoline.
export CI_ENABLE_HCLI_FOR_INTEGRATION_TESTS=true
export HARNESS_TI_QA_ENV=QA_ENV_ENABLED
export CI_ENABLE_RUNTESTV2_JAVA_V2_FF=true

cd "$SCRIPT_DIR"

TEST_EXIT=0
"$HCLI_BIN" htx \
  --services-file="$TI_DATA_DIR/services.yaml" \
  -- mvn -f integration-tests/pom.xml test \
     -Dorder.service.url="$ORDER_SERVICE_URL" \
     -Dinventory.service.url="$INVENTORY_SERVICE_URL" \
     -Dshipping.service.url="$SHIPPING_SERVICE_URL" \
  || TEST_EXIT=$?

echo ""
if [[ "$TEST_EXIT" -eq 0 ]]; then
  echo "Tests: PASSED"
else
  echo "Tests: FAILED (exit $TEST_EXIT)"
fi

sleep 2

CG_SEARCH_DIR="${HARNESS_TI_DATA_DIR:-$HOME/.hcli/ti-agents}"

echo ""
echo "========================================"
echo "Call-graph output"
echo "========================================"
echo "Looking in: $CG_SEARCH_DIR"
FOUND=0
while IFS= read -r -d '' f; do
  FOUND=1
  SIZE=$(wc -c < "$f" | tr -d ' ')
  echo "  $f ($SIZE bytes)"
done < <(find "$CG_SEARCH_DIR" -type f -name 'unified-cg-*.ndjson' -print0 2>/dev/null)
if [[ "$FOUND" -eq 0 ]]; then
  echo "  (none)"
fi

exit "$TEST_EXIT"
