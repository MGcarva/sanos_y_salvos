package com.sanosysalvos.coincidencias.listener;

import com.sanosysalvos.coincidencias.config.RabbitMQConfig;
import com.sanosysalvos.coincidencias.domain.Coincidencia;
import com.sanosysalvos.coincidencias.dto.GeoCompletadoEvent;
import com.sanosysalvos.coincidencias.service.CoincidenciaService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.amqp.rabbit.annotation.RabbitListener;
import org.springframework.amqp.rabbit.core.RabbitTemplate;
import org.springframework.stereotype.Component;

import java.util.List;
import java.util.Map;

@Component
@RequiredArgsConstructor
@Slf4j
public class CoincidenciasListener {

    private final CoincidenciaService coincidenciaService;
    private final RabbitTemplate rabbitTemplate;

    @RabbitListener(queues = RabbitMQConfig.COINCIDENCIAS_QUEUE)
    public void handleGeoCompletado(GeoCompletadoEvent event) {
        log.info("Evento GeoCompletado recibido: reporte {} tipo {}", event.getReporteId(), event.getTipo());

        try {
            List<Coincidencia> matches = coincidenciaService.procesarEvento(event);

            for (Coincidencia match : matches) {
                rabbitTemplate.convertAndSend(
                        RabbitMQConfig.EXCHANGE,
                        RabbitMQConfig.NOTIFICATION_ROUTING_KEY,
                        Map.of(
                                "coincidenciaId", match.getId().toString(),
                                "reportePerdidoId", match.getReportePerdidoId().toString(),
                                "reporteEncontradoId", match.getReporteEncontradoId().toString(),
                                "scoreTotal", match.getScoreTotal(),
                                "distanciaKm", match.getDistanciaKm()
                        ));
                match.setNotificado(true);
            }

            log.info("Procesamiento completado para reporte {}: {} coincidencias",
                    event.getReporteId(), matches.size());

        } catch (Exception e) {
            log.error("Error procesando GeoCompletado para reporte {}: {}", event.getReporteId(), e.getMessage(), e);
            throw e;
        }
    }
}
