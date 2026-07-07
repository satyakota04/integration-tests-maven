#!/usr/bin/env bash
set -euo pipefail

echo "Building Java agent (ByteBuddy instrumentation + trampoline)..."
bash /Users/satya/Git/ti-agents/ti-agent/tools/gradlew \
  -p /Users/satya/Git/ti-agents/ti-agent/src/java \
  :java-agent:build :java-agent-trampoline:build \
  -x test \
  --no-daemon

echo "✓ Java agent built:"
echo "  - trampoline: /Users/satya/Git/ti-agents/ti-agent/src/java/java-agent-trampoline/build/libs/java-agent-trampoline.jar"
echo "  - main agent: /Users/satya/Git/ti-agents/ti-agent/src/java/java-agent/build/libs/java-agent.jar"
