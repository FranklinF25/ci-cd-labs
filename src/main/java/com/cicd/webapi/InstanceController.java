package com.cicd.webapi;

import java.util.Map;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * Identifica la instancia y la versión que procesa cada solicitud.
 * Necesario para demostrar el tráfico en la estrategia Blue-Green
 * (sección 17 del enunciado del proyecto final).
 */
@RestController
public class InstanceController {

    @Value("${app.instance.name}")
    private String instanceName;

    @Value("${server.port:8080}")
    private String port;

    @Value("${app.version}")
    private String version;

    @GetMapping("/api/instance")
    public Map<String, String> instance() {
        return Map.of(
                "instance", instanceName,
                "port", port,
                "version", version
        );
    }
}
