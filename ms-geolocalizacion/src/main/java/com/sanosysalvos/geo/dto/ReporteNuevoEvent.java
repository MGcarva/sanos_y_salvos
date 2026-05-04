package com.sanosysalvos.geo.dto;

import lombok.*;

import java.io.Serializable;
import java.util.UUID;

@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class ReporteNuevoEvent implements Serializable {

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
    private String direccion;
}
