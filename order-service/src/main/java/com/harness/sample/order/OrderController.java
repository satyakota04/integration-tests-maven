package com.harness.sample.order;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/orders")
public class OrderController {
    private static final Logger log = LoggerFactory.getLogger(OrderController.class);
    private final OrderService orderService;

    public OrderController(OrderService orderService) {
        this.orderService = orderService;
    }

    @PostMapping
    public Order createOrder(@RequestBody CreateOrderRequest request) {
        log.info(">>> [ORDER-SERVICE] Received POST /orders - sku={}, quantity={}",
                 request.getSku(), request.getQuantity());
        Order order = orderService.createOrder(request.getSku(), request.getQuantity());
        log.info("<<< [ORDER-SERVICE] Created order - id={}, status={}",
                 order.getId(), order.getStatus());
        return order;
    }

    @GetMapping("/{id}")
    public Order getOrder(@PathVariable String id) {
        log.info(">>> [ORDER-SERVICE] Received GET /orders/{}", id);
        Order order = orderService.getOrder(id);
        log.info("<<< [ORDER-SERVICE] Returning order - id={}, sku={}",
                 order.getId(), order.getSku());
        return order;
    }

    public static class CreateOrderRequest {
        private String sku;
        private int quantity;

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
    }
}
