package com.sanosysalvos.bff.controller;

import com.sanosysalvos.bff.service.AuthProxyService;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@RestController
@RequestMapping("/api/auth")
@RequiredArgsConstructor
@Tag(name = "Auth (BFF)", description = "Proxy de autenticación")
public class AuthController {

    private final AuthProxyService authProxy;

    @PostMapping("/register")
    public ResponseEntity<Map> register(@RequestBody Map<String, Object> body) {
        return authProxy.register(body);
    }

    @PostMapping("/login")
    public ResponseEntity<Map> login(@RequestBody Map<String, Object> body) {
        return authProxy.login(body);
    }

    @PostMapping("/refresh")
    public ResponseEntity<Map> refresh(@RequestBody Map<String, Object> body) {
        return authProxy.refresh(body);
    }

    @GetMapping("/verify-email")
    public ResponseEntity<Map> verifyEmail(@RequestParam String token) {
        return authProxy.verifyEmail(token);
    }
}
