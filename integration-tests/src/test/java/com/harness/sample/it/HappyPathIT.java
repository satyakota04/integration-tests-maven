package com.harness.sample.it;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import okhttp3.*;
import org.testng.annotations.Test;

import static org.assertj.core.api.Assertions.assertThat;

public class HappyPathIT {
    private static final String ORDER_SERVICE_URL = System.getProperty("order.service.url", "http://localhost:8081");
    private final OkHttpClient client = new OkHttpClient();
    private final ObjectMapper objectMapper = new ObjectMapper();

    @Test
    public void placeOrder_completesAcrossThreeServices() throws Exception {
        // Create an order (order-service → inventory-service → shipping-service)
        String requestBody = "{\"sku\":\"LAPTOP-123\",\"quantity\":2}";

        Request request = new Request.Builder()
            .url(ORDER_SERVICE_URL + "/orders")
            .post(RequestBody.create(requestBody, MediaType.parse("application/json")))
            .build();

        try (Response response = client.newCall(request).execute()) {
            assertThat(response.isSuccessful()).isTrue();

            String body = response.body().string();
            JsonNode json = objectMapper.readTree(body);

            assertThat(json.get("id").asText()).isNotEmpty();
            assertThat(json.get("sku").asText()).isEqualTo("LAPTOP-123");
            assertThat(json.get("quantity").asInt()).isEqualTo(2);
            assertThat(json.get("status").asText()).isEqualTo("CONFIRMED");
            assertThat(json.get("estimatedDeliveryDays").asInt()).isGreaterThan(0);

            // Verify we can retrieve the order
            String orderId = json.get("id").asText();
            Request getRequest = new Request.Builder()
                .url(ORDER_SERVICE_URL + "/orders/" + orderId)
                .build();

            try (Response getResponse = client.newCall(getRequest).execute()) {
                assertThat(getResponse.isSuccessful()).isTrue();
                JsonNode getJson = objectMapper.readTree(getResponse.body().string());
                assertThat(getJson.get("id").asText()).isEqualTo(orderId);
            }
        }
    }

    @Test
    public void getOrder_singleService() throws Exception {
        // First create an order
        String requestBody = "{\"sku\":\"MOUSE-456\",\"quantity\":1}";

        Request createRequest = new Request.Builder()
            .url(ORDER_SERVICE_URL + "/orders")
            .post(RequestBody.create(requestBody, MediaType.parse("application/json")))
            .build();

        String orderId;
        try (Response response = client.newCall(createRequest).execute()) {
            assertThat(response.isSuccessful()).isTrue();
            JsonNode json = objectMapper.readTree(response.body().string());
            orderId = json.get("id").asText();
        }

        // Now retrieve it (single service call, no downstream)
        Request getRequest = new Request.Builder()
            .url(ORDER_SERVICE_URL + "/orders/" + orderId)
            .build();

        try (Response response = client.newCall(getRequest).execute()) {
            assertThat(response.isSuccessful()).isTrue();
            JsonNode json = objectMapper.readTree(response.body().string());
            assertThat(json.get("sku").asText()).isEqualTo("MOUSE-456");
        }
    }
}
