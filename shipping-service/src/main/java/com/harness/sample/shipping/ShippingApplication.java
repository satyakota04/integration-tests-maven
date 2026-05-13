package com.harness.sample.shipping;

import io.javalin.Javalin;

public class ShippingApplication {
    public static void main(String[] args) {
        int port = Integer.parseInt(System.getProperty("server.port", "8083"));

        Javalin app = Javalin.create()
            .get("/eta/{sku}", ShippingHandler::getEta)
            .start(port);

        System.out.println("Shipping service started on port " + port);
    }
}
