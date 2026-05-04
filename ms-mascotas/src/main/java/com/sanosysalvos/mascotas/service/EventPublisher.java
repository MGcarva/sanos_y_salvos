package com.sanosysalvos.mascotas.service;

import com.sanosysalvos.mascotas.config.RabbitMQConfig;
import com.sanosysalvos.mascotas.domain.Reporte;
import com.sanosysalvos.mascotas.events.ReporteNuevoEvent;
import io.github.resilience4j.circuitbreaker.annotation.CircuitBreaker;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.amqp.rabbit.core.RabbitTemplate;
import org.springframework.stereotype.Service;

@Service
@RequiredArgsConstructor
@Slf4j
public class EventPublisher {

    private final RabbitTemplate rabbitTemplate;

    @CircuitBreaker(name = "rabbitmq", fallbackMethod = "publishFallback")
    public void publishReporteNuevo(Reporte reporte) {
        ReporteNuevoEvent event = ReporteNuevoEvent.builder()
                .reporteId(reporte.getId())
                .userId(reporte.getUserId())
                .tipo(reporte.getTipo())
                .especie(reporte.getEspecie())
                .raza(reporte.getRaza())
                .color(reporte.getColor())
                .tamano(reporte.getTamano() != null ? reporte.getTamano().name() : null)
                .fotoUrl(reporte.getFotoUrl())
                .lat(reporte.getLat())
                .lng(reporte.getLng())
                .direccion(reporte.getDireccion())
                .build();

        rabbitTemplate.convertAndSend(
                RabbitMQConfig.EXCHANGE,
                RabbitMQConfig.GEO_ROUTING_KEY,
                event);

        log.info("Evento publicado para reporte {}", reporte.getId());
    }

    private void publishFallback(Reporte reporte, Throwable t) {
        log.error("CircuitBreaker: fallo publicando evento para reporte {}. Error: {}",
                reporte.getId(), t.getMessage());
    }
}
