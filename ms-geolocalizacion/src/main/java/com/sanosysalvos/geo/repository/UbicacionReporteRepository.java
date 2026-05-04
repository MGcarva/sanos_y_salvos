package com.sanosysalvos.geo.repository;

import com.sanosysalvos.geo.domain.UbicacionReporte;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface UbicacionReporteRepository extends JpaRepository<UbicacionReporte, UUID> {

    Optional<UbicacionReporte> findByReporteId(UUID reporteId);

    @Query(value = """
            SELECT * FROM ubicaciones_reporte u
            WHERE ST_DWithin(
                CAST(ST_SetSRID(ST_MakePoint(u.lng, u.lat), 4326) AS geography),
                CAST(ST_SetSRID(ST_MakePoint(:lng, :lat), 4326) AS geography),
                :radiusMeters
            )
            """, nativeQuery = true)
    List<UbicacionReporte> findWithinRadius(Double lat, Double lng, Double radiusMeters);

    @Query("SELECT u FROM UbicacionReporte u WHERE u.geocodificado = true ORDER BY u.createdAt DESC")
    List<UbicacionReporte> findAllGeocodificados();

    List<UbicacionReporte> findByTipo(String tipo);

    @Query("SELECT u FROM UbicacionReporte u WHERE u.clusterId IS NOT NULL ORDER BY u.clusterId")
    List<UbicacionReporte> findAllWithCluster();
}
