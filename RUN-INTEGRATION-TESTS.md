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
