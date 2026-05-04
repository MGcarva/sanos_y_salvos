package com.sanosysalvos.auth.config;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.util.UUID;

import static org.assertj.core.api.Assertions.*;

class JwtUtilsTest {

    private JwtUtils jwtUtils;
    private static final String TEST_SECRET = "404E635266556A586E3272357538782F413F4428472B4B6250645367566B5970";
    private static final long ACCESS_EXP = 86400000L;
    private static final long REFRESH_EXP = 604800000L;

    @BeforeEach
    void setUp() {
        jwtUtils = new JwtUtils(TEST_SECRET, ACCESS_EXP, REFRESH_EXP);
    }

    @Test
    void generateAccessToken_validToken() {
        UUID userId = UUID.randomUUID();
        String token = jwtUtils.generateAccessToken(userId, "test@example.com", "USER");

        assertThat(token).isNotNull().isNotEmpty();
        assertThat(jwtUtils.isTokenValid(token)).isTrue();
    }

    @Test
    void extractEmail_fromToken() {
        UUID userId = UUID.randomUUID();
        String token = jwtUtils.generateAccessToken(userId, "test@example.com", "USER");

        assertThat(jwtUtils.extractEmail(token)).isEqualTo("test@example.com");
    }

    @Test
    void extractUserId_fromToken() {
        UUID userId = UUID.randomUUID();
        String token = jwtUtils.generateAccessToken(userId, "test@example.com", "USER");

        assertThat(jwtUtils.extractUserId(token)).isEqualTo(userId.toString());
    }

    @Test
    void extractRol_fromToken() {
        UUID userId = UUID.randomUUID();
        String token = jwtUtils.generateAccessToken(userId, "test@example.com", "ADMIN");

        assertThat(jwtUtils.extractRol(token)).isEqualTo("ADMIN");
    }

    @Test
    void isTokenValid_invalidToken_returnsFalse() {
        assertThat(jwtUtils.isTokenValid("invalid.token.here")).isFalse();
    }

    @Test
    void isTokenValid_nullToken_returnsFalse() {
        assertThat(jwtUtils.isTokenValid(null)).isFalse();
    }

    @Test
    void isTokenValid_emptyToken_returnsFalse() {
        assertThat(jwtUtils.isTokenValid("")).isFalse();
    }

    @Test
    void isTokenValid_expiredToken_returnsFalse() {
        JwtUtils shortLived = new JwtUtils(TEST_SECRET, -1000L, REFRESH_EXP);
        UUID userId = UUID.randomUUID();
        String token = shortLived.generateAccessToken(userId, "test@example.com", "USER");

        assertThat(shortLived.isTokenValid(token)).isFalse();
    }

    @Test
    void getAccessExpiration_returnsConfigured() {
        assertThat(jwtUtils.getAccessExpiration()).isEqualTo(ACCESS_EXP);
    }

    @Test
    void generateRefreshToken_validToken() {
        String token = jwtUtils.generateRefreshToken("test@example.com");

        assertThat(token).isNotNull().isNotEmpty();
        assertThat(jwtUtils.isTokenValid(token)).isTrue();
        assertThat(jwtUtils.extractEmail(token)).isEqualTo("test@example.com");
    }

    @Test
    void differentTokensGenerated_notEqual() {
        UUID userId = UUID.randomUUID();
        String token1 = jwtUtils.generateAccessToken(userId, "test@example.com", "USER");
        String token2 = jwtUtils.generateAccessToken(userId, "test@example.com", "USER");

        assertThat(token1).isNotEqualTo(token2);
    }
}
