package com.sanosysalvos.coincidencias.service;

import com.sanosysalvos.coincidencias.domain.Coincidencia;
import com.sanosysalvos.coincidencias.dto.CandidatoDTO;
import com.sanosysalvos.coincidencias.dto.CoincidenciaResponseDTO;
import com.sanosysalvos.coincidencias.dto.GeoCompletadoEvent;
import com.sanosysalvos.coincidencias.repository.CoincidenciaRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.UUID;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
@Slf4j
public class CoincidenciaService {

    private final CoincidenciaRepository repository;
    private final ScoringService scoringService;
    private final CandidateLoaderService candidateLoader;

    @Transactional
    public List<Coincidencia> procesarEvento(GeoCompletadoEvent event) {
        List<CandidatoDTO> candidates = candidateLoader.loadCandidates(event);
        log.info("Candidatos encontrados para reporte {}: {}", event.getReporteId(), candidates.size());

        List<Coincidencia> matches = candidates.stream()
                .map(candidate -> {
                    ScoringService.ScoreResult score = scoringService.calcularScore(event, candidate);
                    return new Object[]{ candidate, score };
                })
                .filter(arr -> scoringService.superaUmbral(((ScoringService.ScoreResult) arr[1]).total()))
                .map(arr -> {
                    CandidatoDTO candidate = (CandidatoDTO) arr[0];
                    ScoringService.ScoreResult score = (ScoringService.ScoreResult) arr[1];

                    UUID perdidoId = "PERDIDO".equals(event.getTipo()) ? event.getReporteId() : candidate.getReporteId();
                    UUID encontradoId = "ENCONTRADO".equals(event.getTipo()) ? event.getReporteId() : candidate.getReporteId();

                    if (repository.existsByReportePerdidoIdAndReporteEncontradoId(perdidoId, encontradoId)) {
                        return null;
                    }

                    return Coincidencia.builder()
                            .reportePerdidoId(perdidoId)
                            .reporteEncontradoId(encontradoId)
                            .scoreTotal(score.total())
                            .scoreRaza(score.raza())
                            .scoreTamano(score.tamano())
                            .scoreColor(score.color())
                            .scoreGeo(score.geo())
                            .distanciaKm(score.distanciaKm())
                            .build();
                })
                .filter(java.util.Objects::nonNull)
                .collect(Collectors.toList());

        List<Coincidencia> saved = repository.saveAll(matches);
        log.info("Coincidencias guardadas para reporte {}: {}", event.getReporteId(), saved.size());
        return saved;
    }

    public List<CoincidenciaResponseDTO> buscarPorPerdido(UUID reportePerdidoId) {
        return repository.findByReportePerdidoIdOrderByScoreTotalDesc(reportePerdidoId)
                .stream().map(this::toDTO).collect(Collectors.toList());
    }

    public List<CoincidenciaResponseDTO> buscarPorEncontrado(UUID reporteEncontradoId) {
        return repository.findByReporteEncontradoIdOrderByScoreTotalDesc(reporteEncontradoId)
                .stream().map(this::toDTO).collect(Collectors.toList());
    }

    @Transactional
    public CoincidenciaResponseDTO actualizarEstado(UUID id, Coincidencia.EstadoCoincidencia estado) {
        Coincidencia c = repository.findById(id)
                .orElseThrow(() -> new RuntimeException("Coincidencia no encontrada: " + id));
        c.setEstado(estado);
        return toDTO(repository.save(c));
    }

    private CoincidenciaResponseDTO toDTO(Coincidencia c) {
        return CoincidenciaResponseDTO.builder()
                .id(c.getId())
                .reportePerdidoId(c.getReportePerdidoId())
                .reporteEncontradoId(c.getReporteEncontradoId())
                .scoreTotal(c.getScoreTotal())
                .scoreRaza(c.getScoreRaza())
                .scoreTamano(c.getScoreTamano())
                .scoreColor(c.getScoreColor())
                .scoreGeo(c.getScoreGeo())
                .distanciaKm(c.getDistanciaKm())
                .estado(c.getEstado())
                .createdAt(c.getCreatedAt())
                .build();
    }
}
