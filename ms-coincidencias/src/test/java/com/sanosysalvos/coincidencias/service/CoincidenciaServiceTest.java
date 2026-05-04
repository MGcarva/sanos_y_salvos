package com.sanosysalvos.coincidencias.service;

import com.sanosysalvos.coincidencias.domain.Coincidencia;
import com.sanosysalvos.coincidencias.domain.Coincidencia.EstadoCoincidencia;
import com.sanosysalvos.coincidencias.dto.CandidatoDTO;
import com.sanosysalvos.coincidencias.dto.CoincidenciaResponseDTO;
import com.sanosysalvos.coincidencias.dto.GeoCompletadoEvent;
import com.sanosysalvos.coincidencias.repository.CoincidenciaRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class CoincidenciaServiceTest {

    @Mock private CoincidenciaRepository repository;
    @Mock private ScoringService scoringService;
    @Mock private CandidateLoaderService candidateLoader;

    @InjectMocks
    private CoincidenciaService coincidenciaService;

    private UUID perdidoId;
    private UUID encontradoId;
    private Coincidencia testCoincidencia;

    @BeforeEach
    void setUp() {
        perdidoId = UUID.randomUUID();
        encontradoId = UUID.randomUUID();
        testCoincidencia = Coincidencia.builder()
                .id(UUID.randomUUID())
                .reportePerdidoId(perdidoId)
                .reporteEncontradoId(encontradoId)
                .scoreTotal(85.5)
                .scoreRaza(28.0)
                .scoreTamano(20.0)
                .scoreColor(8.5)
                .scoreGeo(11.0)
                .distanciaKm(2.3)
                .estado(EstadoCoincidencia.PENDIENTE)
                .createdAt(LocalDateTime.now())
                .build();
    }

    @Test
    void procesarEvento_withMatchingCandidates_createsCoincidencias() {
        GeoCompletadoEvent event = GeoCompletadoEvent.builder()
                .reporteId(perdidoId)
                .tipo("PERDIDO")
                .raza("Labrador")
                .tamano("GRANDE")
                .color("Dorado")
                .lat(4.711)
                .lng(-74.072)
                .build();

        CandidatoDTO candidate = CandidatoDTO.builder()
                .reporteId(encontradoId)
                .tipo("ENCONTRADO")
                .raza("Labrador")
                .tamano("GRANDE")
                .color("Dorado")
                .lat(4.712)
                .lng(-74.073)
                .build();

        ScoringService.ScoreResult score = new ScoringService.ScoreResult(85.0, 28.0, 20.0, 9.0, 11.0, 0.5);

        when(candidateLoader.loadCandidates(event)).thenReturn(List.of(candidate));
        when(scoringService.calcularScore(event, candidate)).thenReturn(score);
        when(scoringService.superaUmbral(85.0)).thenReturn(true);
        when(repository.existsByReportePerdidoIdAndReporteEncontradoId(perdidoId, encontradoId)).thenReturn(false);
        when(repository.saveAll(anyList())).thenAnswer(i -> i.getArgument(0));

        List<Coincidencia> result = coincidenciaService.procesarEvento(event);

        assertThat(result).hasSize(1);
        assertThat(result.get(0).getReportePerdidoId()).isEqualTo(perdidoId);
        assertThat(result.get(0).getReporteEncontradoId()).isEqualTo(encontradoId);
    }

    @Test
    void procesarEvento_noCandidates_returnsEmpty() {
        GeoCompletadoEvent event = GeoCompletadoEvent.builder()
                .reporteId(perdidoId)
                .tipo("PERDIDO")
                .build();

        when(candidateLoader.loadCandidates(event)).thenReturn(List.of());

        List<Coincidencia> result = coincidenciaService.procesarEvento(event);

        assertThat(result).isEmpty();
        verify(repository, never()).saveAll(anyList());
    }

    @Test
    void procesarEvento_belowThreshold_filtersOut() {
        GeoCompletadoEvent event = GeoCompletadoEvent.builder()
                .reporteId(perdidoId)
                .tipo("PERDIDO")
                .raza("Labrador")
                .build();

        CandidatoDTO candidate = CandidatoDTO.builder()
                .reporteId(encontradoId)
                .tipo("ENCONTRADO")
                .raza("Chihuahua")
                .build();

        ScoringService.ScoreResult score = new ScoringService.ScoreResult(40.0, 5.0, 0.0, 2.0, 0.0, 100.0);

        when(candidateLoader.loadCandidates(event)).thenReturn(List.of(candidate));
        when(scoringService.calcularScore(event, candidate)).thenReturn(score);
        when(scoringService.superaUmbral(40.0)).thenReturn(false);
        when(repository.saveAll(anyList())).thenReturn(List.of());

        List<Coincidencia> result = coincidenciaService.procesarEvento(event);

        assertThat(result).isEmpty();
    }

    @Test
    void procesarEvento_duplicateCoincidencia_skipped() {
        GeoCompletadoEvent event = GeoCompletadoEvent.builder()
                .reporteId(perdidoId)
                .tipo("PERDIDO")
                .raza("Labrador")
                .build();

        CandidatoDTO candidate = CandidatoDTO.builder()
                .reporteId(encontradoId)
                .tipo("ENCONTRADO")
                .raza("Labrador")
                .build();

        ScoringService.ScoreResult score = new ScoringService.ScoreResult(90.0, 30.0, 20.0, 10.0, 12.0, 0.5);

        when(candidateLoader.loadCandidates(event)).thenReturn(List.of(candidate));
        when(scoringService.calcularScore(event, candidate)).thenReturn(score);
        when(scoringService.superaUmbral(90.0)).thenReturn(true);
        when(repository.existsByReportePerdidoIdAndReporteEncontradoId(perdidoId, encontradoId)).thenReturn(true);
        when(repository.saveAll(anyList())).thenReturn(List.of());

        List<Coincidencia> result = coincidenciaService.procesarEvento(event);

        assertThat(result).isEmpty();
    }

    @Test
    void buscarPorPerdido_returnsMatches() {
        when(repository.findByReportePerdidoIdOrderByScoreTotalDesc(perdidoId))
                .thenReturn(List.of(testCoincidencia));

        List<CoincidenciaResponseDTO> result = coincidenciaService.buscarPorPerdido(perdidoId);

        assertThat(result).hasSize(1);
        assertThat(result.get(0).getScoreTotal()).isEqualTo(85.5);
    }

    @Test
    void buscarPorEncontrado_returnsMatches() {
        when(repository.findByReporteEncontradoIdOrderByScoreTotalDesc(encontradoId))
                .thenReturn(List.of(testCoincidencia));

        List<CoincidenciaResponseDTO> result = coincidenciaService.buscarPorEncontrado(encontradoId);

        assertThat(result).hasSize(1);
    }

    @Test
    void actualizarEstado_success() {
        UUID coincidenciaId = testCoincidencia.getId();
        when(repository.findById(coincidenciaId)).thenReturn(Optional.of(testCoincidencia));
        when(repository.save(any(Coincidencia.class))).thenReturn(testCoincidencia);

        CoincidenciaResponseDTO result = coincidenciaService.actualizarEstado(coincidenciaId, EstadoCoincidencia.CONFIRMADA);

        assertThat(result).isNotNull();
        verify(repository).save(testCoincidencia);
    }

    @Test
    void actualizarEstado_notFound_throwsException() {
        UUID randomId = UUID.randomUUID();
        when(repository.findById(randomId)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> coincidenciaService.actualizarEstado(randomId, EstadoCoincidencia.DESCARTADA))
                .isInstanceOf(RuntimeException.class)
                .hasMessageContaining("no encontrada");
    }
}
