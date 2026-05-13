package com.harness.sample.order;

import org.springframework.stereotype.Service;

@Service
public class OrderService {
    private final OrderRepository orderRepository;
    private final InventoryClient inventoryClient;

    public OrderService(OrderRepository orderRepository, InventoryClient inventoryClient) {
        this.orderRepository = orderRepository;
        this.inventoryClient = inventoryClient;
    }

    public Order createOrder(String sku, int quantity) {
        // Check inventory availability
        InventoryClient.StockInfo stockInfo = inventoryClient.checkStock(sku);

        if (stockInfo.getQuantity() < quantity) {
            throw new IllegalArgumentException("Insufficient stock. Available: " + stockInfo.getQuantity());
        }

        Order order = new Order();
        order.setId(java.util.UUID.randomUUID().toString());
        order.setSku(sku);
        order.setQuantity(quantity);
        order.setStatus("CONFIRMED");
        order.setEstimatedDeliveryDays(stockInfo.getEtaDays());

        orderRepository.save(order);
        return order;
    }

    public Order getOrder(String id) {
        return orderRepository.findById(id)
            .orElseThrow(() -> new IllegalArgumentException("Order not found: " + id));
    }
}
