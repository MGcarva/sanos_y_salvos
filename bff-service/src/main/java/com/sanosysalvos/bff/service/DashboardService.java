package com.sanosysalvos.bff.service;

import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.stereotype.Service;

import java.time.Duration;
import java.util.Map;
import java.util.concurrent.CompletableFuture;

@Service
@RequiredArgsConstructor
@Slf4j
public class DashboardService {

    private final MascotasProxyService mascotasProxy;
    private final GeoProxyService geoProxy;
    private final StringRedisTemplate redisTemplate;
    private final ObjectMapper objectMapper;

    @Value("${cache.dashboard.ttl}")
    private long cacheTtl;

    public Map<String, Object> getDashboard() {
        String cacheKey = "dashboard:all";
        try {
            String cached = redisTemplate.opsForValue().get(cacheKey);
            if (cached != null) {
                log.debug("Dashboard cache HIT");
                return objectMapper.readValue(cached, Map.class);
            }
        } catch (Exception e) {
            log.warn("Error leyendo cache: {}", e.getMessage());
        }

        log.debug("Dashboard cache MISS - cargando datos");

        // Parallel calls
        var reportesFuture = CompletableFuture.supplyAsync(() -> {
            try { return mascotasProxy.listarActivos().getBody(); } catch (Exception e) {
                log.error("Error cargando reportes: {}", e.getMessage());
                return java.util.Collections.emptyList();
            }
        });

        var heatmapFuture = CompletableFuture.supplyAsync(() -> {
            try { return geoProxy.getHeatmap(null).getBody(); } catch (Exception e) {
                log.error("Error cargando heatmap: {}", e.getMessage());
                return java.util.Collections.emptyList();
            }
        });

        CompletableFuture.allOf(reportesFuture, heatmapFuture).join();

        Map<String, Object> dashboard = Map.of(
                "reportes", reportesFuture.join(),
                "heatmap", heatmapFuture.join(),
                "timestamp", System.currentTimeMillis()
        );

        try {
            String json = objectMapper.writeValueAsString(dashboard);
            redisTemplate.opsForValue().set(cacheKey, json, Duration.ofSeconds(cacheTtl));
        } catch (Exception e) {
            log.warn("Error guardando cache: {}", e.getMessage());
        }

        return dashboard;
    }

    public void invalidateCache() {
        try {
            redisTemplate.delete("dashboard:all");
            log.debug("Dashboard cache invalidated");
        } catch (Exception e) {
            log.warn("Error invalidando cache: {}", e.getMessage());
        }
    }
}
