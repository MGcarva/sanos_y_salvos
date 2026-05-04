package com.sanosysalvos.geo.domain;

import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.CreationTimestamp;

import java.time.LocalDateTime;
import java.util.UUID;

@Entity
@Table(name = "ubicaciones_reporte")
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class UbicacionReporte {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(name = "reporte_id", nullable = false, unique = true)
    private UUID reporteId;

    @Column(name = "user_id", nullable = false)
    private UUID userId;

    @Column(nullable = false, length = 20)
    private String tipo;

    @Column(nullable = false)
    private Double lat;

    @Column(nullable = false)
    private Double lng;

    @Column(length = 500)
    private String direccion;

    @Column(name = "direccion_geocodificada", length = 500)
    private String direccionGeocodificada;

    @Column(length = 100)
    private String especie;

    @Column(length = 100)
    private String raza;

    @Column(length = 100)
    private String color;

    @Column(length = 20)
    private String tamano;

    @Column(name = "foto_url")
    private String fotoUrl;

    @Column(name = "cluster_id")
    private Integer clusterId;

    @Column(name = "geocodificado")
    @Builder.Default
    private boolean geocodificado = false;

    @CreationTimestamp
    @Column(name = "created_at", updatable = false)
    private LocalDateTime createdAt;
}
