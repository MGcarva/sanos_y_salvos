package com.sanosysalvos.coincidencias.dto;

import lombok.*;

import java.util.UUID;

@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class CandidatoDTO {

    private UUID reporteId;
    private UUID userId;
    private String tipo;
    private String especie;
    private String raza;
    private String color;
    private String tamano;
    private String fotoUrl;
    private Double lat;
    private Double lng;
}
