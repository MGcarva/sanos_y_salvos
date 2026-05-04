package com.sanosysalvos.geo.service;

import com.sanosysalvos.geo.domain.UbicacionReporte;
import com.sanosysalvos.geo.repository.UbicacionReporteRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.*;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
@Slf4j
public class ClusteringService {

    private static final double EPS_METERS = 1000.0;
    private static final int MIN_POINTS = 3;

    private final UbicacionReporteRepository repository;

    @Transactional
    public void runDBSCAN() {
        List<UbicacionReporte> points = repository.findAllGeocodificados();
        if (points.size() < MIN_POINTS) {
            log.info("Puntos insuficientes para clustering: {}", points.size());
            return;
        }

        // Reset clusters
        points.forEach(p -> p.setClusterId(null));

        int clusterId = 0;
        Set<UUID> visited = new HashSet<>();

        for (UbicacionReporte point : points) {
            if (visited.contains(point.getId())) continue;
            visited.add(point.getId());

            List<UbicacionReporte> neighbors = getNeighbors(point, points);
            if (neighbors.size() >= MIN_POINTS) {
                clusterId++;
                expandCluster(point, neighbors, clusterId, visited, points);
            }
        }

        repository.saveAll(points);
        log.info("DBSCAN completado: {} clusters encontrados", clusterId);
    }

    private void expandCluster(UbicacionReporte point, List<UbicacionReporte> neighbors,
                               int clusterId, Set<UUID> visited, List<UbicacionReporte> allPoints) {
        point.setClusterId(clusterId);
        Queue<UbicacionReporte> queue = new LinkedList<>(neighbors);

        while (!queue.isEmpty()) {
            UbicacionReporte neighbor = queue.poll();
            if (!visited.contains(neighbor.getId())) {
                visited.add(neighbor.getId());
                List<UbicacionReporte> neighborNeighbors = getNeighbors(neighbor, allPoints);
                if (neighborNeighbors.size() >= MIN_POINTS) {
                    queue.addAll(neighborNeighbors);
                }
            }
            if (neighbor.getClusterId() == null) {
                neighbor.setClusterId(clusterId);
            }
        }
    }

    private List<UbicacionReporte> getNeighbors(UbicacionReporte point, List<UbicacionReporte> allPoints) {
        return allPoints.stream()
                .filter(p -> haversineMeters(point.getLat(), point.getLng(), p.getLat(), p.getLng()) <= EPS_METERS)
                .collect(Collectors.toList());
    }

    private double haversineMeters(double lat1, double lng1, double lat2, double lng2) {
        double R = 6371000;
        double dLat = Math.toRadians(lat2 - lat1);
        double dLng = Math.toRadians(lng2 - lng1);
        double a = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
                   Math.cos(Math.toRadians(lat1)) * Math.cos(Math.toRadians(lat2)) *
                   Math.sin(dLng / 2) * Math.sin(dLng / 2);
        double c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
        return R * c;
    }
}
