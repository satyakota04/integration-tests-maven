#!/usr/bin/env bash
set -euo pipefail
mvn -f /Users/satya/Git/integration-tests-maven/pom.xml clean install -DskipTests
