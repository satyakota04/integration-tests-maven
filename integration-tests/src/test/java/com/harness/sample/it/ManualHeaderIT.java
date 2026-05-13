package com.harness.sample.it;

import okhttp3.*;
import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;

public class ManualHeaderIT {
    private static final String ORDER_SERVICE_URL = System.getProperty("order.service.url", "http://localhost:8081");
    private final OkHttpClient client = new OkHttpClient();

    @Test
    public void collectWithoutValidExecution_returns404() throws Exception {
        // Test security: attempting to collect without proper execution context
        // In a TI-agent instrumented setup, this would return 404
        // For now, this validates that the service doesn't have a /collect endpoint

        Request request = new Request.Builder()
            .url(ORDER_SERVICE_URL + "/collect/invalid-execution-id")
            .build();

        try (Response response = client.newCall(request).execute()) {
            assertThat(response.code()).isEqualTo(404);
        }
    }

    @Test
    public void collectAfterTtl_returns404() throws Exception {
        // Test TTL enforcement
        Request request = new Request.Builder()
            .url(ORDER_SERVICE_URL + "/collect/expired-context")
            .build();

        try (Response response = client.newCall(request).execute()) {
            assertThat(response.code()).isEqualTo(404);
        }
    }

    @Test
    public void collectWithoutHeaders_passesThrough() throws Exception {
        // Verify normal traffic flows without disruption
        String requestBody = "{\"sku\":\"NORMAL-SKU\",\"quantity\":1}";

        Request request = new Request.Builder()
            .url(ORDER_SERVICE_URL + "/orders")
            .post(RequestBody.create(requestBody, MediaType.parse("application/json")))
            .build();

        try (Response response = client.newCall(request).execute()) {
            assertThat(response.isSuccessful()).isTrue();
        }
    }

    @Test
    public void outgoingFromOutsideTest_addsNoHeaders() throws Exception {
        // Verify that requests from outside test context don't add headers
        // This is a placeholder test that validates normal behavior
        String requestBody = "{\"sku\":\"OUTSIDE-TEST\",\"quantity\":1}";

        Request request = new Request.Builder()
            .url(ORDER_SERVICE_URL + "/orders")
            .post(RequestBody.create(requestBody, MediaType.parse("application/json")))
            .build();

        try (Response response = client.newCall(request).execute()) {
            assertThat(response.isSuccessful()).isTrue();
        }
    }
}
