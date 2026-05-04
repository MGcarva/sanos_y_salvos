package com.sanosysalvos.coincidencias.service;

import com.sanosysalvos.coincidencias.dto.CandidatoDTO;
import com.sanosysalvos.coincidencias.dto.GeoCompletadoEvent;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

@Service
@Slf4j
public class ScoringService {

    @Value("${matching.score.raza-weight}")
    private int razaWeight;

    @Value("${matching.score.tamano-weight}")
    private int tamanoWeight;

    @Value("${matching.score.geo-weight}")
    private int geoWeight;

    @Value("${matching.score.color-weight}")
    private int colorWeight;

    @Value("${matching.threshold}")
    private int threshold;

    @Value("${matching.radius-km}")
    private int radiusKm;

    public ScoreResult calcularScore(GeoCompletadoEvent source, CandidatoDTO candidate) {
        double raza = fuzzyScore(source.getRaza(), candidate.getRaza()) * razaWeight / 100.0;
        double tamano = equalScore(source.getTamano(), candidate.getTamano()) * tamanoWeight / 100.0;
        double color = fuzzyScore(source.getColor(), candidate.getColor()) * colorWeight / 100.0;
        double geo = geoScore(source.getLat(), source.getLng(), candidate.getLat(), candidate.getLng()) * geoWeight / 100.0;

        double total = raza + tamano + color + geo;
        double distancia = haversineKm(source.getLat(), source.getLng(), candidate.getLat(), candidate.getLng());

        return new ScoreResult(total, raza, tamano, color, geo, distancia);
    }

    public boolean superaUmbral(double score) {
        return score >= threshold;
    }

    private double fuzzyScore(String a, String b) {
        if (a == null || b == null) return 0;
        if (a.isBlank() || b.isBlank()) return 0;
        String na = a.trim().toLowerCase();
        String nb = b.trim().toLowerCase();
        if (na.equals(nb)) return 100;
        if (na.contains(nb) || nb.contains(na)) return 80;

        // Simple Levenshtein-based ratio
        int distance = levenshtein(na, nb);
        int maxLen = Math.max(na.length(), nb.length());
        return maxLen == 0 ? 100 : ((1.0 - (double) distance / maxLen) * 100);
    }

    private double equalScore(String a, String b) {
        if (a == null || b == null) return 0;
        return a.equalsIgnoreCase(b) ? 100 : 0;
    }

    private double geoScore(Double lat1, Double lng1, Double lat2, Double lng2) {
        if (lat1 == null || lng1 == null || lat2 == null || lng2 == null) return 0;
        double km = haversineKm(lat1, lng1, lat2, lng2);
        if (km > radiusKm) return 0;
        return (1.0 - km / radiusKm) * 100;
    }

    private double haversineKm(Double lat1, Double lng1, Double lat2, Double lng2) {
        double R = 6371;
        double dLat = Math.toRadians(lat2 - lat1);
        double dLng = Math.toRadians(lng2 - lng1);
        double a = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
                   Math.cos(Math.toRadians(lat1)) * Math.cos(Math.toRadians(lat2)) *
                   Math.sin(dLng / 2) * Math.sin(dLng / 2);
        double c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
        return R * c;
    }

    private int levenshtein(String a, String b) {
        int[][] dp = new int[a.length() + 1][b.length() + 1];
        for (int i = 0; i <= a.length(); i++) dp[i][0] = i;
        for (int j = 0; j <= b.length(); j++) dp[0][j] = j;
        for (int i = 1; i <= a.length(); i++) {
            for (int j = 1; j <= b.length(); j++) {
                int cost = a.charAt(i - 1) == b.charAt(j - 1) ? 0 : 1;
                dp[i][j] = Math.min(Math.min(dp[i - 1][j] + 1, dp[i][j - 1] + 1), dp[i - 1][j - 1] + cost);
            }
        }
        return dp[a.length()][b.length()];
    }

    public record ScoreResult(double total, double raza, double tamano, double color, double geo, double distanciaKm) {}
}
