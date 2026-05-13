package com.harness.sample.order;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestTemplate;

@Component
public class InventoryClient {
    private static final Logger log = LoggerFactory.getLogger(InventoryClient.class);
    private final RestTemplate restTemplate;
    private final String inventoryServiceUrl;

    public InventoryClient(RestTemplate restTemplate,
                           @Value("${inventory.service.url}") String inventoryServiceUrl) {
        this.restTemplate = restTemplate;
        this.inventoryServiceUrl = inventoryServiceUrl;
    }

    public StockInfo checkStock(String sku) {
        log.info("    [ORDER->INVENTORY] Calling GET {}/stock/{}", inventoryServiceUrl, sku);
        StockInfo stockInfo = restTemplate.getForObject(
            inventoryServiceUrl + "/stock/" + sku,
            StockInfo.class
        );
        log.info("    [ORDER<-INVENTORY] Received stock info - quantity={}, etaDays={}",
                 stockInfo.getQuantity(), stockInfo.getEtaDays());
        return stockInfo;
    }

    public static class StockInfo {
        private String sku;
        private int quantity;
        private int etaDays;

        public String getSku() {
            return sku;
        }

        public void setSku(String sku) {
            this.sku = sku;
        }

        public int getQuantity() {
            return quantity;
        }

        public void setQuantity(int quantity) {
            this.quantity = quantity;
        }

        public int getEtaDays() {
            return etaDays;
        }

        public void setEtaDays(int etaDays) {
            this.etaDays = etaDays;
        }
    }
}
