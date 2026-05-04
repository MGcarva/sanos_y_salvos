package com.sanosysalvos.auth.service;

import com.sanosysalvos.auth.config.JwtUtils;
import com.sanosysalvos.auth.domain.RefreshToken;
import com.sanosysalvos.auth.domain.User;
import com.sanosysalvos.auth.domain.User.RolUsuario;
import com.sanosysalvos.auth.dto.*;
import com.sanosysalvos.auth.repository.RefreshTokenRepository;
import com.sanosysalvos.auth.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.UUID;

@Service
@RequiredArgsConstructor
@Slf4j
public class AuthService {

    private final UserRepository userRepository;
    private final RefreshTokenRepository refreshTokenRepository;
    private final PasswordEncoder passwordEncoder;
    private final JwtUtils jwtUtils;
    private final EmailService emailService;
    private final RateLimitService rateLimitService;

    @org.springframework.beans.factory.annotation.Value("${app.auto-verify-email:false}")
    private boolean autoVerifyEmail;

    @Transactional
    public AuthResponseDTO register(RegisterRequestDTO request, String clientIp) {
        if (rateLimitService.isRateLimited(clientIp)) {
            throw new RuntimeException("Demasiadas solicitudes. Intente más tarde.");
        }

        if (userRepository.existsByEmail(request.getEmail())) {
            throw new RuntimeException("El email ya está registrado");
        }

        RolUsuario rol = request.getRol() != null ? request.getRol() : RolUsuario.USER;

        String verificationToken = UUID.randomUUID().toString();
        User user = User.builder()
                .nombre(request.getNombre())
                .email(request.getEmail())
                .passwordHash(passwordEncoder.encode(request.getPassword()))
                .rol(rol)
                .verificationToken(verificationToken)
                .verificationTokenExpiry(LocalDateTime.now().plusHours(24))
                .build();

        user = userRepository.save(user);
        log.info("Usuario registrado: {} con rol {}", user.getEmail(), user.getRol());

        if (autoVerifyEmail) {
            user.setEmailVerified(true);
            userRepository.save(user);
            log.info("Auto-verificado email para: {}", user.getEmail());
        } else {
            emailService.sendVerificationEmail(user.getEmail(), verificationToken);
        }

        String accessToken = jwtUtils.generateAccessToken(user.getId(), user.getEmail(), user.getRol().name());
        String refreshToken = createRefreshToken(user);

        return buildAuthResponse(user, accessToken, refreshToken);
    }

    @Transactional
    public AuthResponseDTO login(LoginRequestDTO request, String clientIp) {
        if (rateLimitService.isRateLimited(clientIp)) {
            throw new RuntimeException("Demasiadas solicitudes. Intente más tarde.");
        }

        User user = userRepository.findByEmail(request.getEmail())
                .orElseThrow(() -> new RuntimeException("Credenciales inválidas"));

        if (user.isLocked()) {
            throw new RuntimeException("La cuenta está bloqueada. Contacte al administrador.");
        }

        if (!user.isEmailVerified()) {
            throw new RuntimeException("Debe verificar su email antes de iniciar sesión");
        }

        if (!passwordEncoder.matches(request.getPassword(), user.getPasswordHash())) {
            handleFailedLogin(user);
            throw new RuntimeException("Credenciales inválidas");
        }

        userRepository.resetFailedAttempts(user.getId());
        log.info("Login exitoso: {}", user.getEmail());

        String accessToken = jwtUtils.generateAccessToken(user.getId(), user.getEmail(), user.getRol().name());
        String refreshToken = createRefreshToken(user);

        return buildAuthResponse(user, accessToken, refreshToken);
    }

    @Transactional
    public AuthResponseDTO refreshToken(RefreshTokenRequestDTO request) {
        RefreshToken refreshToken = refreshTokenRepository.findByToken(request.getRefreshToken())
                .orElseThrow(() -> new RuntimeException("Refresh token inválido"));

        if (refreshToken.isExpired()) {
            refreshTokenRepository.delete(refreshToken);
            throw new RuntimeException("Refresh token expirado");
        }

        User user = refreshToken.getUser();
        refreshTokenRepository.delete(refreshToken);

        String newAccessToken = jwtUtils.generateAccessToken(user.getId(), user.getEmail(), user.getRol().name());
        String newRefreshToken = createRefreshToken(user);

        return buildAuthResponse(user, newAccessToken, newRefreshToken);
    }

    @Transactional
    public String verifyEmail(String token) {
        User user = userRepository.findByVerificationToken(token)
                .orElseThrow(() -> new RuntimeException("Token de verificación inválido"));

        if (user.getVerificationTokenExpiry().isBefore(LocalDateTime.now())) {
            throw new RuntimeException("Token de verificación expirado");
        }

        user.setEmailVerified(true);
        user.setVerificationToken(null);
        user.setVerificationTokenExpiry(null);
        userRepository.save(user);

        log.info("Email verificado: {}", user.getEmail());
        return "Email verificado exitosamente";
    }

    private void handleFailedLogin(User user) {
        userRepository.incrementFailedAttempts(user.getId());
        int attempts = user.getFailedAttempts() + 1;
        if (attempts >= 5) {
            userRepository.lockAccount(user.getId());
            log.warn("Cuenta bloqueada por intentos fallidos: {}", user.getEmail());
        }
    }

    private String createRefreshToken(User user) {
        RefreshToken refreshToken = RefreshToken.builder()
                .user(user)
                .token(UUID.randomUUID().toString())
                .expiresAt(LocalDateTime.now().plusDays(7))
                .build();
        return refreshTokenRepository.save(refreshToken).getToken();
    }

    private AuthResponseDTO buildAuthResponse(User user, String accessToken, String refreshToken) {
        return AuthResponseDTO.builder()
                .accessToken(accessToken)
                .refreshToken(refreshToken)
                .expiresIn(jwtUtils.getAccessExpiration())
                .userId(user.getId())
                .nombre(user.getNombre())
                .email(user.getEmail())
                .rol(user.getRol())
                .build();
    }
}
