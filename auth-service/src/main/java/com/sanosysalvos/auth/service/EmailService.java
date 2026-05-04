package com.sanosysalvos.auth.service;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.mail.SimpleMailMessage;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.stereotype.Service;

@Service
@RequiredArgsConstructor
@Slf4j
public class EmailService {

    private final JavaMailSender mailSender;

    @Value("${app.frontend-url:http://localhost:3000}")
    private String frontendUrl;

    public void sendVerificationEmail(String to, String token) {
        String verifyUrl = frontendUrl + "/verify-email?token=" + token;
        SimpleMailMessage message = new SimpleMailMessage();
        message.setTo(to);
        message.setFrom("noreply@sanosysalvos.com");
        message.setSubject("Verifica tu cuenta - Sanos y Salvos");
        message.setText("Hola,\n\nPor favor verifica tu cuenta haciendo clic en el siguiente enlace:\n\n"
                + verifyUrl + "\n\nEste enlace expira en 24 horas.\n\nSanos y Salvos");
        try {
            mailSender.send(message);
            log.info("Email de verificación enviado a {}", to);
        } catch (Exception e) {
            log.error("Error enviando email a {}: {}", to, e.getMessage());
        }
    }
}
