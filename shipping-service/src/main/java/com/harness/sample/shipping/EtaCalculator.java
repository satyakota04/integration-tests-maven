package com.harness.sample.shipping;

public class EtaCalculator {
    public static int calculate(String sku) {
        // Simple hash-based ETA calculation for deterministic results
        int hash = Math.abs(sku.hashCode());
        return 1 + (hash % 10); // 1-10 days
    }
}
