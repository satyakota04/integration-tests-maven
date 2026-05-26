package com.harness.sample.inventory;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class StockController {
    private static final Logger log = LoggerFactory.getLogger(StockController.class);
    private final StockService stockService;

    public StockController(StockService stockService) {
        this.stockService = stockService;
    }

    @GetMapping("/health")
    public String health() {
        return "OK";
    }

    @GetMapping("/stock/{sku}")
    public StockItem getStock(@PathVariable String sku) {
        log.info(">>> [INVENTORY-SERVICE] Received GET /stock/{}", sku);
        StockItem item = stockService.getStock(sku);
        log.info("<<< [INVENTORY-SERVICE] Returning stock - quantity={}, etaDays={}",
                 item.getQuantity(), item.getEtaDays());
        return item;
    }
}
