# Integration Tests - Multi-Service Sample

Three microservices with comprehensive integration tests covering all service chain combinations.

---

## 🚀 Quick Start

```bash
# Run everything (start services, run tests, cleanup)
./run-it.sh
```

**That's it!** Services start automatically, tests run, results display, then cleanup.

---

## 📋 Manual Commands

### Run Tests (services must be running)
```bash
# Clean build with fresh test execution
./gradlew clean test --rerun-tasks

# Or shorter (uses cache if available)
./gradlew clean test
```

### Start Services (3 terminals)
```bash
# Terminal 1 - Shipping (port 8083)
./gradlew :shipping-service:run

# Terminal 2 - Inventory (port 8082)
./gradlew :inventory-service:bootRun

# Terminal 3 - Order (port 8081)
./gradlew :order-service:bootRun
```

### Stop Services
```bash
pkill -f "shipping-service"
pkill -f "inventory-service"
pkill -f "order-service"
```

---

## 📊 Test Output

You'll see **real-time test execution**:

```
ComprehensiveMatrixIT > Test 1: C alone - shipping-service standalone PASSED
ComprehensiveMatrixIT > Test 2: B alone - inventory without shipping PASSED
ComprehensiveMatrixIT > Test 3: B→C - inventory calls shipping PASSED
ComprehensiveMatrixIT > Test 4: A alone - order GET without downstream PASSED
ComprehensiveMatrixIT > Test 5: A→B - order calls inventory PASSED
ComprehensiveMatrixIT > Test 6: A→B→C - full service chain PASSED
ComprehensiveMatrixIT > Bonus: All combinations in parallel PASSED

HappyPathIT > placeOrder_completesAcrossThreeServices() PASSED
HappyPathIT > getOrder_singleService() PASSED

ConcurrentTestsIT > parallelTests_isolateContextIds() PASSED
...

============================================================
Test Results: SUCCESS
============================================================
Total: 24 tests
Passed: 24
Failed: 0
Skipped: 0
============================================================

BUILD SUCCESSFUL in 2s
```

---

## 🏗️ Architecture

**Service Chain:** order-service → inventory-service → shipping-service

| Service | Framework | HTTP Client | Port |
|---------|-----------|-------------|------|
| order-service | Spring Boot 3 | RestTemplate | 8081 |
| inventory-service | Spring Boot 2.7 | OkHttp | 8082 |
| shipping-service | Javalin | None (leaf) | 8083 |

**Why Different Technologies?**
- Tests both `jakarta.servlet` (Spring Boot 3) and `javax.servlet` (Spring Boot 2, Javalin)
- Validates multiple HTTP clients (RestTemplate, OkHttp, raw servlet)
- Ensures framework-agnostic integration

---

## ✅ Test Coverage

### Service Combinations Tested

| Test | Entry | Chain | What It Tests |
|------|-------|-------|---------------|
| 1 | C | **C** | Shipping standalone (leaf node) |
| 2 | B | **B** | Inventory without shipping (edge case) |
| 3 | B | **B→C** | Inventory calls shipping |
| 4 | A | **A** | Order GET (no downstream calls) |
| 5 | A | **A→B** | Order + inventory (no shipping) |
| 6 | A | **A→B→C** | Full chain (all 3 services) |
| 7 | All | **Parallel** | All combinations simultaneously |

**Naming:** A=order-service, B=inventory-service, C=shipping-service

### Test Suites (24 total tests)

1. **ComprehensiveMatrixIT** (7 tests) - All combinations with visual output
2. **ServiceChainCombinationsIT** (8 tests) - Extended scenarios
3. **HappyPathIT** (2 tests) - Basic happy paths
4. **ConcurrentTestsIT** (2 tests) - Parallel execution
5. **PartialFailureIT** (1 test) - Graceful failure handling
6. **ManualHeaderIT** (4 tests) - Edge cases

---

## 🔍 API Endpoints

### Order Service (8081)
```bash
# Create order
POST /orders
{"sku": "LAPTOP-123", "quantity": 2}

# Get order
GET /orders/{id}
```

### Inventory Service (8082)
```bash
GET /stock/{sku}
```

### Shipping Service (8083)
```bash
GET /eta/{sku}
```

---

## 📂 Project Structure

```
integration-tests/
├── order-service/          Spring Boot 3 (A)
├── inventory-service/      Spring Boot 2 (B)
├── shipping-service/       Javalin (C)
├── integration-tests/      Test suite
├── run-it.sh              Automated runner
├── README.md              This file
└── QUICKSTART.md          Quick reference
```

---

## 🎯 Run Specific Tests

```bash
# All matrix tests
./gradlew test --tests ComprehensiveMatrixIT

# Specific test
./gradlew test --tests "ComprehensiveMatrixIT.test6*"

# Happy path only
./gradlew test --tests HappyPathIT

# Concurrent tests
./gradlew test --tests ConcurrentTestsIT
```

---

## 📖 View HTML Report

```bash
open integration-tests/build/reports/tests/test/index.html
```

---

## 🛠️ Requirements

- Java 17+
- Gradle 8.5+ (wrapper included - use `./gradlew`)

---

## 💡 Design Decisions

✅ **In-memory data** - No external databases, hermetic tests  
✅ **Process-based tests** - Tests run as separate JVM via HTTP  
✅ **Heterogeneous stack** - Multiple frameworks & HTTP clients  
✅ **Real-time output** - See each test as it executes  
✅ **Clean Gradle** - Standard setup, no cache warnings  

---

## 🐛 Troubleshooting

**Tests fail with connection errors?**
```bash
# Services aren't running. Start them:
./run-it.sh

# Or manually in 3 terminals (see "Start Services" above)
```

**Port already in use?**
```bash
# Kill existing services:
pkill -f "shipping-service"
pkill -f "inventory-service"  
pkill -f "order-service"
```

**Using wrong Gradle?**
```bash
# Use ./gradlew (with dot-slash), NOT gradle
./gradlew clean test  ✅
gradle clean test     ❌
```

---

## 📚 Additional Documentation

See **[QUICKSTART.md](QUICKSTART.md)** for condensed reference.
