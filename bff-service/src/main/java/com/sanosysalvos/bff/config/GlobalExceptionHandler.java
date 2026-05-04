package com.sanosysalvos.bff.config;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.ControllerAdvice;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.client.HttpClientErrorException;
import org.springframework.web.client.HttpServerErrorException;

import java.util.Map;

@ControllerAdvice
public class GlobalExceptionHandler {

    private final ObjectMapper objectMapper = new ObjectMapper();

    @ExceptionHandler(HttpClientErrorException.class)
    public ResponseEntity<Map> handleClientError(HttpClientErrorException ex) {
        Map body = parseBody(ex.getResponseBodyAsString());
        return ResponseEntity.status(ex.getStatusCode()).body(body);
    }

    @ExceptionHandler(HttpServerErrorException.class)
    public ResponseEntity<Map> handleServerError(HttpServerErrorException ex) {
        Map body = parseBody(ex.getResponseBodyAsString());
        return ResponseEntity.status(ex.getStatusCode()).body(body);
    }

    @SuppressWarnings("unchecked")
    private Map parseBody(String responseBody) {
        try {
            return objectMapper.readValue(responseBody, Map.class);
        } catch (Exception e) {
            return Map.of("message", responseBody != null ? responseBody : "Error interno");
        }
    }
}
