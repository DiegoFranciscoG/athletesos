package com.athleteos.backend.controller;

import com.athleteos.backend.model.Usuario;
import com.athleteos.backend.repository.UsuarioRepository;
import com.athleteos.backend.service.PlanEngineService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;

/** Racha de hábitos para la tarjeta de Inicio — el resto de la app de aprendizaje no usa día/fase/nivel de plan. */
@RestController
@RequestMapping("/api/v1/progress")
@RequiredArgsConstructor
public class ProgressController {

    private final UsuarioRepository usuarioRepository;
    private final PlanEngineService planEngineService;

    @GetMapping("/resumen")
    public ResponseEntity<?> resumen(Authentication authentication) {
        Usuario usuario = usuarioRepository.findByEmail(authentication.getName())
                .orElseThrow(() -> new IllegalStateException("Usuario no encontrado"));

        if (!Boolean.TRUE.equals(usuario.getOnboardingCompletado())) {
            return ResponseEntity.ok(Map.of("hasActivePlan", false));
        }

        return ResponseEntity.ok(Map.of(
                "hasActivePlan", true,
                "rachas", planEngineService.getRachas(usuario.getId())
        ));
    }
}
