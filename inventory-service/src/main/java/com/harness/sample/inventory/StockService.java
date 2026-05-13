package com.harness.sample.inventory;

import org.springframework.stereotype.Service;

@Service
public class StockService {
    private final ShippingClient shippingClient;

    public StockService(ShippingClient shippingClient) {
        this.shippingClient = shippingClient;
    }

    public StockItem getStock(String sku) {
        int quantity = calculateQuantity(sku);
        int etaDays = shippingClient.getEta(sku);

        return new StockItem(sku, quantity, etaDays);
    }

    private int calculateQuantity(String sku) {
        // Hash-based calculation for deterministic results
        int hash = Math.abs(sku.hashCode());
        return 10 + (hash % 100); // 10-109 units
    }
}
