package com.sanosysalvos.geo.service;

import com.sanosysalvos.geo.domain.UbicacionReporte;
import com.sanosysalvos.geo.repository.UbicacionReporteRepository;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class ClusteringServiceTest {

    @Mock
    private UbicacionReporteRepository repository;

    @InjectMocks
    private ClusteringService clusteringService;

    @Test
    void runDBSCAN_insufficientPoints_doesNotCluster() {
        when(repository.findAllGeocodificados()).thenReturn(List.of(
                buildUbicacion(4.711, -74.072)
        ));

        clusteringService.runDBSCAN();

        verify(repository, never()).saveAll(anyList());
    }

    @Test
    void runDBSCAN_closePoints_formCluster() {
        List<UbicacionReporte> points = new ArrayList<>();
        // 5 points within 1km of each other in Bogotá
        points.add(buildUbicacion(4.7110, -74.0720));
        points.add(buildUbicacion(4.7115, -74.0725));
        points.add(buildUbicacion(4.7120, -74.0730));
        points.add(buildUbicacion(4.7105, -74.0715));
        points.add(buildUbicacion(4.7108, -74.0718));

        when(repository.findAllGeocodificados()).thenReturn(points);

        clusteringService.runDBSCAN();

        verify(repository).saveAll(points);
        // All points should have same clusterId since they're close
        boolean allClustered = points.stream().allMatch(p -> p.getClusterId() != null);
        assert allClustered : "All close points should be clustered";
    }

    @Test
    void runDBSCAN_farPoints_noCluster() {
        List<UbicacionReporte> points = new ArrayList<>();
        // 3 points far apart (different cities)
        points.add(buildUbicacion(4.711, -74.072));   // Bogotá
        points.add(buildUbicacion(6.251, -75.564));   // Medellín
        points.add(buildUbicacion(3.437, -76.522));   // Cali

        when(repository.findAllGeocodificados()).thenReturn(points);

        clusteringService.runDBSCAN();

        verify(repository).saveAll(points);
        boolean noneClustered = points.stream().allMatch(p -> p.getClusterId() == null);
        assert noneClustered : "Far apart points should not be clustered";
    }

    @Test
    void runDBSCAN_mixedDistance_partialCluster() {
        List<UbicacionReporte> points = new ArrayList<>();
        // 3 close points (cluster) + 1 far point
        points.add(buildUbicacion(4.7110, -74.0720));
        points.add(buildUbicacion(4.7115, -74.0725));
        points.add(buildUbicacion(4.7120, -74.0730));
        points.add(buildUbicacion(6.251, -75.564));  // Medellín - far away

        when(repository.findAllGeocodificados()).thenReturn(points);

        clusteringService.runDBSCAN();

        verify(repository).saveAll(points);
    }

    @Test
    void runDBSCAN_emptyList_doesNothing() {
        when(repository.findAllGeocodificados()).thenReturn(List.of());

        clusteringService.runDBSCAN();

        verify(repository, never()).saveAll(anyList());
    }

    private UbicacionReporte buildUbicacion(double lat, double lng) {
        return UbicacionReporte.builder()
                .id(UUID.randomUUID())
                .reporteId(UUID.randomUUID())
                .userId(UUID.randomUUID())
                .tipo("PERDIDO")
                .lat(lat)
                .lng(lng)
                .especie("Perro")
                .raza("Labrador")
                .color("Dorado")
                .tamano("GRANDE")
                .build();
    }
}
