package com.sanosysalvos.coincidencias.domain;

import jakarta.persistence.*;
import lombok.*;
import org.hibernate.annotations.CreationTimestamp;

import java.time.LocalDateTime;
import java.util.UUID;

@Entity
@Table(name = "coincidencias")
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class Coincidencia {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(name = "reporte_perdido_id", nullable = false)
    private UUID reportePerdidoId;

    @Column(name = "reporte_encontrado_id", nullable = false)
    private UUID reporteEncontradoId;

    @Column(name = "score_total", nullable = false)
    private double scoreTotal;

    @Column(name = "score_raza")
    private double scoreRaza;

    @Column(name = "score_tamano")
    private double scoreTamano;

    @Column(name = "score_color")
    private double scoreColor;

    @Column(name = "score_geo")
    private double scoreGeo;

    @Column(name = "distancia_km")
    private double distanciaKm;

    @Enumerated(EnumType.STRING)
    @Column(length = 20)
    @Builder.Default
    private EstadoCoincidencia estado = EstadoCoincidencia.PENDIENTE;

    @Column(name = "notificado")
    @Builder.Default
    private boolean notificado = false;

    @CreationTimestamp
    @Column(name = "created_at", updatable = false)
    private LocalDateTime createdAt;

    public enum EstadoCoincidencia {
        PENDIENTE, CONFIRMADA, DESCARTADA
    }
}
