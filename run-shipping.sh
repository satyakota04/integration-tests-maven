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

mkdir -p /tmp/ti-it/shipping

echo "Writing agent config files for shipping-service..."
cat > /tmp/ti-it/shipping/config.ini <<'EOF'
outDir: /tmp/ti-it/shipping
logLevel: 5
logConsole: false
packageInference: false
EOF

cat > /tmp/ti-it/shipping/native-config.json <<EOF
{
  "outdir": "/tmp/ti-it/shipping/native",
  "connectorPath": "$AGENT_JAR",
  "logging": {
    "level": "Information",
    "console": "false",
    "file": "true",
    "filePath": "/tmp/ti-it/shipping/native-agent.log"
  }
}
EOF

echo "✓ Config written to /tmp/ti-it/shipping/"
echo "  Java agent config: /tmp/ti-it/shipping/config.ini"
echo "  Native agent config: /tmp/ti-it/shipping/native-config.json"
echo "  Native agent logs: /tmp/ti-it/shipping/native-agent.log"
echo ""
echo "Starting shipping-service (port 8083) with TI agent..."
echo ""

export HARNESS_TI_AGENT_PATH="$NATIVE_AGENT_PATH"
export TI_AGENT_CONFIG="/tmp/ti-it/shipping/native-config.json"

java "-javaagent:$AGENT_JAR=/tmp/ti-it/shipping/config.ini" \
  -jar /Users/satya/Git/shipping-service/target/shipping-service-1.0-SNAPSHOT.jar
