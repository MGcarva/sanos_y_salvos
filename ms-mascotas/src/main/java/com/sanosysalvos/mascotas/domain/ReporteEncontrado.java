package com.sanosysalvos.mascotas.domain;

import jakarta.persistence.*;
import lombok.*;

@Entity
@DiscriminatorValue("ENCONTRADO")
@Getter @Setter @NoArgsConstructor
public class ReporteEncontrado extends Reporte {

    @Column(name = "lugar_resguardo", length = 500)
    private String lugarResguardo;

    @Column(name = "tiene_collar")
    private boolean tieneCollar;

    @Builder(builderMethodName = "encontradoBuilder")
    public ReporteEncontrado(java.util.UUID userId, String especie, String raza, String nombre,
                             String color, Tamano tamano, String descripcion,
                             Double lat, Double lng, String direccion,
                             java.time.LocalDateTime fechaEvento,
                             String lugarResguardo, boolean tieneCollar) {
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
        this.lugarResguardo = lugarResguardo;
        this.tieneCollar = tieneCollar;
    }

    @Override
    public String getTipo() { return "ENCONTRADO"; }
}
