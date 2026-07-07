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

mkdir -p /tmp/ti-it/order

echo "Writing agent config files for order-service..."
cat > /tmp/ti-it/order/config.ini <<'EOF'
outDir: /tmp/ti-it/order
logLevel: 5
logConsole: false
packageInference: false
EOF

cat > /tmp/ti-it/order/native-config.json <<EOF
{
  "outdir": "/tmp/ti-it/order/native",
  "connectorPath": "$AGENT_JAR",
  "logging": {
    "level": "Information",
    "console": "false",
    "file": "true",
    "filePath": "/tmp/ti-it/order/native-agent.log"
  }
}
EOF

echo "✓ Config written to /tmp/ti-it/order/"
echo "  Java agent config: /tmp/ti-it/order/config.ini"
echo "  Native agent config: /tmp/ti-it/order/native-config.json"
echo "  Native agent logs: /tmp/ti-it/order/native-agent.log"
echo ""
echo "Starting order-service (port 8081) with TI agent..."
echo ""

export HARNESS_TI_AGENT_PATH="$NATIVE_AGENT_PATH"
export TI_AGENT_CONFIG="/tmp/ti-it/order/native-config.json"

java "-javaagent:$AGENT_JAR=/tmp/ti-it/order/config.ini" \
  -jar /Users/satya/Git/order-service/target/order-service-1.0-SNAPSHOT.jar
