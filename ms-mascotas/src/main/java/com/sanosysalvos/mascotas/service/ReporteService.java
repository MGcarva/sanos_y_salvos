package com.sanosysalvos.mascotas.service;

import com.sanosysalvos.mascotas.domain.*;
import com.sanosysalvos.mascotas.dto.*;
import com.sanosysalvos.mascotas.factory.ReporteFactory;
import com.sanosysalvos.mascotas.repository.ReporteRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

import java.util.List;
import java.util.UUID;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
@Slf4j
public class ReporteService {

    private final ReporteRepository reporteRepository;
    private final ReporteFactory reporteFactory;
    private final MinioService minioService;
    private final EventPublisher eventPublisher;

    @Transactional
    public ReporteResponseDTO crearReporte(ReporteRequestDTO dto, MultipartFile foto, UUID userId) {
        Reporte reporte = reporteFactory.crear(dto, userId);

        reporte = reporteRepository.save(reporte);

        if (foto != null && !foto.isEmpty()) {
            String fotoUrl = minioService.uploadImage(foto, reporte.getId());
            reporte.setFotoUrl(fotoUrl);
            reporte = reporteRepository.save(reporte);
        }

        eventPublisher.publishReporteNuevo(reporte);
        log.info("Reporte creado: {} tipo {}", reporte.getId(), reporte.getTipo());

        return toResponseDTO(reporte);
    }

    public List<ReporteResponseDTO> listarActivos() {
        return reporteRepository.findAllActivos().stream()
                .map(this::toResponseDTO)
                .collect(Collectors.toList());
    }

    public List<ReporteResponseDTO> listarTodos() {
        return reporteRepository.findAllByOrderByCreatedAtDesc().stream()
                .map(this::toResponseDTO)
                .collect(Collectors.toList());
    }

    public ReporteResponseDTO obtenerPorId(UUID id) {
        Reporte reporte = reporteRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Reporte no encontrado: " + id));
        return toResponseDTO(reporte);
    }

    public List<ReporteResponseDTO> listarPorUsuario(UUID userId) {
        return reporteRepository.findByUserId(userId).stream()
                .map(this::toResponseDTO)
                .collect(Collectors.toList());
    }

    @Transactional
    public ReporteResponseDTO actualizarEstado(UUID id, Reporte.EstadoReporte estado) {
        Reporte reporte = reporteRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Reporte no encontrado: " + id));
        reporte.setEstado(estado);
        return toResponseDTO(reporteRepository.save(reporte));
    }

    private ReporteResponseDTO toResponseDTO(Reporte r) {
        ReporteResponseDTO.ReporteResponseDTOBuilder builder = ReporteResponseDTO.builder()
                .id(r.getId())
                .userId(r.getUserId())
                .tipo(r.getTipo())
                .especie(r.getEspecie())
                .raza(r.getRaza())
                .nombre(r.getNombre())
                .color(r.getColor())
                .tamano(r.getTamano())
                .descripcion(r.getDescripcion())
                .fotoUrl(r.getFotoUrl())
                .estado(r.getEstado())
                .lat(r.getLat())
                .lng(r.getLng())
                .direccion(r.getDireccion())
                .fechaEvento(r.getFechaEvento())
                .createdAt(r.getCreatedAt());

        if (r instanceof ReportePerdido rp) {
            builder.recompensa(rp.getRecompensa());
        } else if (r instanceof ReporteEncontrado re) {
            builder.lugarResguardo(re.getLugarResguardo());
            builder.tieneCollar(re.isTieneCollar());
        }

        return builder.build();
    }
}
