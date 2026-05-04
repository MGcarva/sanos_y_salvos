package com.sanosysalvos.coincidencias.controller;

import com.sanosysalvos.coincidencias.domain.Coincidencia;
import com.sanosysalvos.coincidencias.dto.CoincidenciaResponseDTO;
import com.sanosysalvos.coincidencias.service.CoincidenciaService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/coincidencias")
@RequiredArgsConstructor
@Tag(name = "Coincidencias", description = "Consulta y gestión de coincidencias")
public class CoincidenciaController {

    private final CoincidenciaService coincidenciaService;

    @GetMapping("/perdido/{reporteId}")
    @Operation(summary = "Coincidencias para un reporte perdido")
    public ResponseEntity<List<CoincidenciaResponseDTO>> porPerdido(@PathVariable UUID reporteId) {
        return ResponseEntity.ok(coincidenciaService.buscarPorPerdido(reporteId));
    }

    @GetMapping("/encontrado/{reporteId}")
    @Operation(summary = "Coincidencias para un reporte encontrado")
    public ResponseEntity<List<CoincidenciaResponseDTO>> porEncontrado(@PathVariable UUID reporteId) {
        return ResponseEntity.ok(coincidenciaService.buscarPorEncontrado(reporteId));
    }

    @PatchMapping("/{id}/estado")
    @Operation(summary = "Actualizar estado de coincidencia")
    public ResponseEntity<CoincidenciaResponseDTO> actualizarEstado(
            @PathVariable UUID id,
            @RequestParam Coincidencia.EstadoCoincidencia estado) {
        return ResponseEntity.ok(coincidenciaService.actualizarEstado(id, estado));
    }
}
