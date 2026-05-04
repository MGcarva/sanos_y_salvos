package com.sanosysalvos.mascotas.domain;

import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.CreationTimestamp;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.UUID;

@Entity
@Table(name = "reportes")
@Getter @Setter @NoArgsConstructor @AllArgsConstructor
@Inheritance(strategy = InheritanceType.SINGLE_TABLE)
@DiscriminatorColumn(name = "tipo", discriminatorType = DiscriminatorType.STRING)
public abstract class Reporte {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(name = "user_id", nullable = false)
    private UUID userId;

    @Column(length = 100)
    private String especie;

    @Column(length = 100)
    private String raza;

    @Column(length = 100)
    private String nombre;

    @Column(length = 100)
    private String color;

    @Enumerated(EnumType.STRING)
    @Column(length = 20)
    private Tamano tamano;

    @Column(columnDefinition = "TEXT")
    private String descripcion;

    @Column(name = "foto_url")
    private String fotoUrl;

    @Enumerated(EnumType.STRING)
    @Column(length = 20)
    private EstadoReporte estado = EstadoReporte.ACTIVO;

    @Column(name = "lat")
    private Double lat;

    @Column(name = "lng")
    private Double lng;

    @Column(length = 500)
    private String direccion;

    @Column(name = "fecha_evento")
    private LocalDateTime fechaEvento;

    @CreationTimestamp
    @Column(name = "created_at", updatable = false)
    private LocalDateTime createdAt;

    public enum Tamano {
        PEQUENO, MEDIANO, GRANDE
    }

    public enum EstadoReporte {
        ACTIVO, INACTIVO, RESUELTO
    }

    public abstract String getTipo();
}
