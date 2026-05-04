package com.sanosysalvos.coincidencias.service;

import com.sanosysalvos.coincidencias.dto.CandidatoDTO;
import com.sanosysalvos.coincidencias.dto.GeoCompletadoEvent;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.test.util.ReflectionTestUtils;

import java.util.UUID;

import static org.assertj.core.api.Assertions.*;

class ScoringServiceTest {

    private ScoringService scoringService;

    @BeforeEach
    void setUp() {
        scoringService = new ScoringService();
        ReflectionTestUtils.setField(scoringService, "razaWeight", 30);
        ReflectionTestUtils.setField(scoringService, "tamanoWeight", 20);
        ReflectionTestUtils.setField(scoringService, "geoWeight", 12);
        ReflectionTestUtils.setField(scoringService, "colorWeight", 10);
        ReflectionTestUtils.setField(scoringService, "threshold", 80);
        ReflectionTestUtils.setField(scoringService, "radiusKm", 50);
    }

    @Test
    void calcularScore_perfectMatch_highScore() {
        GeoCompletadoEvent source = GeoCompletadoEvent.builder()
                .reporteId(UUID.randomUUID())
                .tipo("PERDIDO")
                .raza("Labrador")
                .tamano("GRANDE")
                .color("Dorado")
                .lat(4.711)
                .lng(-74.072)
                .build();

        CandidatoDTO candidate = CandidatoDTO.builder()
                .reporteId(UUID.randomUUID())
                .tipo("ENCONTRADO")
                .raza("Labrador")
                .tamano("GRANDE")
                .color("Dorado")
                .lat(4.711)
                .lng(-74.072)
                .build();

        ScoringService.ScoreResult result = scoringService.calcularScore(source, candidate);

        assertThat(result.total()).isGreaterThan(60);
        assertThat(result.raza()).isEqualTo(30.0);
        assertThat(result.tamano()).isEqualTo(20.0);
        assertThat(result.color()).isEqualTo(10.0);
        assertThat(result.geo()).isEqualTo(12.0);
        assertThat(result.distanciaKm()).isEqualTo(0.0);
    }

    @Test
    void calcularScore_noMatch_lowScore() {
        GeoCompletadoEvent source = GeoCompletadoEvent.builder()
                .reporteId(UUID.randomUUID())
                .tipo("PERDIDO")
                .raza("Labrador")
                .tamano("GRANDE")
                .color("Dorado")
                .lat(4.711)
                .lng(-74.072)
                .build();

        CandidatoDTO candidate = CandidatoDTO.builder()
                .reporteId(UUID.randomUUID())
                .tipo("ENCONTRADO")
                .raza("Chihuahua")
                .tamano("PEQUENO")
                .color("Negro")
                .lat(10.0)
                .lng(-80.0)
                .build();

        ScoringService.ScoreResult result = scoringService.calcularScore(source, candidate);

        assertThat(result.total()).isLessThan(30);
        assertThat(result.tamano()).isEqualTo(0.0);
    }

    @Test
    void calcularScore_partialMatch_mediumScore() {
        GeoCompletadoEvent source = GeoCompletadoEvent.builder()
                .reporteId(UUID.randomUUID())
                .tipo("PERDIDO")
                .raza("Labrador Retriever")
                .tamano("GRANDE")
                .color("Dorado claro")
                .lat(4.711)
                .lng(-74.072)
                .build();

        CandidatoDTO candidate = CandidatoDTO.builder()
                .reporteId(UUID.randomUUID())
                .tipo("ENCONTRADO")
                .raza("Labrador")
                .tamano("GRANDE")
                .color("Dorado")
                .lat(4.720)
                .lng(-74.080)
                .build();

        ScoringService.ScoreResult result = scoringService.calcularScore(source, candidate);

        assertThat(result.total()).isGreaterThan(40);
        assertThat(result.tamano()).isEqualTo(20.0);
        assertThat(result.raza()).isGreaterThan(20.0);
    }

    @Test
    void calcularScore_nullFields_handledGracefully() {
        GeoCompletadoEvent source = GeoCompletadoEvent.builder()
                .reporteId(UUID.randomUUID())
                .tipo("PERDIDO")
                .raza(null)
                .tamano(null)
                .color(null)
                .lat(null)
                .lng(null)
                .build();

        CandidatoDTO candidate = CandidatoDTO.builder()
                .reporteId(UUID.randomUUID())
                .tipo("ENCONTRADO")
                .raza("Labrador")
                .tamano("GRANDE")
                .color("Dorado")
                .lat(4.711)
                .lng(-74.072)
                .build();

        ScoringService.ScoreResult result = scoringService.calcularScore(source, candidate);

        assertThat(result.total()).isEqualTo(0.0);
        assertThat(result.raza()).isEqualTo(0.0);
        assertThat(result.tamano()).isEqualTo(0.0);
    }

    @Test
    void calcularScore_fuzzyRaza_partialScore() {
        GeoCompletadoEvent source = GeoCompletadoEvent.builder()
                .reporteId(UUID.randomUUID())
                .raza("Pastor Aleman")
                .tamano("GRANDE")
                .color("Negro y cafe")
                .lat(4.711)
                .lng(-74.072)
                .build();

        CandidatoDTO candidate = CandidatoDTO.builder()
                .reporteId(UUID.randomUUID())
                .raza("Pastor Alemán")
                .tamano("GRANDE")
                .color("Negro")
                .lat(4.711)
                .lng(-74.072)
                .build();

        ScoringService.ScoreResult result = scoringService.calcularScore(source, candidate);

        assertThat(result.raza()).isGreaterThan(20.0);
    }

    @Test
    void calcularScore_farDistance_zeroGeo() {
        GeoCompletadoEvent source = GeoCompletadoEvent.builder()
                .reporteId(UUID.randomUUID())
                .raza("Labrador")
                .tamano("GRANDE")
                .color("Dorado")
                .lat(4.711)
                .lng(-74.072)
                .build();

        CandidatoDTO candidate = CandidatoDTO.builder()
                .reporteId(UUID.randomUUID())
                .raza("Labrador")
                .tamano("GRANDE")
                .color("Dorado")
                .lat(7.0)
                .lng(-73.0)
                .build();

        ScoringService.ScoreResult result = scoringService.calcularScore(source, candidate);

        assertThat(result.geo()).isEqualTo(0.0);
        assertThat(result.distanciaKm()).isGreaterThan(50);
    }

    @Test
    void superaUmbral_above_returnsTrue() {
        assertThat(scoringService.superaUmbral(85.0)).isTrue();
    }

    @Test
    void superaUmbral_below_returnsFalse() {
        assertThat(scoringService.superaUmbral(75.0)).isFalse();
    }

    @Test
    void superaUmbral_exact_returnsTrue() {
        assertThat(scoringService.superaUmbral(80.0)).isTrue();
    }

    @Test
    void calcularScore_sameLocation_maxGeoScore() {
        GeoCompletadoEvent source = GeoCompletadoEvent.builder()
                .reporteId(UUID.randomUUID())
                .raza("Persa")
                .tamano("MEDIANO")
                .color("Blanco")
                .lat(4.711)
                .lng(-74.072)
                .build();

        CandidatoDTO candidate = CandidatoDTO.builder()
                .reporteId(UUID.randomUUID())
                .raza("Persa")
                .tamano("MEDIANO")
                .color("Blanco")
                .lat(4.711)
                .lng(-74.072)
                .build();

        ScoringService.ScoreResult result = scoringService.calcularScore(source, candidate);

        assertThat(result.geo()).isEqualTo(12.0);
        assertThat(result.distanciaKm()).isEqualTo(0.0);
    }

    @Test
    void calcularScore_containsMatch_80percent() {
        GeoCompletadoEvent source = GeoCompletadoEvent.builder()
                .reporteId(UUID.randomUUID())
                .raza("Labrador Retriever Golden")
                .tamano("GRANDE")
                .color("Dorado")
                .lat(4.711)
                .lng(-74.072)
                .build();

        CandidatoDTO candidate = CandidatoDTO.builder()
                .reporteId(UUID.randomUUID())
                .raza("Labrador")
                .tamano("GRANDE")
                .color("Dorado")
                .lat(4.711)
                .lng(-74.072)
                .build();

        ScoringService.ScoreResult result = scoringService.calcularScore(source, candidate);

        assertThat(result.raza()).isEqualTo(30.0 * 80.0 / 100.0);
    }
}
