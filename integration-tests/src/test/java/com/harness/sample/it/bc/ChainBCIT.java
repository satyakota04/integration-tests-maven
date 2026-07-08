package com.harness.sample.it.bc;

import okhttp3.*;
import org.testng.annotations.Test;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Chain B→C: inventory-service → shipping-service.
 * Entry point: GET /stock/{sku} on inventory-service (port 8082).
 * Inventory calls shipping (/eta/{sku}).
 */
public class ChainBCIT {
    private static final String INVENTORY_SERVICE_URL = System.getProperty("inventory.service.url", "https://inventory-kota.ngrok-free.dev");
    private final OkHttpClient client = new OkHttpClient();

    @Test
    public void inventoryChain_shipping() throws Exception {
        Request request = new Request.Builder()
            .url(INVENTORY_SERVICE_URL + "/stock/BC-CHAIN-SKU")
            .build();

        try (Response response = client.newCall(request).execute()) {
            assertThat(response.isSuccessful()).isTrue();
            assertThat(response.code()).isEqualTo(200);
        }
    }
}
