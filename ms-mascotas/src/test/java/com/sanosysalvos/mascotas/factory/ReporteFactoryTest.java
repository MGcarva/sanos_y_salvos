package com.sanosysalvos.mascotas.factory;

import com.sanosysalvos.mascotas.domain.*;
import com.sanosysalvos.mascotas.domain.Reporte.Tamano;
import com.sanosysalvos.mascotas.dto.ReporteRequestDTO;
import org.junit.jupiter.api.Test;

import java.math.BigDecimal;
import java.util.UUID;

import static org.assertj.core.api.Assertions.*;

class ReporteFactoryTest {

    private final ReporteFactory factory = new ReporteFactory();

    @Test
    void crear_perdido_returnsReportePerdido() {
        UUID userId = UUID.randomUUID();
        ReporteRequestDTO dto = ReporteRequestDTO.builder()
                .tipo("PERDIDO")
                .especie("Perro")
                .raza("Husky")
                .nombre("Luna")
                .color("Blanco y negro")
                .tamano(Tamano.GRANDE)
                .descripcion("Husky perdido en parque")
                .lat(4.711)
                .lng(-74.072)
                .direccion("Calle 123")
                .recompensa(BigDecimal.valueOf(200000))
                .build();

        Reporte result = factory.crear(dto, userId);

        assertThat(result).isInstanceOf(ReportePerdido.class);
        assertThat(result.getUserId()).isEqualTo(userId);
        assertThat(result.getEspecie()).isEqualTo("Perro");
        assertThat(result.getRaza()).isEqualTo("Husky");
        assertThat(result.getTipo()).isEqualTo("PERDIDO");
        assertThat(((ReportePerdido) result).getRecompensa()).isEqualTo(BigDecimal.valueOf(200000));
    }

    @Test
    void crear_encontrado_returnsReporteEncontrado() {
        UUID userId = UUID.randomUUID();
        ReporteRequestDTO dto = ReporteRequestDTO.builder()
                .tipo("ENCONTRADO")
                .especie("Gato")
                .raza("Siamés")
                .color("Crema")
                .tamano(Tamano.PEQUENO)
                .descripcion("Gato encontrado en calle")
                .lugarResguardo("Mi casa")
                .tieneCollar(true)
                .build();

        Reporte result = factory.crear(dto, userId);

        assertThat(result).isInstanceOf(ReporteEncontrado.class);
        assertThat(result.getTipo()).isEqualTo("ENCONTRADO");
        assertThat(((ReporteEncontrado) result).getLugarResguardo()).isEqualTo("Mi casa");
        assertThat(((ReporteEncontrado) result).isTieneCollar()).isTrue();
    }

    @Test
    void crear_invalidTipo_throwsException() {
        ReporteRequestDTO dto = ReporteRequestDTO.builder()
                .tipo("INVALIDO")
                .especie("Perro")
                .descripcion("Test")
                .build();

        assertThatThrownBy(() -> factory.crear(dto, UUID.randomUUID()))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("inválido");
    }

    @Test
    void crear_perdido_caseInsensitive() {
        ReporteRequestDTO dto = ReporteRequestDTO.builder()
                .tipo("perdido")
                .especie("Perro")
                .descripcion("Test")
                .build();

        Reporte result = factory.crear(dto, UUID.randomUUID());

        assertThat(result).isInstanceOf(ReportePerdido.class);
    }
}
