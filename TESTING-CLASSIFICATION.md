# Testing Class Origin Classification

This guide helps you test the new native-driven class origin classification feature (CI-22474).

## What Changed

- **Before**: Java agent logged class origins but didn't act on them
- **After**: Native agent classifies classes as user/dependency and Java agent skips instrumenting dependencies

## Quick Test

### 1. Build the agents with new changes

```bash
cd /Users/satya/Git/integration-tests-maven

# Build native agent (C# with new classification logic)
./build-native-agent.sh

# Build Java agent (updated to call native)
./build-ti-agent.sh
```

### 2. Run order-service with the agent

```bash
# In one terminal:
./run-order.sh
```

Watch the console output for classification messages like:
```
Class classification: class=com.harness.sample.order.OrderController, source=jar:file:/.../BOOT-INF/classes/!, isUserClass=True
Class classification: class=com.fasterxml.jackson.databind.ObjectMapper, source=jar:nested:/.../jackson-databind-2.15.3.jar!/, isUserClass=False
```

### 3. Check classification results

```bash
# In another terminal:
./check-classification.sh
```

This shows:
- Which classes were classified as **user** (instrumented)
- Which classes were classified as **dependency** (skipped)
- Counts of each category

## What to Look For

### ✅ Expected Behavior

1. **User classes** (from `com.harness.sample.*`) should have `isUserClass=True`:
   - `com.harness.sample.order.OrderController`
   - `com.harness.sample.order.OrderService`
   - `com.harness.sample.order.OrderRepository`

2. **Dependency classes** should have `isUserClass=False`:
   - Spring classes: `org.springframework.*`
   - Jackson: `com.fasterxml.jackson.*`
   - Hibernate: `org.hibernate.*`
   - Tomcat: `org.apache.catalina.*`

3. **Spring Boot structure** should be correctly handled:
   - User classes from `BOOT-INF/classes/` → user class
   - Dependencies from `BOOT-INF/lib/*.jar` → dependency class

### ❌ Signs of Issues

- All classes classified as user (no dependencies filtered)
- All classes classified as dependencies (user code not recognized)
- Native agent crashes or fails to load
- No classification messages in logs

## Classification Logic

The native agent uses this algorithm:

1. **Package prefix match** (`instrPackages: com.harness.sample.`)
   - If class name starts with configured package → **USER**

2. **Spring Boot detection** (in source URL)
   - If URL contains `BOOT-INF/classes/` → **USER**
   - If URL contains `BOOT-INF/lib/` → **DEPENDENCY**

3. **JAR vs directory**
   - If source URL is a JAR → **DEPENDENCY**
   - If source URL is a directory → **USER**

## Troubleshooting

### Agent doesn't load
```bash
# Check native agent exists
ls -la /Users/satya/Git/ti-agents/ti-agent/src/ti.agent/bin/Release/net8.0/osx-arm64/native/ti-agent.dylib
```

### No classification messages
- Check log level is set to `Information` in native config
- Check `logConsole: true` in Java agent config
- Verify `HARNESS_TI_AGENT_PATH` points to the dylib

### All classes classified as user
- Verify `instrPackages` is set correctly in config.ini
- Check that native agent is actually being called (look for JNI errors)

### Classification seems wrong
- Check the full classification log: `less /tmp/ti-it/order/native-agent.log`
- Look for the source URL pattern — does it match expectations?

## Advanced: Verify Instrumentation Impact

Check the generated call graph to confirm dependency classes aren't in the output:

```bash
# After running tests, check the call graph
ls -la /tmp/ti-it/order/cg_*.json

# Count methods from user vs dependency packages
grep -o '"class":"[^"]*"' /tmp/ti-it/order/cg_*.json | sort -u | grep com.harness | wc -l
grep -o '"class":"[^"]*"' /tmp/ti-it/order/cg_*.json | sort -u | grep -v com.harness | wc -l
```

User classes should appear in the call graph. Dependency classes should NOT (unless called from user code).

## Files to Check

- **Java agent logs**: Console output when running order-service
- **Native agent logs**: `/tmp/ti-it/order/native-agent.log`
- **Call graph output**: `/tmp/ti-it/order/cg_*.json`
- **Configs**:
  - Java: `/tmp/ti-it/order/config.ini`
  - Native: `/tmp/ti-it/order/native-config.json`
