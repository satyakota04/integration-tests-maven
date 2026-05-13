package com.harness.sample.inventory;

public class StockItem {
    private String sku;
    private int quantity;
    private int etaDays;

    public StockItem() {
    }

    public StockItem(String sku, int quantity, int etaDays) {
        this.sku = sku;
        this.quantity = quantity;
        this.etaDays = etaDays;
    }

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
