# Integration Tests - Multi-Service Sample (Maven)

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

### Build All Services
```bash
mvn clean package -DskipTests
```

### Start Services (3 terminals)
```bash
# Terminal 1 - Shipping (port 8083)
java -jar shipping-service/target/shipping-service-1.0-SNAPSHOT.jar

# Terminal 2 - Inventory (port 8082)
java -jar inventory-service/target/inventory-service-1.0-SNAPSHOT.jar

# Terminal 3 - Order (port 8081)
java -jar order-service/target/order-service-1.0-SNAPSHOT.jar
```

### Run Tests (services must be running)
```bash
cd integration-tests
mvn test
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

BUILD SUCCESS
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
integration-tests-maven/
├── order-service/          Spring Boot 3 (A)
├── inventory-service/      Spring Boot 2 (B)
├── shipping-service/       Javalin (C)
├── integration-tests/      Test suite
├── pom.xml                Parent POM
├── run-it.sh              Automated runner
├── docker-compose.yml     Docker orchestration
└── README.md              This file
```

---

## 🎯 Run Specific Tests

```bash
cd integration-tests

# All matrix tests
mvn test -Dtest=ComprehensiveMatrixIT

# Happy path only
mvn test -Dtest=HappyPathIT

# Concurrent tests
mvn test -Dtest=ConcurrentTestsIT

# Multiple test classes
mvn test -Dtest=HappyPathIT,ConcurrentTestsIT
```

---

## 📖 View Test Reports

```bash
# Maven surefire reports
open integration-tests/target/surefire-reports/index.html
```

---

## 🛠️ Requirements

- **Java 17+**
- **Maven 3.6+** (tested with 3.9.12)

### Installation

```bash
# macOS
brew install maven

# Or use sdkman
sdk install maven
sdk install java 17.0.7-tem
```

---

## 🐳 Docker Support

```bash
# Build images
docker-compose build

# Start all services
docker-compose up -d

# Run tests against Docker services
cd integration-tests
mvn test

# Stop services
docker-compose down
```

---

## 💡 Design Decisions

✅ **In-memory data** - No external databases, hermetic tests  
✅ **Process-based tests** - Tests run as separate JVMs via HTTP  
✅ **Heterogeneous stack** - Multiple frameworks & HTTP clients  
✅ **Maven multi-module** - Standard Maven parent/child structure  
✅ **Fat JARs** - Spring Boot executable JARs + maven-shade for Javalin  

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

**JAR files not building?**
```bash
# Clean build everything
mvn clean package -DskipTests
```

**Shipping service ClassNotFoundException?**
```bash
# Verify maven-shade-plugin created fat JAR
ls -lh shipping-service/target/shipping-service-1.0-SNAPSHOT.jar
# Should be ~5MB, not ~2KB
```

---

## 📝 Service Logging

All services include logging to show the HTTP call chain:

```
>>> [ORDER-SERVICE] Received POST /orders
    [ORDER->INVENTORY] Calling GET http://localhost:8082/stock/TEST-SKU
    >>> [INVENTORY-SERVICE] Received GET /stock/TEST-SKU
        [INVENTORY->SHIPPING] Calling GET http://localhost:8083/eta/TEST-SKU
            >>> [SHIPPING-SERVICE] Received GET /eta/TEST-SKU
            <<< [SHIPPING-SERVICE] Returning ETA: 1 days
        [INVENTORY<-SHIPPING] Received ETA: 1 days
    <<< [INVENTORY-SERVICE] Returning stock - quantity=20, etaDays=1
    [ORDER<-INVENTORY] Received stock info - quantity=20, etaDays=1
<<< [ORDER-SERVICE] Created order - id=..., status=CONFIRMED
```

---

## 🔗 Related Repositories

- [integration-tests](https://github.com/satyakota04/integration-tests) - Gradle version
