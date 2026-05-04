package com.sanosysalvos.coincidencias.repository;

import com.sanosysalvos.coincidencias.domain.Coincidencia;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.UUID;

@Repository
public interface CoincidenciaRepository extends JpaRepository<Coincidencia, UUID> {

    List<Coincidencia> findByReportePerdidoIdOrderByScoreTotalDesc(UUID reportePerdidoId);

    List<Coincidencia> findByReporteEncontradoIdOrderByScoreTotalDesc(UUID reporteEncontradoId);

    boolean existsByReportePerdidoIdAndReporteEncontradoId(UUID perdidoId, UUID encontradoId);
}
