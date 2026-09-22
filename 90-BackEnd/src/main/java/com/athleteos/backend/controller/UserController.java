package com.athleteos.backend.controller;

import com.athleteos.backend.model.PerfilPersonal;
import com.athleteos.backend.model.Usuario;
import com.athleteos.backend.repository.PerfilPersonalRepository;
import com.athleteos.backend.repository.UsuarioRepository;
import lombok.Data;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/users")
@RequiredArgsConstructor
public class UserController {

    private final UsuarioRepository usuarioRepository;
    private final PerfilPersonalRepository perfilRepository;

    @GetMapping("/me")
    public ResponseEntity<?> getCurrentUser(Authentication authentication) {
        String email = authentication.getName();
        Usuario usuario = usuarioRepository.findByEmail(email).orElse(null);
        if (usuario == null) return ResponseEntity.notFound().build();

        PerfilPersonal perfil = perfilRepository.findByUsuario(usuario).orElse(null);

        MeResponse response = new MeResponse();
        response.setNombre(perfil != null ? perfil.getNombre() : "Atleta");
        response.setAvatarUrl(perfil != null ? perfil.getAvatarUrl() : null);
        response.setObjetivoPrincipal(perfil != null ? perfil.getObjetivoPrincipal() : null);
        response.setRol(usuario.getRol());
        response.setNivelHabilidad(usuario.getNivelHabilidad());
        response.setIntensidad(usuario.getIntensidad());
        response.setOnboardingCompletado(Boolean.TRUE.equals(usuario.getOnboardingCompletado()));
        return ResponseEntity.ok(response);
    }

    @Data
    static class MeResponse {
        private String nombre;
        private String avatarUrl;
        private String objetivoPrincipal;
        private String rol;
        private String nivelHabilidad;
        private String intensidad;
        private boolean onboardingCompletado;
    }
}
