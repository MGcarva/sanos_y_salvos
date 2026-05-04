package com.sanosysalvos.coincidencias.service;

import com.sanosysalvos.coincidencias.dto.CandidatoDTO;
import com.sanosysalvos.coincidencias.dto.GeoCompletadoEvent;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.ParameterizedTypeReference;
import org.springframework.http.HttpMethod;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestTemplate;

import java.util.Collections;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
@Slf4j
public class CandidateLoaderService {

    @Value("${matching.radius-km}")
    private int radiusKm;

    private final RestTemplate restTemplate = new RestTemplate();

    public List<CandidatoDTO> loadCandidates(GeoCompletadoEvent event) {
        String tipoOpuesto = "PERDIDO".equals(event.getTipo()) ? "ENCONTRADO" : "PERDIDO";

        try {
            String geoUrl = "http://ms-geolocalizacion:8083/api/geo/nearby?lat=" + event.getLat()
                    + "&lng=" + event.getLng()
                    + "&radiusMeters=" + (radiusKm * 1000);

            @SuppressWarnings("unchecked")
            List<Map<String, Object>> ubicaciones = restTemplate.getForObject(geoUrl, List.class);

            if (ubicaciones == null) return Collections.emptyList();

            return ubicaciones.stream()
                    .filter(u -> tipoOpuesto.equals(u.get("tipo")))
                    .map(u -> CandidatoDTO.builder()
                            .reporteId(parseUUID(u.get("reporteId")))
                            .userId(parseUUID(u.get("userId")))
                            .tipo((String) u.get("tipo"))
                            .especie((String) u.get("especie"))
                            .raza((String) u.get("raza"))
                            .color((String) u.get("color"))
                            .tamano((String) u.get("tamano"))
                            .fotoUrl((String) u.get("fotoUrl"))
                            .lat(toDouble(u.get("lat")))
                            .lng(toDouble(u.get("lng")))
                            .build())
                    .collect(Collectors.toList());

        } catch (Exception e) {
            log.error("Error cargando candidatos para reporte {}: {}", event.getReporteId(), e.getMessage());
            return Collections.emptyList();
        }
    }

    private java.util.UUID parseUUID(Object obj) {
        return obj != null ? java.util.UUID.fromString(obj.toString()) : null;
    }

    private Double toDouble(Object obj) {
        if (obj instanceof Number n) return n.doubleValue();
        return obj != null ? Double.parseDouble(obj.toString()) : null;
    }
}
