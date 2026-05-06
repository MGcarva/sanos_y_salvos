package com.sanosysalvos.bff.config;

import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.client.HttpClientErrorException;
import org.springframework.web.client.HttpServerErrorException;

import java.nio.charset.StandardCharsets;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Tests unitarios para GlobalExceptionHandler.
 * Verifica el manejo centralizado de errores HTTP del BFF.
 */
class GlobalExceptionHandlerTest {

    private final GlobalExceptionHandler handler = new GlobalExceptionHandler();

    @Test
    void handleClientError_debeRetornarMismoStatusCode() {
        String body = "{\"message\": \"No autorizado\"}";
        HttpClientErrorException ex = HttpClientErrorException.create(
                HttpStatus.UNAUTHORIZED,
                "Unauthorized",
                null,
                body.getBytes(StandardCharsets.UTF_8),
                StandardCharsets.UTF_8
        );

        ResponseEntity<Map> response = handler.handleClientError(ex);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.UNAUTHORIZED);
        assertThat(response.getBody()).containsEntry("message", "No autorizado");
    }

    @Test
    void handleClientError_cuandoBodyNoEsJson_debeRetornarMensajeRaw() {
        String bodyTexto = "Error de autenticación";
        HttpClientErrorException ex = HttpClientErrorException.create(
                HttpStatus.FORBIDDEN,
                "Forbidden",
                null,
                bodyTexto.getBytes(StandardCharsets.UTF_8),
                StandardCharsets.UTF_8
        );

        ResponseEntity<Map> response = handler.handleClientError(ex);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.FORBIDDEN);
        assertThat(response.getBody()).containsKey("message");
    }

    @Test
    void handleServerError_debeRetornar500CuandoMicroservicioCae() {
        String body = "{\"error\": \"Internal Server Error\"}";
        HttpServerErrorException ex = HttpServerErrorException.create(
                HttpStatus.INTERNAL_SERVER_ERROR,
                "Internal Server Error",
                null,
                body.getBytes(StandardCharsets.UTF_8),
                StandardCharsets.UTF_8
        );

        ResponseEntity<Map> response = handler.handleServerError(ex);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.INTERNAL_SERVER_ERROR);
        assertThat(response.getBody()).containsKey("error");
    }

    @Test
    void handleClientError_cuandoBodyEsNull_debeRetornarMapaConMensaje() {
        HttpClientErrorException ex = HttpClientErrorException.create(
                HttpStatus.NOT_FOUND,
                "Not Found",
                null,
                null,
                StandardCharsets.UTF_8
        );

        ResponseEntity<Map> response = handler.handleClientError(ex);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.NOT_FOUND);
        assertThat(response.getBody()).isNotNull();
    }
}
