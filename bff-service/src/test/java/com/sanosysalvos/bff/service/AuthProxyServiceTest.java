package com.sanosysalvos.bff.service;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.test.util.ReflectionTestUtils;
import org.springframework.web.client.HttpClientErrorException;
import org.springframework.web.client.RestTemplate;

import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

/**
 * Tests unitarios para AuthProxyService.
 * Verifica el patrón Proxy: el BFF delega correctamente a auth-service.
 */
@ExtendWith(MockitoExtension.class)
class AuthProxyServiceTest {

    @Mock
    private RestTemplate restTemplate;

    @InjectMocks
    private AuthProxyService authProxyService;

    private static final String AUTH_URL = "http://auth-service:8081";

    @BeforeEach
    void setUp() {
        ReflectionTestUtils.setField(authProxyService, "authUrl", AUTH_URL);
    }

    @Test
    void login_debeRetornarTokenCuandoCredencialesCorrectas() {
        Map<String, Object> credenciales = Map.of("email", "user@test.com", "password", "pass123");
        Map<String, String> tokenResponse = Map.of("accessToken", "jwt-token-123", "refreshToken", "refresh-456");

        when(restTemplate.postForEntity(
                eq(AUTH_URL + "/api/auth/login"),
                eq(credenciales),
                eq(Map.class)
        )).thenReturn(ResponseEntity.ok(tokenResponse));

        ResponseEntity<Map> result = authProxyService.login(credenciales);

        assertThat(result.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(result.getBody()).containsKey("accessToken");
        assertThat(result.getBody().get("accessToken")).isEqualTo("jwt-token-123");
        verify(restTemplate, times(1)).postForEntity(anyString(), any(), eq(Map.class));
    }

    @Test
    void login_debePropagarErrorCuandoCredencialesInvalidas() {
        Map<String, Object> credenciales = Map.of("email", "user@test.com", "password", "wrong");

        when(restTemplate.postForEntity(
                eq(AUTH_URL + "/api/auth/login"),
                eq(credenciales),
                eq(Map.class)
        )).thenThrow(new HttpClientErrorException(HttpStatus.UNAUTHORIZED));

        assertThatThrownBy(() -> authProxyService.login(credenciales))
                .isInstanceOf(HttpClientErrorException.class)
                .extracting(e -> ((HttpClientErrorException) e).getStatusCode())
                .isEqualTo(HttpStatus.UNAUTHORIZED);
    }

    @Test
    void register_debeLlamarEndpointCorrecto() {
        Map<String, Object> body = Map.of("email", "nuevo@test.com", "password", "secure123", "nombre", "Juan");
        Map<String, Object> respuesta = Map.of("id", "uuid-123", "email", "nuevo@test.com");

        when(restTemplate.postForEntity(
                eq(AUTH_URL + "/api/auth/register"),
                eq(body),
                eq(Map.class)
        )).thenReturn(ResponseEntity.status(HttpStatus.CREATED).body(respuesta));

        ResponseEntity<Map> result = authProxyService.register(body);

        assertThat(result.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        assertThat(result.getBody()).containsEntry("email", "nuevo@test.com");
    }

    @Test
    void refresh_debeRenovarTokenCorrectamente() {
        Map<String, Object> body = Map.of("refreshToken", "refresh-token-viejo");
        Map<String, String> nuevoToken = Map.of("accessToken", "nuevo-jwt-token");

        when(restTemplate.postForEntity(
                eq(AUTH_URL + "/api/auth/refresh"),
                eq(body),
                eq(Map.class)
        )).thenReturn(ResponseEntity.ok(nuevoToken));

        ResponseEntity<Map> result = authProxyService.refresh(body);

        assertThat(result.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(result.getBody()).containsKey("accessToken");
    }

    @Test
    void verifyEmail_debeLlamarEndpointGetConToken() {
        String token = "verification-token-abc";
        Map<String, String> respuesta = Map.of("message", "Email verificado correctamente");

        when(restTemplate.getForEntity(
                eq(AUTH_URL + "/api/auth/verify-email?token=" + token),
                eq(Map.class)
        )).thenReturn(ResponseEntity.ok(respuesta));

        ResponseEntity<Map> result = authProxyService.verifyEmail(token);

        assertThat(result.getStatusCode()).isEqualTo(HttpStatus.OK);
        assertThat(result.getBody()).containsKey("message");
        verify(restTemplate, times(1)).getForEntity(anyString(), eq(Map.class));
    }
}
