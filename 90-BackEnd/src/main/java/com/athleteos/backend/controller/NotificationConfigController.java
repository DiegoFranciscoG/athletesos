package com.athleteos.backend.controller;

import com.athleteos.backend.model.Usuario;
import com.athleteos.backend.repository.UsuarioRepository;
import com.athleteos.backend.service.NotificationConfigService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

import java.util.Map;
import java.util.Set;

/**
 * Configuración de recordatorios (agua, pre-entreno, desconexión). Los
 * horarios exactos de disparo los calcula y programa el propio teléfono con
 * flutter_local_notifications — este endpoint solo persiste las preferencias
 * del usuario (activa/hora/intervalo), igual que cualquier otro ajuste.
 */
@RestController
@RequestMapping("/api/v1/notificaciones")
@RequiredArgsConstructor
public class NotificationConfigController {

    private static final Set<String> CATEGORIAS_VALIDAS = Set.of("AGUA", "PRE_ENTRENO", "DESCONEXION");

    private final UsuarioRepository usuarioRepository;
    private final NotificationConfigService notificationConfigService;

    @GetMapping("/configuracion")
    public ResponseEntity<?> getConfiguracion(Authentication authentication) {
        Usuario usuario = requireUsuario(authentication);
        return ResponseEntity.ok(Map.of("configuracion", notificationConfigService.getConfiguracion(usuario.getId())));
    }

    @PutMapping("/configuracion/{categoria}")
    public ResponseEntity<?> actualizar(Authentication authentication, @PathVariable String categoria,
                                         @RequestBody Map<String, Object> campos) {
        if (!CATEGORIAS_VALIDAS.contains(categoria)) {
            return ResponseEntity.badRequest().body(Map.of("error", "Categoría inválida"));
        }
        Usuario usuario = requireUsuario(authentication);
        int actualizado = notificationConfigService.actualizar(usuario.getId(), categoria, campos);
        if (actualizado == 0) {
            return ResponseEntity.status(404).body(Map.of("error", "Configuración no encontrada"));
        }
        return ResponseEntity.ok(Map.of("configuracion", notificationConfigService.getConfiguracion(usuario.getId())));
    }

    private Usuario requireUsuario(Authentication authentication) {
        return usuarioRepository.findByEmail(authentication.getName())
                .orElseThrow(() -> new IllegalStateException("Usuario no encontrado"));
    }
}
