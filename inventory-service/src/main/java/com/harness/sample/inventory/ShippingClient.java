package com.harness.sample.inventory;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import okhttp3.OkHttpClient;
import okhttp3.Request;
import okhttp3.Response;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import java.io.IOException;

@Component
public class ShippingClient {
    private static final Logger log = LoggerFactory.getLogger(ShippingClient.class);
    private final OkHttpClient client;
    private final String shippingServiceUrl;
    private final ObjectMapper objectMapper;

    public ShippingClient(@Value("${shipping.service.url}") String shippingServiceUrl) {
        this.client = new OkHttpClient();
        this.shippingServiceUrl = shippingServiceUrl;
        this.objectMapper = new ObjectMapper();
    }

    public int getEta(String sku) {
        log.info("        [INVENTORY->SHIPPING] Calling GET {}/eta/{}", shippingServiceUrl, sku);
        Request request = new Request.Builder()
            .url(shippingServiceUrl + "/eta/" + sku)
            .build();

        try (Response response = client.newCall(request).execute()) {
            if (!response.isSuccessful()) {
                throw new RuntimeException("Failed to get ETA: " + response.code());
            }

            String body = response.body().string();
            JsonNode json = objectMapper.readTree(body);
            int etaDays = json.get("etaDays").asInt();
            log.info("        [INVENTORY<-SHIPPING] Received ETA: {} days", etaDays);
            return etaDays;
        } catch (IOException e) {
            throw new RuntimeException("Failed to call shipping service", e);
        }
    }
}
