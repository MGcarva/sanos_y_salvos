package com.sanosysalvos.bff.controller;

import com.sanosysalvos.bff.service.DashboardService;
import com.sanosysalvos.bff.service.MascotasProxyService;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/reportes")
@RequiredArgsConstructor
@Tag(name = "Reportes (BFF)", description = "Proxy de reportes de mascotas")
public class ReportesController {

    private final MascotasProxyService mascotasProxy;
    private final DashboardService dashboardService;

    @GetMapping
    public ResponseEntity<List> listarActivos() {
        return mascotasProxy.listarActivos();
    }

    @GetMapping("/{id}")
    public ResponseEntity<Map> obtenerPorId(@PathVariable String id) {
        return mascotasProxy.obtenerPorId(id);
    }

    @PostMapping
    public ResponseEntity<Map> crear(
            @RequestPart("reporte") String reporteJson,
            @RequestPart(value = "foto", required = false) MultipartFile foto,
            Authentication authentication) {
        String token = (String) authentication.getCredentials();
        ResponseEntity<Map> response = mascotasProxy.crear(reporteJson, foto, token);
        dashboardService.invalidateCache();
        return response;
    }

    @GetMapping("/mis-reportes")
    public ResponseEntity<List> misReportes(Authentication authentication) {
        String userId = (String) authentication.getPrincipal();
        String token = (String) authentication.getCredentials();
        return mascotasProxy.listarPorUsuario(userId, token);
    }

    @PatchMapping("/{id}/estado")
    public ResponseEntity<Map> actualizarEstado(
            @PathVariable String id,
            @RequestParam String estado,
            Authentication authentication) {
        String token = (String) authentication.getCredentials();
        ResponseEntity<Map> response = mascotasProxy.actualizarEstado(id, estado, token);
        dashboardService.invalidateCache();
        return response;
    }
}
