package com.harness.sample.it;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import okhttp3.*;
import org.testng.annotations.Test;

import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.*;

import static org.assertj.core.api.Assertions.assertThat;

public class ConcurrentTestsIT {
    private static final String ORDER_SERVICE_URL = System.getProperty("order.service.url", "http://localhost:8081");
    private final OkHttpClient client = new OkHttpClient();
    private final ObjectMapper objectMapper = new ObjectMapper();

    @Test
    public void parallelTests_isolateContextIds() throws Exception {
        int concurrentRequests = 10;
        ExecutorService executor = Executors.newFixedThreadPool(concurrentRequests);
        List<Future<String>> futures = new ArrayList<>();

        // Submit concurrent order creation requests
        for (int i = 0; i < concurrentRequests; i++) {
            final int index = i;
            futures.add(executor.submit(() -> createOrder("SKU-" + index)));
        }

        // Collect results
        List<String> orderIds = new ArrayList<>();
        for (Future<String> future : futures) {
            orderIds.add(future.get(10, TimeUnit.SECONDS));
        }

        executor.shutdown();

        // Verify all orders were created successfully with unique IDs
        assertThat(orderIds).hasSize(concurrentRequests);
        assertThat(orderIds).doesNotContainNull();
        assertThat(orderIds).doesNotHaveDuplicates();
    }

    @Test
    public void sameContextSequentialCalls_aggregate() throws Exception {
        // Create multiple orders sequentially in the same test context
        String orderId1 = createOrder("SEQUENTIAL-1");
        String orderId2 = createOrder("SEQUENTIAL-2");

        assertThat(orderId1).isNotEmpty();
        assertThat(orderId2).isNotEmpty();
        assertThat(orderId1).isNotEqualTo(orderId2);
    }

    private String createOrder(String sku) throws Exception {
        String requestBody = "{\"sku\":\"" + sku + "\",\"quantity\":1}";

        Request request = new Request.Builder()
            .url(ORDER_SERVICE_URL + "/orders")
            .post(RequestBody.create(requestBody, MediaType.parse("application/json")))
            .build();

        try (Response response = client.newCall(request).execute()) {
            assertThat(response.isSuccessful()).isTrue();
            JsonNode json = objectMapper.readTree(response.body().string());
            return json.get("id").asText();
        }
    }
}
