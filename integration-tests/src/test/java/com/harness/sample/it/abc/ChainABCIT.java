package com.harness.sample.it.abc;

import okhttp3.*;
import org.testng.annotations.Test;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Chain A→B→C: order-service → inventory-service → shipping-service.
 * Entry point: POST /orders on order-service (port 8081).
 * Order calls inventory (/stock/{sku}), inventory calls shipping (/eta/{sku}).
 */
public class ChainABCIT {
    private static final String ORDER_SERVICE_URL = System.getProperty("order.service.url", "https://order-kota.ngrok-free.dev");
    private final OkHttpClient client = new OkHttpClient();

    @Test
    public void orderChain_inventory_shipping() throws Exception {
        String requestBody = "{\"sku\":\"ABC-CHAIN-SKU\",\"quantity\":2}";

        Request request = new Request.Builder()
            .url(ORDER_SERVICE_URL + "/orders")
            .post(RequestBody.create(requestBody, MediaType.parse("application/json")))
            .build();

        try (Response response = client.newCall(request).execute()) {
            assertThat(response.isSuccessful()).isTrue();
            assertThat(response.code()).isEqualTo(200);
        }
    }
}
