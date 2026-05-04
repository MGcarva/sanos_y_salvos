package com.sanosysalvos.geo.service;

import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestTemplate;

import java.util.List;
import java.util.Map;

@Service
@Slf4j
public class GeocodingService {

    private final String nominatimBaseUrl;
    private final RestTemplate restTemplate;

    public GeocodingService(@Value("${nominatim.base-url}") String nominatimBaseUrl) {
        this.nominatimBaseUrl = nominatimBaseUrl;
        this.restTemplate = new RestTemplate();
    }

    public String reverseGeocode(Double lat, Double lng) {
        try {
            return reverseGeocodeNominatim(lat, lng);
        } catch (Exception e) {
            log.warn("Fallo geocodificación inversa para ({}, {}): {}", lat, lng, e.getMessage());
            return null;
        }
    }

    private String reverseGeocodeNominatim(Double lat, Double lng) {
        String url = nominatimBaseUrl + "/reverse?format=json&lat=" + lat + "&lon=" + lng + "&zoom=18&addressdetails=1";
        try {
            @SuppressWarnings("unchecked")
            Map<String, Object> response = restTemplate.getForObject(url, Map.class);
            if (response != null && response.containsKey("display_name")) {
                return (String) response.get("display_name");
            }
        } catch (Exception e) {
            log.error("Error Nominatim: {}", e.getMessage());
        }
        return null;
    }

    public double[] geocodeAddress(String address) {
        try {
            String url = nominatimBaseUrl + "/search?format=json&q=" + address + "&limit=1";
            @SuppressWarnings("unchecked")
            List<Map<String, Object>> results = restTemplate.getForObject(url, List.class);
            if (results != null && !results.isEmpty()) {
                Map<String, Object> result = results.get(0);
                double lat = Double.parseDouble(result.get("lat").toString());
                double lon = Double.parseDouble(result.get("lon").toString());
                return new double[]{lat, lon};
            }
        } catch (Exception e) {
            log.error("Error geocodificando dirección: {}", e.getMessage());
        }
        return null;
    }
}
