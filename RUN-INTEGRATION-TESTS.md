# Running Integration Tests with Classification

## Quick Start - All Services Automated

```bash
cd /Users/satya/Git/integration-tests-maven

# Build agents first (one time)
./build-native-agent.sh
./build-ti-agent.sh

# Run everything (builds services, starts them, runs tests, checks classification)
./run-all-services.sh
```

This script will:
1. Build all services (if needed)
2. Start shipping, inventory, and order services with TI agent
3. Wait for them to be ready
4. Run integration tests
5. Show classification report
6. Stop all services and show summary

## Manual Testing - Individual Services

If you want to run services manually in separate terminals:

### Terminal 1 - Shipping Service
```bash
./run-shipping.sh
```

### Terminal 2 - Inventory Service
```bash
./run-inventory.sh
```

### Terminal 3 - Order Service
```bash
./run-order.sh
```

### Terminal 4 - Run Tests
```bash
# Wait for all services to start, then:
mvn -f integration-tests/pom.xml test
```

### Terminal 5 - Check Classification
```bash
./check-all-classification.sh
```

## What the Scripts Do

### Service Scripts
- **`run-order.sh`** - Starts order-service on port 8081 with TI agent
- **`run-inventory.sh`** - Starts inventory-service on port 8082 with TI agent
- **`run-shipping.sh`** - Starts shipping-service on port 8083 with TI agent

All services:
- Log classification to `/tmp/ti-it/<service>/native-agent.log`
- Write call graphs to `/tmp/ti-it/<service>/cg_*.json`
- Use `instrPackages: com.harness.sample.` to identify user code

### Check Scripts
- **`check-classification.sh [service]`** - Check single service (default: order)
- **`check-all-classification.sh`** - Check all three services

### Build Scripts
- **`build-ti-agent.sh`** - Build Java agent (ByteBuddy + trampoline)
- **`build-native-agent.sh`** - Build C# native agent (AOT compiled)
- **`build-services.sh`** - Build order/inventory/shipping Spring Boot JARs

## Expected Classification Results

### User Classes (isUserClass=True)
Should see classes from `com.harness.sample.*`:
- `com.harness.sample.order.OrderController`
- `com.harness.sample.inventory.InventoryService`
- `com.harness.sample.shipping.ShippingCalculator`

### Dependency Classes (isUserClass=False)
Should see:
- **JDK**: `java.util.*`, `java.lang.*`, `java.io.*`
- **Spring Boot**: `org.springframework.boot.*`
- **Spring Framework**: `org.springframework.web.*`, `org.springframework.context.*`
- **Jackson**: `com.fasterxml.jackson.*`
- **Hibernate**: `org.hibernate.*`
- **Tomcat**: `org.apache.catalina.*`, `org.apache.tomcat.*`

## Ports

- **8081** - order-service
- **8082** - inventory-service
- **8083** - shipping-service

## Log Files

- `/tmp/ti-it/order/native-agent.log` - Order service classification log
- `/tmp/ti-it/inventory/native-agent.log` - Inventory service classification log
- `/tmp/ti-it/shipping/native-agent.log` - Shipping service classification log
- `/tmp/ti-it/*/console.log` - Service console output

## Call Graph Output

After running tests, call graphs are written to:
- `/tmp/ti-it/order/cg_*.json` - Order service call graph
- `/tmp/ti-it/inventory/cg_*.json` - Inventory service call graph
- `/tmp/ti-it/shipping/cg_*.json` - Shipping service call graph

These should ONLY contain user classes (`com.harness.sample.*`), not dependency classes.

## Troubleshooting

### Services won't start
```bash
# Check if ports are already in use
lsof -ti:8081,8082,8083

# Kill any existing services
pkill -f "order-service-1.0-SNAPSHOT.jar"
pkill -f "inventory-service-1.0-SNAPSHOT.jar"
pkill -f "shipping-service-1.0-SNAPSHOT.jar"
```

### No classification logs
```bash
# Verify agents are built
ls -la /Users/satya/Git/ti-agents/ti-agent/src/java/java-agent-trampoline/build/libs/java-agent-trampoline.jar
ls -la /Users/satya/Git/ti-agents/ti-agent/src/ti.agent/bin/Release/net8.0/osx-arm64/native/ti-agent.dylib

# Check native agent is loading
grep "Attaching Harness TI Agent" /tmp/ti-it/*/console.log
```

### All classes classified as user
This was the bug - fixed now. The native agent now correctly identifies:
- JDK classes (`jrt:` protocol) as dependencies
- Temp JARs (`/tmp/`, `/var/folders/`) as dependencies
- Empty source URLs as dependencies

### Want verbose console output
Edit the service scripts and change:
- `logConsole: false` → `logConsole: true` (in config.ini)
- `"console": "false"` → `"console": "true"` (in native-config.json)

## CI via Tunnel (services on PC, hcli in Harness CI)

Instead of running the services in the CI runner, keep the services (with the TI
agent) running on your PC and run **only `hcli`** in a Harness CI pipeline, reaching
the services over public tunnels.

> Not reproducible per-push: the pipeline fails whenever your PC or the tunnels are
> offline. Use this for on-demand/manual runs. For real per-push CI, run the services
> in the pipeline instead (see `test-on-gke.sh` / `.harness/integration-tests-gke*.yaml`).

### 1. Start services on the PC (agent attached)

```bash
./run-all-services.sh
# or run ./run-shipping.sh, ./run-inventory.sh, ./run-order.sh in separate terminals
```

### 2. Expose the 3 entry ports via tunnels

```bash
./tunnel-services.sh
```

This uses **reserved ngrok domains** from `~/Library/Application Support/ngrok/ngrok.yml`
(named tunnels `order`/`inventory`/`shipping`), so the URLs are stable and known in
advance — no need to copy them each run:

| service   | port | URL                                  |
|-----------|------|--------------------------------------|
| order     | 8081 | https://order-kota.ngrok-free.dev    |
| inventory | 8082 | https://inventory-kota.ngrok-free.dev |
| shipping  | 8083 | https://shipping-kota.ngrok-free.dev |

Inter-service calls (order→inventory→shipping) stay on localhost on your PC; only the
entry ports are tunneled. Keep this terminal open for the whole pipeline run.

> Prerequisite: the 3 domains must be reserved on your ngrok dashboard and the named
> tunnels present in `ngrok.yml`. Override domains via `ORDER_DOMAIN` / `INVENTORY_DOMAIN`
> / `SHIPPING_DOMAIN` env vars if you rename them. Alternative provider:
> `TUNNEL_PROVIDER=cloudflared ./tunnel-services.sh`.

### 3. Publish linux-x64 artifacts once

The CI runner is Linux, so it needs linux-x64 builds (NOT the osx-arm64 ones on your
Mac). Publish these somewhere HTTP-accessible (GitHub Release / GCS / etc.):
- `hcli` (linux-x64 Go binary)
- `java-agent-trampoline.jar` (platform-independent)
- `ti-agent.so` (linux-x64 native agent; build with `dotnet publish ... -r linux-x64`)

### 4. Trigger the Harness CI pipeline

Pipeline: `.harness/integration-tests-hcli.yaml` (identifier `integration_tests_hcli`).

Trigger it manually and provide these pipeline variables:
- `ORDER_SERVICE_URL`, `INVENTORY_SERVICE_URL`, `SHIPPING_SERVICE_URL` — the tunnel URLs
- `HCLI_BINARY_URL`, `TI_AGENT_JAR_URL`, `TI_NATIVE_AGENT_URL` — the artifact URLs from step 3
- `TI_SERVICE_ENDPOINT` (optional, defaults to a dummy endpoint)

The pipeline runs `ci-hcli-tests.sh`, which downloads the artifacts, attaches the TI
agent to the test runner (`mvn test` via `hcli`), points the tests at the tunnel URLs,
and prints the call-graph output.
