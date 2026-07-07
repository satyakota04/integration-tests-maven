#!/usr/bin/env bash
set -euo pipefail

echo "Building native agent (C# AOT compilation)..."
dotnet publish /Users/satya/Git/ti-agents/ti-agent/src/ti.agent/ti-agent.csproj \
  -c Release \
  -r osx-arm64 \
  /p:NativeLib=Shared \
  /p:SelfContained=true

echo "✓ Native agent built: /Users/satya/Git/ti-agents/ti-agent/src/ti.agent/bin/Release/net8.0/osx-arm64/native/ti-agent.dylib"
