package com.athleteos.backend.controller;

import com.athleteos.backend.model.Habito;
import com.athleteos.backend.model.RegistroHabito;
import com.athleteos.backend.model.Usuario;
import com.athleteos.backend.repository.HabitoRepository;
import com.athleteos.backend.repository.RegistroHabitoRepository;
import com.athleteos.backend.repository.UsuarioRepository;
import lombok.Data;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDate;
import java.util.List;
import java.util.Map;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/habits")
@RequiredArgsConstructor
public class HabitController {

    private final UsuarioRepository usuarioRepository;
    private final HabitoRepository habitoRepository;
    private final RegistroHabitoRepository registroHabitoRepository;

    @GetMapping
    public ResponseEntity<?> listar(Authentication authentication) {
        Usuario usuario = requireUsuario(authentication);
        List<Habito> habitos = habitoRepository.findByUsuarioIdAndActivoTrue(usuario.getId());
        List<Map<String, Object>> respuesta = habitos.stream().map(h -> Map.<String, Object>of(
                "id", h.getId(),
                "nombre", h.getNombre(),
                "tipo", h.getTipo(),
                "completadoHoy", registroHabitoRepository.existsByHabitoIdAndFecha(h.getId(), LocalDate.now())
        )).toList();
        return ResponseEntity.ok(Map.of("habitos", respuesta));
    }

    @PostMapping
    public ResponseEntity<?> crear(Authentication authentication, @RequestBody CrearHabitoRequest request) {
        Usuario usuario = requireUsuario(authentication);
        String nombre = request.getNombre() == null ? "" : request.getNombre().trim();
        if (nombre.isEmpty()) {
            return ResponseEntity.badRequest().body(Map.of("error", "El hábito necesita un nombre"));
        }
        Habito habito = new Habito();
        habito.setUsuarioId(usuario.getId());
        habito.setNombre(nombre);
        habito.setTipo("OTRO");
        habitoRepository.save(habito);
        return ResponseEntity.ok(Map.of(
                "id", habito.getId(),
                "nombre", habito.getNombre(),
                "tipo", habito.getTipo(),
                "completadoHoy", false
        ));
    }

    @PostMapping("/{id}/completar")
    public ResponseEntity<?> completar(Authentication authentication, @PathVariable UUID id) {
        Usuario usuario = requireUsuario(authentication);
        if (registroHabitoRepository.existsByHabitoIdAndFecha(id, LocalDate.now())) {
            return ResponseEntity.ok(Map.of("status", "YA_COMPLETADO_HOY"));
        }
        RegistroHabito registro = new RegistroHabito();
        registro.setUsuarioId(usuario.getId());
        registro.setHabitoId(id);
        registroHabitoRepository.save(registro);
        return ResponseEntity.ok(Map.of("status", "COMPLETADO"));
    }

    private Usuario requireUsuario(Authentication authentication) {
        return usuarioRepository.findByEmail(authentication.getName())
                .orElseThrow(() -> new IllegalStateException("Usuario no encontrado"));
    }

    @Data
    static class CrearHabitoRequest {
        private String nombre;
    }
}
