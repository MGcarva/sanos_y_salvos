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
}
