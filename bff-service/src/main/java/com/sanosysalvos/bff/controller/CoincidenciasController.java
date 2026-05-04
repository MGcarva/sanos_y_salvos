package com.sanosysalvos.bff.controller;

import com.sanosysalvos.bff.service.CoincidenciasProxyService;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/coincidencias")
@RequiredArgsConstructor
@Tag(name = "Coincidencias (BFF)", description = "Proxy de coincidencias")
public class CoincidenciasController {

    private final CoincidenciasProxyService coincidenciasProxy;

    @GetMapping("/perdido/{reporteId}")
    public ResponseEntity<List> porPerdido(@PathVariable String reporteId) {
        return coincidenciasProxy.buscarPorPerdido(reporteId);
    }

    @GetMapping("/encontrado/{reporteId}")
    public ResponseEntity<List> porEncontrado(@PathVariable String reporteId) {
        return coincidenciasProxy.buscarPorEncontrado(reporteId);
    }
}
