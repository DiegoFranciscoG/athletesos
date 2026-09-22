package com.athleteos.backend.controller;

import com.athleteos.backend.model.Usuario;
import com.athleteos.backend.repository.UsuarioRepository;
import com.athleteos.backend.service.RutaAprendizajeService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;

/** Rutas de aprendizaje: temas/subtemas bloqueados hasta completar el anterior, de fácil a difícil. */
@RestController
@RequestMapping("/api/v1/rutas")
@RequiredArgsConstructor
public class RutaAprendizajeController {

    private static final Set<String> DOMINIOS_VALIDOS = Set.of("CALISTENIA", "AJEDREZ", "BOXEO", "KARATE", "CONOCIMIENTO");

    @GetMapping("/ajedrez/puzzles")
    public ResponseEntity<?> puzzlesAjedrez() {
        return ResponseEntity.ok(Map.of("puzzles", rutaAprendizajeService.getPuzzlesAjedrez()));
    }

    private final UsuarioRepository usuarioRepository;
    private final RutaAprendizajeService rutaAprendizajeService;

    @GetMapping("/{dominio}")
    public ResponseEntity<?> ruta(Authentication authentication, @PathVariable String dominio) {
        String dominioNorm = dominio.toUpperCase();
        if (!DOMINIOS_VALIDOS.contains(dominioNorm)) {
            return ResponseEntity.badRequest().body(Map.of("error", "Dominio no reconocido: " + dominio));
        }
        Usuario usuario = requireUsuario(authentication);
        List<Map<String, Object>> temas = rutaAprendizajeService.getRuta(usuario.getId(), dominioNorm);
        return ResponseEntity.ok(Map.of("dominio", dominioNorm, "temas", temas));
    }

    @PostMapping("/temas/{temaId}/completar")
    public ResponseEntity<?> completar(Authentication authentication, @PathVariable UUID temaId) {
        Usuario usuario = requireUsuario(authentication);
        try {
            String resultado = rutaAprendizajeService.completarTema(usuario.getId(), temaId);
            return ResponseEntity.ok(Map.of("resultado", resultado));
        } catch (Exception e) {
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage() != null ? e.getMessage() : "No se pudo completar el tema"));
        }
    }

    private Usuario requireUsuario(Authentication authentication) {
        return usuarioRepository.findByEmail(authentication.getName())
                .orElseThrow(() -> new IllegalStateException("Usuario no encontrado"));
    }
}
