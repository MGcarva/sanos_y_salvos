package com.sanosysalvos.mascotas.service;

import com.sanosysalvos.mascotas.domain.*;
import com.sanosysalvos.mascotas.domain.Reporte.EstadoReporte;
import com.sanosysalvos.mascotas.domain.Reporte.Tamano;
import com.sanosysalvos.mascotas.dto.*;
import com.sanosysalvos.mascotas.factory.ReporteFactory;
import com.sanosysalvos.mascotas.repository.ReporteRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.web.multipart.MultipartFile;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class ReporteServiceTest {

    @Mock private ReporteRepository reporteRepository;
    @Mock private ReporteFactory reporteFactory;
    @Mock private MinioService minioService;
    @Mock private EventPublisher eventPublisher;

    @InjectMocks
    private ReporteService reporteService;

    private UUID userId;
    private ReportePerdido testReporte;

    @BeforeEach
    void setUp() {
        userId = UUID.randomUUID();
        testReporte = new ReportePerdido();
        testReporte.setId(UUID.randomUUID());
        testReporte.setUserId(userId);
        testReporte.setEspecie("Perro");
        testReporte.setRaza("Labrador");
        testReporte.setNombre("Max");
        testReporte.setColor("Dorado");
        testReporte.setTamano(Tamano.GRANDE);
        testReporte.setDescripcion("Perro labrador dorado perdido");
        testReporte.setEstado(EstadoReporte.ACTIVO);
        testReporte.setLat(4.711);
        testReporte.setLng(-74.072);
        testReporte.setRecompensa(BigDecimal.valueOf(50000));
        testReporte.setCreatedAt(LocalDateTime.now());
    }

    @Test
    void crearReporte_sinFoto_success() {
        ReporteRequestDTO dto = ReporteRequestDTO.builder()
                .tipo("PERDIDO")
                .especie("Perro")
                .raza("Labrador")
                .nombre("Max")
                .color("Dorado")
                .tamano(Tamano.GRANDE)
                .descripcion("Perro perdido")
                .lat(4.711)
                .lng(-74.072)
                .build();

        when(reporteFactory.crear(dto, userId)).thenReturn(testReporte);
        when(reporteRepository.save(any(Reporte.class))).thenReturn(testReporte);

        ReporteResponseDTO response = reporteService.crearReporte(dto, null, userId);

        assertThat(response).isNotNull();
        assertThat(response.getEspecie()).isEqualTo("Perro");
        assertThat(response.getTipo()).isEqualTo("PERDIDO");
        verify(eventPublisher).publishReporteNuevo(testReporte);
        verify(minioService, never()).uploadImage(any(), any());
    }

    @Test
    void crearReporte_conFoto_success() {
        ReporteRequestDTO dto = ReporteRequestDTO.builder()
                .tipo("PERDIDO")
                .especie("Gato")
                .descripcion("Gato perdido")
                .build();

        MultipartFile mockFile = mock(MultipartFile.class);
        when(mockFile.isEmpty()).thenReturn(false);

        when(reporteFactory.crear(dto, userId)).thenReturn(testReporte);
        when(reporteRepository.save(any(Reporte.class))).thenReturn(testReporte);
        when(minioService.uploadImage(mockFile, testReporte.getId())).thenReturn("http://minio:9000/mascotas-fotos/foto.jpg");

        ReporteResponseDTO response = reporteService.crearReporte(dto, mockFile, userId);

        assertThat(response).isNotNull();
        verify(minioService).uploadImage(mockFile, testReporte.getId());
        verify(reporteRepository, times(2)).save(any(Reporte.class));
    }

    @Test
    void listarActivos_returnsActiveReportes() {
        when(reporteRepository.findAllActivos()).thenReturn(List.of(testReporte));

        List<ReporteResponseDTO> result = reporteService.listarActivos();

        assertThat(result).hasSize(1);
        assertThat(result.get(0).getEspecie()).isEqualTo("Perro");
    }

    @Test
    void listarActivos_empty() {
        when(reporteRepository.findAllActivos()).thenReturn(List.of());

        List<ReporteResponseDTO> result = reporteService.listarActivos();

        assertThat(result).isEmpty();
    }

    @Test
    void obtenerPorId_found() {
        when(reporteRepository.findById(testReporte.getId())).thenReturn(Optional.of(testReporte));

        ReporteResponseDTO result = reporteService.obtenerPorId(testReporte.getId());

        assertThat(result.getId()).isEqualTo(testReporte.getId());
    }

    @Test
    void obtenerPorId_notFound_throwsException() {
        UUID randomId = UUID.randomUUID();
        when(reporteRepository.findById(randomId)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> reporteService.obtenerPorId(randomId))
                .isInstanceOf(RuntimeException.class)
                .hasMessageContaining("Reporte no encontrado");
    }

    @Test
    void listarPorUsuario_returnsUserReportes() {
        when(reporteRepository.findByUserId(userId)).thenReturn(List.of(testReporte));

        List<ReporteResponseDTO> result = reporteService.listarPorUsuario(userId);

        assertThat(result).hasSize(1);
        assertThat(result.get(0).getUserId()).isEqualTo(userId);
    }

    @Test
    void actualizarEstado_success() {
        when(reporteRepository.findById(testReporte.getId())).thenReturn(Optional.of(testReporte));
        when(reporteRepository.save(any(Reporte.class))).thenReturn(testReporte);

        ReporteResponseDTO result = reporteService.actualizarEstado(testReporte.getId(), EstadoReporte.RESUELTO);

        assertThat(result).isNotNull();
        verify(reporteRepository).save(testReporte);
    }

    @Test
    void crearReporte_perdido_includesRecompensa() {
        ReporteRequestDTO dto = ReporteRequestDTO.builder()
                .tipo("PERDIDO")
                .especie("Perro")
                .descripcion("Perro perdido")
                .recompensa(BigDecimal.valueOf(100000))
                .build();

        when(reporteFactory.crear(dto, userId)).thenReturn(testReporte);
        when(reporteRepository.save(any(Reporte.class))).thenReturn(testReporte);

        ReporteResponseDTO response = reporteService.crearReporte(dto, null, userId);

        assertThat(response.getRecompensa()).isEqualTo(BigDecimal.valueOf(50000));
    }
}
