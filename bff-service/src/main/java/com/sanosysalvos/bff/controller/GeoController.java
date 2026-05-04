package com.sanosysalvos.bff.controller;

import com.sanosysalvos.bff.service.CoincidenciasProxyService;
import com.sanosysalvos.bff.service.GeoProxyService;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/geo")
@RequiredArgsConstructor
@Tag(name = "Geo (BFF)", description = "Proxy de geolocalización")
public class GeoController {

    private final GeoProxyService geoProxy;

    @GetMapping("/heatmap")
    public ResponseEntity<List> heatmap(@RequestParam(required = false) String tipo) {
        return geoProxy.getHeatmap(tipo);
    }

    @GetMapping("/nearby")
    public ResponseEntity<List> nearby(
            @RequestParam Double lat,
            @RequestParam Double lng,
            @RequestParam(defaultValue = "5000") Double radiusMeters) {
        return geoProxy.getNearby(lat, lng, radiusMeters);
    }

    @GetMapping("/clusters")
    public ResponseEntity<List> clusters() {
        return geoProxy.getClusters();
    }
}
