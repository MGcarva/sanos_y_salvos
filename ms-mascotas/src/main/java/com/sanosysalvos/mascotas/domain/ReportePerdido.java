package com.sanosysalvos.mascotas.domain;

import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;

@Entity
@DiscriminatorValue("PERDIDO")
@Getter @Setter @NoArgsConstructor
public class ReportePerdido extends Reporte {

    @Column
    private BigDecimal recompensa;

    @Builder(builderMethodName = "perdidoBuilder")
    public ReportePerdido(java.util.UUID userId, String especie, String raza, String nombre,
                          String color, Tamano tamano, String descripcion,
                          Double lat, Double lng, String direccion,
                          java.time.LocalDateTime fechaEvento, BigDecimal recompensa) {
        setUserId(userId);
        setEspecie(especie);
        setRaza(raza);
        setNombre(nombre);
        setColor(color);
        setTamano(tamano);
        setDescripcion(descripcion);
        setLat(lat);
        setLng(lng);
        setDireccion(direccion);
        setFechaEvento(fechaEvento);
        this.recompensa = recompensa;
    }

    @Override
    public String getTipo() { return "PERDIDO"; }
}
