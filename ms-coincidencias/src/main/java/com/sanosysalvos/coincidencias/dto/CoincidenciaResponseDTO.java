package com.sanosysalvos.coincidencias.dto;

import com.sanosysalvos.coincidencias.domain.Coincidencia;
import lombok.*;

import java.time.LocalDateTime;
import java.util.UUID;

@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class CoincidenciaResponseDTO {

    private UUID id;
    private UUID reportePerdidoId;
    private UUID reporteEncontradoId;
    private double scoreTotal;
    private double scoreRaza;
    private double scoreTamano;
    private double scoreColor;
    private double scoreGeo;
    private double distanciaKm;
    private Coincidencia.EstadoCoincidencia estado;
    private LocalDateTime createdAt;
}
