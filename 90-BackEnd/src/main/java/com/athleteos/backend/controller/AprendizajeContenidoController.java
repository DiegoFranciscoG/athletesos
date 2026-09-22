package com.athleteos.backend.controller;

import com.athleteos.backend.model.Usuario;
import com.athleteos.backend.repository.UsuarioRepository;
import com.athleteos.backend.service.ContenidoAprendizajeService;
import lombok.Data;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

/** Vocabulario y trivia — contenido que nunca se repite para un mismo usuario (ver V27). */
@RestController
@RequestMapping("/api/v1/aprendizaje")
@RequiredArgsConstructor
public class AprendizajeContenidoController {

    private final UsuarioRepository usuarioRepository;
    private final ContenidoAprendizajeService contenidoService;

    @GetMapping("/palabra-nueva")
    public ResponseEntity<?> palabraNueva(Authentication authentication) {
        Usuario usuario = requireUsuario(authentication);
        Map<String, Object> palabra = contenidoService.siguientePalabra(usuario.getId());
        if (palabra == null) {
            return ResponseEntity.ok(Map.of("agotado", true));
        }
        return ResponseEntity.ok(palabra);
    }

    @GetMapping("/trivia-nueva")
    public ResponseEntity<?> triviaNueva(Authentication authentication) {
        Usuario usuario = requireUsuario(authentication);
        Map<String, Object> trivia = contenidoService.siguienteTrivia(usuario.getId());
        if (trivia == null) {
            return ResponseEntity.ok(Map.of("agotado", true));
        }
        return ResponseEntity.ok(trivia);
    }

    @PostMapping("/trivia/{id}/responder")
    public ResponseEntity<?> responderTrivia(@PathVariable int id, @RequestBody ResponderTriviaRequest request) {
        Map<String, Object> resultado = contenidoService.responderTrivia(id, request.getOpcionElegida());
        if (resultado == null) {
            return ResponseEntity.status(404).body(Map.of("error", "Pregunta no encontrada"));
        }
        return ResponseEntity.ok(resultado);
    }

    private Usuario requireUsuario(Authentication authentication) {
        return usuarioRepository.findByEmail(authentication.getName())
                .orElseThrow(() -> new IllegalStateException("Usuario no encontrado"));
    }

    @Data
    static class ResponderTriviaRequest {
        private int opcionElegida;
    }
}
