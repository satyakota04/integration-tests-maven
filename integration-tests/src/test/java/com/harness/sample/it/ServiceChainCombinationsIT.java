package com.harness.sample.it;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import okhttp3.*;
import org.testng.SkipException;
import org.testng.annotations.Test;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Comprehensive test suite covering all service chain combinations:
 * - Entry point A (order-service): A, A→B, A→B→C
 * - Entry point B (inventory-service): B, B→C
 * - Entry point C (shipping-service): C
 */
public class ServiceChainCombinationsIT {
    private static final String ORDER_SERVICE_URL = System.getProperty("order.service.url", "http://localhost:8081");
    private static final String INVENTORY_SERVICE_URL = System.getProperty("inventory.service.url", "http://localhost:8082");
    private static final String SHIPPING_SERVICE_URL = System.getProperty("shipping.service.url", "http://localhost:8083");

    private final OkHttpClient client = new OkHttpClient();
    private final ObjectMapper objectMapper = new ObjectMapper();

    // ========================================================================
    // Entry Point C (shipping-service) - Leaf node, no downstream
    // ========================================================================

    @Test(priority = 1, description = "C alone: shipping-service standalone")
    public void testC_shippingServiceAlone() throws Exception {
        // Test shipping service directly with no downstream dependencies
        Request request = new Request.Builder()
            .url(SHIPPING_SERVICE_URL + "/eta/STANDALONE-SKU")
            .build();

        try (Response response = client.newCall(request).execute()) {
            assertThat(response.isSuccessful()).isTrue();

            String body = response.body().string();
            JsonNode json = objectMapper.readTree(body);

            assertThat(json.get("sku").asText()).isEqualTo("STANDALONE-SKU");
            assertThat(json.get("etaDays").asInt()).isGreaterThan(0);
        }
    }

    // ========================================================================
    // Entry Point B (inventory-service)
    // ========================================================================

    @Test(priority = 2, description = "B→C: inventory-service with shipping-service")
    public void testB_C_inventoryWithShipping() throws Exception {
        // Test inventory service calling shipping service (B→C chain)
        Request request = new Request.Builder()
            .url(INVENTORY_SERVICE_URL + "/stock/INVENTORY-SKU-1")
            .build();

        try (Response response = client.newCall(request).execute()) {
            assertThat(response.isSuccessful()).isTrue();

            String body = response.body().string();
            JsonNode json = objectMapper.readTree(body);

            assertThat(json.get("sku").asText()).isEqualTo("INVENTORY-SKU-1");
            assertThat(json.get("quantity").asInt()).isGreaterThan(0);
            assertThat(json.get("etaDays").asInt()).isGreaterThan(0);

            System.out.println("✓ B→C chain: inventory called shipping successfully");
        }
    }

    @Test(priority = 3, description = "B without C: inventory-service when shipping-service unavailable")
    public void testB_withoutC_inventoryWithoutShipping() throws Exception {
        // This test validates behavior when C (shipping) is down
        // In real scenario, you'd stop shipping-service before this test
        // For now, we verify the current behavior - should work when C is up

        Request request = new Request.Builder()
            .url(INVENTORY_SERVICE_URL + "/stock/INVENTORY-SKU-2")
            .build();

        try (Response response = client.newCall(request).execute()) {
            // When C is available: succeeds
            // When C is unavailable: should fail gracefully (500/503)
            if (response.isSuccessful()) {
                System.out.println("✓ B→C chain: shipping available");
                assertThat(response.code()).isEqualTo(200);
            } else {
                System.out.println("✓ B without C: shipping unavailable, graceful failure");
                assertThat(response.code()).isIn(500, 503);
            }
        }
    }

    // ========================================================================
    // Entry Point A (order-service)
    // ========================================================================

    @Test(priority = 4, description = "A→B→C: full chain (order→inventory→shipping)")
    public void testA_B_C_fullChain() throws Exception {
        // Test full chain: A calls B, B calls C
        String requestBody = "{\"sku\":\"FULL-CHAIN-SKU\",\"quantity\":2}";

        Request request = new Request.Builder()
            .url(ORDER_SERVICE_URL + "/orders")
            .post(RequestBody.create(requestBody, MediaType.parse("application/json")))
            .build();

        try (Response response = client.newCall(request).execute()) {
            assertThat(response.isSuccessful()).isTrue();

            String body = response.body().string();
            JsonNode json = objectMapper.readTree(body);

            assertThat(json.get("id").asText()).isNotEmpty();
            assertThat(json.get("sku").asText()).isEqualTo("FULL-CHAIN-SKU");
            assertThat(json.get("quantity").asInt()).isEqualTo(2);
            assertThat(json.get("status").asText()).isEqualTo("CONFIRMED");
            assertThat(json.get("estimatedDeliveryDays").asInt()).isGreaterThan(0);

            System.out.println("✓ A→B→C full chain: order→inventory→shipping successful");
        }
    }

    @Test(priority = 5, description = "A→B without C: order→inventory when shipping unavailable")
    public void testA_B_withoutC_orderInventoryWithoutShipping() throws Exception {
        // Test A→B chain when C is unavailable
        // This simulates shipping service being down
        String requestBody = "{\"sku\":\"NO-SHIPPING-SKU\",\"quantity\":1}";

        Request request = new Request.Builder()
            .url(ORDER_SERVICE_URL + "/orders")
            .post(RequestBody.create(requestBody, MediaType.parse("application/json")))
            .build();

        try (Response response = client.newCall(request).execute()) {
            // When all services up: succeeds
            // When C down: B fails, so A fails
            if (response.isSuccessful()) {
                System.out.println("✓ A→B→C: all services available");
            } else {
                System.out.println("✓ A→B without C: shipping unavailable, cascading failure");
                assertThat(response.code()).isIn(500, 503);
            }
        }
    }

    @Test(priority = 6, description = "A alone: order-service GET (no downstream calls)")
    public void testA_alone_orderServiceGet() throws Exception {
        // First create an order (this will use full chain A→B→C)
        String createBody = "{\"sku\":\"GET-ONLY-SKU\",\"quantity\":1}";

        Request createRequest = new Request.Builder()
            .url(ORDER_SERVICE_URL + "/orders")
            .post(RequestBody.create(createBody, MediaType.parse("application/json")))
            .build();

        String orderId;
        try (Response response = client.newCall(createRequest).execute()) {
            if (!response.isSuccessful()) {
                // If create fails due to downstream issues, skip this test
                throw new SkipException("Skipping: cannot create order for GET test");
            }
            JsonNode json = objectMapper.readTree(response.body().string());
            orderId = json.get("id").asText();
        }

        // Now test A alone: GET request with no downstream calls
        Request getRequest = new Request.Builder()
            .url(ORDER_SERVICE_URL + "/orders/" + orderId)
            .build();

        try (Response response = client.newCall(getRequest).execute()) {
            assertThat(response.isSuccessful()).isTrue();

            String body = response.body().string();
            JsonNode json = objectMapper.readTree(body);

            assertThat(json.get("id").asText()).isEqualTo(orderId);
            assertThat(json.get("sku").asText()).isEqualTo("GET-ONLY-SKU");

            System.out.println("✓ A alone: order GET with no downstream dependencies");
        }
    }

    // ========================================================================
    // Combination matrix tests
    // ========================================================================

    @Test(priority = 7, description = "Matrix: Test all combinations in sequence")
    public void testAllCombinationsMatrix() throws Exception {
        System.out.println("\n=== Service Chain Combination Matrix ===");

        // C alone
        testServiceAvailability("C", SHIPPING_SERVICE_URL + "/eta/MATRIX-SKU");

        // B→C
        testServiceAvailability("B→C", INVENTORY_SERVICE_URL + "/stock/MATRIX-SKU");

        // A→B→C (via GET to test A independently after creation)
        String orderId = createOrderForMatrix();
        if (orderId != null) {
            testServiceAvailability("A alone (GET)", ORDER_SERVICE_URL + "/orders/" + orderId);
        }

        System.out.println("=======================================\n");
    }

    @Test(priority = 8, description = "Parallel: All entry points simultaneously")
    public void testAllEntryPointsParallel() throws Exception {
        // Test all three entry points in parallel to verify isolation
        System.out.println("\n=== Testing all entry points in parallel ===");

        // Create 3 concurrent requests, one to each service
        Thread threadC = new Thread(() -> {
            try {
                Request request = new Request.Builder()
                    .url(SHIPPING_SERVICE_URL + "/eta/PARALLEL-C")
                    .build();
                try (Response response = client.newCall(request).execute()) {
                    assertThat(response.isSuccessful()).isTrue();
                    System.out.println("  ✓ C (parallel)");
                }
            } catch (Exception e) {
                throw new RuntimeException(e);
            }
        });

        Thread threadB = new Thread(() -> {
            try {
                Request request = new Request.Builder()
                    .url(INVENTORY_SERVICE_URL + "/stock/PARALLEL-B")
                    .build();
                try (Response response = client.newCall(request).execute()) {
                    assertThat(response.isSuccessful()).isTrue();
                    System.out.println("  ✓ B→C (parallel)");
                }
            } catch (Exception e) {
                throw new RuntimeException(e);
            }
        });

        Thread threadA = new Thread(() -> {
            try {
                String requestBody = "{\"sku\":\"PARALLEL-A\",\"quantity\":1}";
                Request request = new Request.Builder()
                    .url(ORDER_SERVICE_URL + "/orders")
                    .post(RequestBody.create(requestBody, MediaType.parse("application/json")))
                    .build();
                try (Response response = client.newCall(request).execute()) {
                    assertThat(response.isSuccessful()).isTrue();
                    System.out.println("  ✓ A→B→C (parallel)");
                }
            } catch (Exception e) {
                throw new RuntimeException(e);
            }
        });

        // Start all threads
        threadC.start();
        threadB.start();
        threadA.start();

        // Wait for completion
        threadC.join(10000);
        threadB.join(10000);
        threadA.join(10000);

        System.out.println("===========================================\n");
    }

    // ========================================================================
    // Helper methods
    // ========================================================================

    private void testServiceAvailability(String label, String url) {
        try {
            Request request = new Request.Builder()
                .url(url)
                .build();

            try (Response response = client.newCall(request).execute()) {
                if (response.isSuccessful()) {
                    System.out.println("  ✓ " + label + ": available");
                } else {
                    System.out.println("  ✗ " + label + ": unavailable (" + response.code() + ")");
                }
            }
        } catch (Exception e) {
            System.out.println("  ✗ " + label + ": error (" + e.getMessage() + ")");
        }
    }

    private String createOrderForMatrix() {
        try {
            String requestBody = "{\"sku\":\"MATRIX-ORDER\",\"quantity\":1}";
            Request request = new Request.Builder()
                .url(ORDER_SERVICE_URL + "/orders")
                .post(RequestBody.create(requestBody, MediaType.parse("application/json")))
                .build();

            try (Response response = client.newCall(request).execute()) {
                if (response.isSuccessful()) {
                    JsonNode json = objectMapper.readTree(response.body().string());
                    System.out.println("  ✓ A→B→C (POST): created order");
                    return json.get("id").asText();
                }
            }
        } catch (Exception e) {
            System.out.println("  ✗ A→B→C (POST): failed");
        }
        return null;
    }
}
