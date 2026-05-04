package com.sanosysalvos.geo.dto;

import lombok.*;

import java.util.UUID;

@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class HeatmapPointDTO {
    private UUID reporteId;
    private Double lat;
    private Double lng;
    private String tipo;
    private Integer clusterId;
    private double intensidad;
}
