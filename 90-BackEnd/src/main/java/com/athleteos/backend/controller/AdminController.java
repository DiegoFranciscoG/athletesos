package com.athleteos.backend.controller;

import com.athleteos.backend.service.PlanEngineService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

/**
 * Panel de control del sistema (no una app distinta): editar la
 * configuración de nivel/intensidad y ver auditoría sin tocar código.
 * Protegido a nivel de SecurityConfig (/admin/**) y aquí también por
 * @PreAuthorize como defensa en profundidad.
 */
@RestController
@RequestMapping("/api/v1/admin")
@RequiredArgsConstructor
@PreAuthorize("hasRole('ADMIN')")
public class AdminController {

    private final PlanEngineService planEngineService;

    @GetMapping("/config/intensidad")
    public ResponseEntity<?> configIntensidad() {
        return ResponseEntity.ok(Map.of("config", planEngineService.getConfigIntensidad()));
    }

    @PutMapping("/config/intensidad/{id}")
    public ResponseEntity<?> actualizarConfigIntensidad(@PathVariable int id, @RequestBody Map<String, Object> campos) {
        planEngineService.actualizarConfigIntensidad(id, campos);
        return ResponseEntity.ok(Map.of("status", "ACTUALIZADO"));
    }

    @GetMapping("/config/nivel")
    public ResponseEntity<?> configNivel() {
        return ResponseEntity.ok(Map.of("config", planEngineService.getConfigNivel()));
    }

    @GetMapping("/auditoria")
    public ResponseEntity<?> auditoria(@RequestParam(defaultValue = "100") int limit) {
        return ResponseEntity.ok(Map.of("eventos", planEngineService.getAuditoriaReciente(limit)));
    }
}
