package com.athleteos.backend.controller;

import com.athleteos.backend.model.Usuario;
import com.athleteos.backend.repository.UsuarioRepository;
import com.athleteos.backend.service.PlanEngineService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;

/** Onboarding de la app de aprendizaje: una sola pregunta (qué dominios quiere aprender), sin plan de 90 días. */
@RestController
@RequestMapping("/api/v1/onboarding")
@RequiredArgsConstructor
public class OnboardingController {

    private final UsuarioRepository usuarioRepository;
    private final PlanEngineService planEngineService;

    @PostMapping("/completar-aprendizaje")
    public ResponseEntity<?> completarAprendizaje(Authentication authentication) {
        Usuario usuario = usuarioRepository.findByEmail(authentication.getName())
                .orElseThrow(() -> new IllegalStateException("Usuario no encontrado"));
        if (Boolean.TRUE.equals(usuario.getOnboardingCompletado())) {
            return ResponseEntity.ok(Map.of("status", "YA_COMPLETADO"));
        }
        planEngineService.completarOnboardingAprendizaje(usuario.getId());
        return ResponseEntity.ok(Map.of("status", "COMPLETADO"));
    }
}
