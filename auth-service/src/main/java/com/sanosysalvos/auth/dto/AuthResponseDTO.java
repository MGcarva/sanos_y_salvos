package com.sanosysalvos.auth.dto;

import com.sanosysalvos.auth.domain.User.RolUsuario;
import lombok.*;

import java.util.UUID;

@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class AuthResponseDTO {

    private String accessToken;
    private String refreshToken;
    @Builder.Default
    private String tokenType = "Bearer";
    private long expiresIn;
    private UUID userId;
    private String nombre;
    private String email;
    private RolUsuario rol;
}
