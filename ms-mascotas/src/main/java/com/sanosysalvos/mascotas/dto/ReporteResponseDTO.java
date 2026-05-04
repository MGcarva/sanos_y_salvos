package com.sanosysalvos.mascotas.dto;

import com.sanosysalvos.mascotas.domain.Reporte.EstadoReporte;
import com.sanosysalvos.mascotas.domain.Reporte.Tamano;
import lombok.*;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.UUID;

@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class ReporteResponseDTO {

    private UUID id;
    private UUID userId;
    private String tipo;
    private String especie;
    private String raza;
    private String nombre;
    private String color;
    private Tamano tamano;
    private String descripcion;
    private String fotoUrl;
    private EstadoReporte estado;
    private Double lat;
    private Double lng;
    private String direccion;
    private LocalDateTime fechaEvento;
    private LocalDateTime createdAt;

    // PERDIDO
    private BigDecimal recompensa;

    // ENCONTRADO
    private String lugarResguardo;
    private boolean tieneCollar;
}
