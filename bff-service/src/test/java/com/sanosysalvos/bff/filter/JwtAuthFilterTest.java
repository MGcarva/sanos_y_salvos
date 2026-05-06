package com.sanosysalvos.bff.filter;

import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;
import jakarta.servlet.FilterChain;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.security.core.context.SecurityContextHolder;

import java.util.Date;
import java.util.HexFormat;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.*;

/**
 * Tests unitarios para JwtAuthFilter.
 * Verifica que el filtro establece el contexto de seguridad correctamente
 * con tokens válidos y rechaza tokens inválidos o ausentes.
 */
@ExtendWith(MockitoExtension.class)
class JwtAuthFilterTest {

    private static final String HEX_SECRET =
            "a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2";

    @Mock
    private HttpServletRequest request;

    @Mock
    private HttpServletResponse response;

    @Mock
    private FilterChain filterChain;

    private JwtAuthFilter jwtAuthFilter;

    @BeforeEach
    void setUp() {
        SecurityContextHolder.clearContext();
        jwtAuthFilter = new JwtAuthFilter(HEX_SECRET);
    }

    @Test
    void filtro_sinHeader_debeContinuarSinAutenticacion() throws Exception {
        when(request.getHeader("Authorization")).thenReturn(null);

        jwtAuthFilter.doFilterInternal(request, response, filterChain);

        verify(filterChain, times(1)).doFilter(request, response);
        assertThat(SecurityContextHolder.getContext().getAuthentication()).isNull();
    }

    @Test
    void filtro_conTokenValido_debeEstablecerAutenticacion() throws Exception {
        String token = generarTokenValido("user-uuid-123", "USER");
        when(request.getHeader("Authorization")).thenReturn("Bearer " + token);

        jwtAuthFilter.doFilterInternal(request, response, filterChain);

        verify(filterChain, times(1)).doFilter(request, response);
        assertThat(SecurityContextHolder.getContext().getAuthentication()).isNotNull();
        assertThat(SecurityContextHolder.getContext().getAuthentication().getPrincipal())
                .isEqualTo("user-uuid-123");
    }

    @Test
    void filtro_conTokenInvalido_debeIgnorarYContinuar() throws Exception {
        when(request.getHeader("Authorization")).thenReturn("Bearer token-invalido-xyz");

        jwtAuthFilter.doFilterInternal(request, response, filterChain);

        verify(filterChain, times(1)).doFilter(request, response);
        assertThat(SecurityContextHolder.getContext().getAuthentication()).isNull();
    }

    @Test
    void filtro_conHeaderSinBearer_debeContinuarSinAutenticacion() throws Exception {
        when(request.getHeader("Authorization")).thenReturn("Basic dXNlcjpwYXNz");

        jwtAuthFilter.doFilterInternal(request, response, filterChain);

        verify(filterChain, times(1)).doFilter(request, response);
        assertThat(SecurityContextHolder.getContext().getAuthentication()).isNull();
    }

    @Test
    void filtro_conTokenExpirado_debeIgnorarYContinuar() throws Exception {
        String tokenExpirado = generarTokenExpirado("user-uuid-456");
        when(request.getHeader("Authorization")).thenReturn("Bearer " + tokenExpirado);

        jwtAuthFilter.doFilterInternal(request, response, filterChain);

        verify(filterChain, times(1)).doFilter(request, response);
        assertThat(SecurityContextHolder.getContext().getAuthentication()).isNull();
    }

    private String generarTokenValido(String userId, String rol) {
        var key = Keys.hmacShaKeyFor(HexFormat.of().parseHex(HEX_SECRET));
        return Jwts.builder()
                .subject(userId)
                .claim("rol", rol)
                .claim("userId", userId)
                .issuedAt(new Date())
                .expiration(new Date(System.currentTimeMillis() + 3600_000))
                .signWith(key)
                .compact();
    }

    private String generarTokenExpirado(String userId) {
        var key = Keys.hmacShaKeyFor(HexFormat.of().parseHex(HEX_SECRET));
        return Jwts.builder()
                .subject(userId)
                .claim("rol", "USER")
                .issuedAt(new Date(System.currentTimeMillis() - 7200_000))
                .expiration(new Date(System.currentTimeMillis() - 3600_000))
                .signWith(key)
                .compact();
    }
}
