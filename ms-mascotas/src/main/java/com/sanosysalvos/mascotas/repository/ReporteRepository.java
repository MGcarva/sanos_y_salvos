package com.sanosysalvos.mascotas.repository;

import com.sanosysalvos.mascotas.domain.Reporte;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.UUID;

@Repository
public interface ReporteRepository extends JpaRepository<Reporte, UUID> {

    List<Reporte> findByUserId(UUID userId);

    @Query("SELECT r FROM Reporte r WHERE r.estado = 'ACTIVO' AND TYPE(r) = :tipo")
    List<Reporte> findActivosByTipo(Class<? extends Reporte> tipo);

    @Query("SELECT r FROM Reporte r WHERE r.estado = 'ACTIVO' ORDER BY r.createdAt DESC")
    List<Reporte> findAllActivos();

    List<Reporte> findAllByOrderByCreatedAtDesc();

    @Query("SELECT r FROM Reporte r WHERE r.estado = 'ACTIVO' AND r.especie = :especie")
    List<Reporte> findActivosByEspecie(String especie);

    /**
     * Búsqueda avanzada de reportes por múltiples características
     * Usa LOWER y LIKE para búsqueda flexible (case-insensitive, parcial)
     */
    @Query("SELECT r FROM Reporte r WHERE r.estado = 'ACTIVO' " +
            "AND (:tipoReporte IS NULL OR ((:tipoReporte = 'PERDIDO' AND TYPE(r) = com.sanosysalvos.mascotas.domain.ReportePerdido) OR (:tipoReporte = 'ENCONTRADO' AND TYPE(r) = com.sanosysalvos.mascotas.domain.ReporteEncontrado))) " +
            "AND (:especie IS NULL OR LOWER(r.especie) LIKE LOWER(CONCAT('%', CAST(:especie AS string), '%'))) " +
            "AND (:raza IS NULL OR LOWER(r.raza) LIKE LOWER(CONCAT('%', CAST(:raza AS string), '%'))) " +
            "AND (:color IS NULL OR LOWER(r.color) LIKE LOWER(CONCAT('%', CAST(:color AS string), '%'))) " +
            "AND (:nombre IS NULL OR LOWER(r.nombre) LIKE LOWER(CONCAT('%', CAST(:nombre AS string), '%'))) " +
            "AND (:tamano IS NULL OR r.tamano = :tamano) " +
            "AND (:direccion IS NULL OR LOWER(r.direccion) LIKE LOWER(CONCAT('%', CAST(:direccion AS string), '%'))) " +
            "ORDER BY r.createdAt DESC")
    List<Reporte> buscarPorCaracteristicas(
            String tipoReporte,
            String especie,
            String raza,
            String color,
            String nombre,
            Reporte.Tamano tamano,
            String direccion
    );
}
