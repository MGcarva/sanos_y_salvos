package com.sanosysalvos.mascotas.controller;

import com.sanosysalvos.mascotas.domain.Reporte;
import com.sanosysalvos.mascotas.dto.*;
import com.sanosysalvos.mascotas.service.ReporteService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/reportes")
@RequiredArgsConstructor
@Tag(name = "Reportes", description = "Gestión de reportes de mascotas perdidas/encontradas")
public class ReporteController {

    private final ReporteService reporteService;

    @PostMapping(consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    @Operation(summary = "Crear nuevo reporte")
    public ResponseEntity<ReporteResponseDTO> crear(
            @Valid @RequestPart("reporte") ReporteRequestDTO dto,
            @RequestPart(value = "foto", required = false) MultipartFile foto,
            Authentication authentication) {
        UUID userId = UUID.fromString((String) authentication.getPrincipal());
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(reporteService.crearReporte(dto, foto, userId));
    }

    @GetMapping
    @Operation(summary = "Listar reportes activos")
    public ResponseEntity<List<ReporteResponseDTO>> listarActivos() {
        return ResponseEntity.ok(reporteService.listarActivos());
    }

    @GetMapping("/todos")
    @Operation(summary = "Listar todos los reportes")
    public ResponseEntity<List<ReporteResponseDTO>> listarTodos() {
        return ResponseEntity.ok(reporteService.listarTodos());
    }

    @GetMapping("/{id}")
    @Operation(summary = "Obtener reporte por ID")
    public ResponseEntity<ReporteResponseDTO> obtenerPorId(@PathVariable UUID id) {
        return ResponseEntity.ok(reporteService.obtenerPorId(id));
    }

    @GetMapping("/usuario/{userId}")
    @Operation(summary = "Listar reportes por usuario")
    public ResponseEntity<List<ReporteResponseDTO>> listarPorUsuario(@PathVariable UUID userId) {
        return ResponseEntity.ok(reporteService.listarPorUsuario(userId));
    }

    @PatchMapping("/{id}/estado")
    @Operation(summary = "Actualizar estado de reporte")
    public ResponseEntity<ReporteResponseDTO> actualizarEstado(
            @PathVariable UUID id,
            @RequestParam Reporte.EstadoReporte estado) {
        return ResponseEntity.ok(reporteService.actualizarEstado(id, estado));
    }
}
