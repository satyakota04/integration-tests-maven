package com.harness.sample.it.ca;

import okhttp3.*;
import org.testng.annotations.Test;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Chain C→A: shipping-service → order-service.
 * Entry point: GET /ship-order/{sku} on shipping-service (port 8083).
 * Shipping calls order (/orders/lookup/{sku}), order calls inventory (/stock/{sku}).
 */
public class ChainCAIT {
    private static final String SHIPPING_SERVICE_URL = System.getProperty("shipping.service.url", "https://shipping-kota.ngrok-free.dev");
    private final OkHttpClient client = new OkHttpClient();

    @Test
    public void shippingChain_order() throws Exception {
        Request request = new Request.Builder()
            .url(SHIPPING_SERVICE_URL + "/ship-order/CA-CHAIN-SKU")
            .build();

        try (Response response = client.newCall(request).execute()) {
            assertThat(response.isSuccessful()).isTrue();
            assertThat(response.code()).isEqualTo(200);
        }
    }
}
