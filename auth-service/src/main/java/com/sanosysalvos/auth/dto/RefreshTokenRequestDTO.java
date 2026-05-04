package com.sanosysalvos.auth.dto;

import lombok.*;

@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class RefreshTokenRequestDTO {

    private String refreshToken;
}
