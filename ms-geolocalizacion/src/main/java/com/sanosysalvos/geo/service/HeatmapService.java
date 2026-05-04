package com.sanosysalvos.geo.service;

import com.sanosysalvos.geo.domain.UbicacionReporte;
import com.sanosysalvos.geo.dto.HeatmapPointDTO;
import com.sanosysalvos.geo.repository.UbicacionReporteRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class HeatmapService {

    private final UbicacionReporteRepository repository;

    public List<HeatmapPointDTO> getHeatmapData(String tipo) {
        List<UbicacionReporte> ubicaciones = (tipo != null && !tipo.isBlank())
                ? repository.findByTipo(tipo.toUpperCase())
                : repository.findAllGeocodificados();

        return ubicaciones.stream()
                .map(u -> HeatmapPointDTO.builder()
                        .reporteId(u.getReporteId())
                        .lat(u.getLat())
                        .lng(u.getLng())
                        .tipo(u.getTipo())
                        .clusterId(u.getClusterId())
                        .intensidad(u.getClusterId() != null ? 1.0 : 0.5)
                        .build())
                .collect(Collectors.toList());
    }
}
