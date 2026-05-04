package com.sanosysalvos.bff.service;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.*;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestTemplate;

import java.util.List;
import java.util.Map;

@Service
@RequiredArgsConstructor
@Slf4j
public class CoincidenciasProxyService {

    private final RestTemplate restTemplate;

    @Value("${services.coincidencias-url}")
    private String coincidenciasUrl;

    public ResponseEntity<List> buscarPorPerdido(String reporteId) {
        ResponseEntity<List> r = restTemplate.getForEntity(coincidenciasUrl + "/api/coincidencias/perdido/" + reporteId, List.class);
        return ResponseEntity.status(r.getStatusCode()).body(r.getBody());
    }

    public ResponseEntity<List> buscarPorEncontrado(String reporteId) {
        ResponseEntity<List> r = restTemplate.getForEntity(coincidenciasUrl + "/api/coincidencias/encontrado/" + reporteId, List.class);
        return ResponseEntity.status(r.getStatusCode()).body(r.getBody());
    }
}
