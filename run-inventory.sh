#!/usr/bin/env bash
set -euo pipefail

AGENT_JAR="/Users/satya/Git/ti-agents/ti-agent/src/java/java-agent-trampoline/build/libs/java-agent-trampoline.jar"
NATIVE_AGENT_PATH="${HARNESS_TI_AGENT_PATH:-/Users/satya/Git/ti-agents/ti-agent/src/ti.agent/bin/Release/net8.0/osx-arm64/native/ti-agent.dylib}"

if [[ ! -f "$AGENT_JAR" ]]; then
  echo "Missing java agent jar: $AGENT_JAR" >&2
  exit 1
fi

if [[ ! -f "$NATIVE_AGENT_PATH" ]]; then
  echo "Missing native agent library: $NATIVE_AGENT_PATH" >&2
  exit 1
fi

mkdir -p /tmp/ti-it/inventory

echo "Writing agent config files for inventory-service..."
cat > /tmp/ti-it/inventory/config.ini <<'EOF'
outDir: /tmp/ti-it/inventory
logLevel: 5
logConsole: false
packageInference: false
EOF

cat > /tmp/ti-it/inventory/native-config.json <<EOF
{
  "outdir": "/tmp/ti-it/inventory/native",
  "connectorPath": "$AGENT_JAR",
  "logging": {
    "level": "Information",
    "console": "false",
    "file": "true",
    "filePath": "/tmp/ti-it/inventory/native-agent.log"
  }
}
EOF

echo "✓ Config written to /tmp/ti-it/inventory/"
echo "  Java agent config: /tmp/ti-it/inventory/config.ini"
echo "  Native agent config: /tmp/ti-it/inventory/native-config.json"
echo "  Native agent logs: /tmp/ti-it/inventory/native-agent.log"
echo ""
echo "Starting inventory-service (port 8082) with TI agent..."
echo ""

export HARNESS_TI_AGENT_PATH="$NATIVE_AGENT_PATH"
export TI_AGENT_CONFIG="/tmp/ti-it/inventory/native-config.json"

java "-javaagent:$AGENT_JAR=/tmp/ti-it/inventory/config.ini" \
  -jar /Users/satya/Git/inventory-service/target/inventory-service-1.0-SNAPSHOT.jar
