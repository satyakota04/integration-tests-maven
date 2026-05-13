package com.harness.sample.shipping;

import io.javalin.http.Context;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

public class ShippingHandler {
    private static final Logger log = LoggerFactory.getLogger(ShippingHandler.class);

    public static void getEta(Context ctx) {
        String sku = ctx.pathParam("sku");
        log.info("            >>> [SHIPPING-SERVICE] Received GET /eta/{}", sku);
        int etaDays = EtaCalculator.calculate(sku);
        log.info("            <<< [SHIPPING-SERVICE] Returning ETA: {} days", etaDays);

        ctx.json(new EtaResponse(sku, etaDays));
    }

    public static class EtaResponse {
        public String sku;
        public int etaDays;

        public EtaResponse(String sku, int etaDays) {
            this.sku = sku;
            this.etaDays = etaDays;
        }
    }
}
