package com.sanosysalvos.mascotas.dto;

import com.sanosysalvos.mascotas.domain.Reporte.Tamano;
import jakarta.validation.constraints.*;
import lombok.*;

import java.math.BigDecimal;
import java.time.LocalDateTime;

@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class ReporteRequestDTO {

    @NotBlank(message = "El tipo es obligatorio (PERDIDO o ENCONTRADO)")
    private String tipo;

    @NotBlank(message = "La especie es obligatoria")
    private String especie;

    private String raza;
    private String nombre;
    private String color;
    private Tamano tamano;

    @NotBlank(message = "La descripción es obligatoria")
    private String descripcion;

    private Double lat;
    private Double lng;
    private String direccion;
    private LocalDateTime fechaEvento;

    // Campos específicos de PERDIDO
    private BigDecimal recompensa;

    // Campos específicos de ENCONTRADO
    private String lugarResguardo;
    private boolean tieneCollar;
}
