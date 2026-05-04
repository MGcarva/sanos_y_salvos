package com.sanosysalvos.auth.controller;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.sanosysalvos.auth.domain.User.RolUsuario;
import com.sanosysalvos.auth.dto.*;
import com.sanosysalvos.auth.service.AuthService;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.mock.bean.MockBean;
import org.springframework.http.MediaType;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;

import java.util.UUID;

import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
class AuthControllerTest {

    @Autowired private MockMvc mockMvc;
    @Autowired private ObjectMapper objectMapper;
    @MockBean private AuthService authService;

    @Test
    void register_validRequest_returns201() throws Exception {
        RegisterRequestDTO request = RegisterRequestDTO.builder()
                .nombre("Test User")
                .email("test@example.com")
                .password("password123")
                .rol(RolUsuario.USER)
                .build();

        AuthResponseDTO response = AuthResponseDTO.builder()
                .accessToken("access-token")
                .refreshToken("refresh-token")
                .expiresIn(86400000L)
                .userId(UUID.randomUUID())
                .nombre("Test User")
                .email("test@example.com")
                .rol(RolUsuario.USER)
                .build();

        when(authService.register(any(), anyString())).thenReturn(response);

        mockMvc.perform(post("/api/auth/register")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.accessToken").value("access-token"))
                .andExpect(jsonPath("$.nombre").value("Test User"));
    }

    @Test
    void register_missingEmail_returns400() throws Exception {
        RegisterRequestDTO request = RegisterRequestDTO.builder()
                .nombre("Test User")
                .password("password123")
                .build();

        mockMvc.perform(post("/api/auth/register")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isBadRequest());
    }

    @Test
    void register_invalidEmail_returns400() throws Exception {
        RegisterRequestDTO request = RegisterRequestDTO.builder()
                .nombre("Test User")
                .email("not-an-email")
                .password("password123")
                .build();

        mockMvc.perform(post("/api/auth/register")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isBadRequest());
    }

    @Test
    void login_validRequest_returns200() throws Exception {
        LoginRequestDTO request = LoginRequestDTO.builder()
                .email("test@example.com")
                .password("password123")
                .build();

        AuthResponseDTO response = AuthResponseDTO.builder()
                .accessToken("access-token")
                .refreshToken("refresh-token")
                .expiresIn(86400000L)
                .userId(UUID.randomUUID())
                .nombre("Test User")
                .email("test@example.com")
                .rol(RolUsuario.USER)
                .build();

        when(authService.login(any(), anyString())).thenReturn(response);

        mockMvc.perform(post("/api/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.accessToken").value("access-token"));
    }

    @Test
    void login_missingPassword_returns400() throws Exception {
        LoginRequestDTO request = LoginRequestDTO.builder()
                .email("test@example.com")
                .build();

        mockMvc.perform(post("/api/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isBadRequest());
    }

    @Test
    void refresh_validRequest_returns200() throws Exception {
        RefreshTokenRequestDTO request = RefreshTokenRequestDTO.builder()
                .refreshToken("valid-token")
                .build();

        AuthResponseDTO response = AuthResponseDTO.builder()
                .accessToken("new-access-token")
                .refreshToken("new-refresh-token")
                .expiresIn(86400000L)
                .userId(UUID.randomUUID())
                .nombre("Test User")
                .email("test@example.com")
                .rol(RolUsuario.USER)
                .build();

        when(authService.refreshToken(any())).thenReturn(response);

        mockMvc.perform(post("/api/auth/refresh")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.accessToken").value("new-access-token"));
    }

    @Test
    void verifyEmail_validToken_returns200() throws Exception {
        when(authService.verifyEmail("valid-token")).thenReturn("Email verificado exitosamente");

        mockMvc.perform(get("/api/auth/verify-email").param("token", "valid-token"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.message").value("Email verificado exitosamente"));
    }
}
