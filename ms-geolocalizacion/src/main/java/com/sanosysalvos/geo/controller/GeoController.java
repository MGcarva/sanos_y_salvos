package com.sanosysalvos.geo.controller;

import com.sanosysalvos.geo.domain.UbicacionReporte;
import com.sanosysalvos.geo.dto.HeatmapPointDTO;
import com.sanosysalvos.geo.repository.UbicacionReporteRepository;
import com.sanosysalvos.geo.service.HeatmapService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/geo")
@RequiredArgsConstructor
@Tag(name = "Geolocalización", description = "Consultas geoespaciales y heatmaps")
public class GeoController {

    private final UbicacionReporteRepository repository;
    private final HeatmapService heatmapService;

    @GetMapping("/heatmap")
    @Operation(summary = "Obtener datos del heatmap")
    public ResponseEntity<List<HeatmapPointDTO>> getHeatmap(
            @RequestParam(required = false) String tipo) {
        return ResponseEntity.ok(heatmapService.getHeatmapData(tipo));
    }

    @GetMapping("/nearby")
    @Operation(summary = "Buscar reportes cercanos a un punto")
    public ResponseEntity<List<UbicacionReporte>> getNearby(
            @RequestParam Double lat,
            @RequestParam Double lng,
            @RequestParam(defaultValue = "5000") Double radiusMeters) {
        return ResponseEntity.ok(repository.findWithinRadius(lat, lng, radiusMeters));
    }

    @GetMapping("/reporte/{reporteId}")
    @Operation(summary = "Obtener ubicación de un reporte")
    public ResponseEntity<UbicacionReporte> getByReporteId(@PathVariable UUID reporteId) {
        return repository.findByReporteId(reporteId)
                .map(ResponseEntity::ok)
                .orElse(ResponseEntity.notFound().build());
    }

    @GetMapping("/clusters")
    @Operation(summary = "Obtener reportes con cluster asignado")
    public ResponseEntity<List<UbicacionReporte>> getClusters() {
        return ResponseEntity.ok(repository.findAllWithCluster());
    }
}
