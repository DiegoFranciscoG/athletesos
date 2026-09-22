package com.athleteos.backend.service;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.Map;
import java.util.UUID;

/**
 * Motor genérico de rutas de aprendizaje (temas/subtemas bloqueados hasta
 * completar el anterior). Toda la lógica de desbloqueo vive en Postgres
 * (obtener_ruta_aprendizaje / completar_tema) — este servicio solo orquesta.
 */
@Service
public class RutaAprendizajeService {

    private final JdbcTemplate jdbc;

    public RutaAprendizajeService(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    public List<Map<String, Object>> getRuta(UUID usuarioId, String dominio) {
        return jdbc.queryForList("SELECT * FROM obtener_ruta_aprendizaje(?, ?)", usuarioId, dominio);
    }

    public String completarTema(UUID usuarioId, UUID temaId) {
        return jdbc.queryForObject("SELECT completar_tema(?, ?)", String.class, usuarioId, temaId);
    }

    public List<Map<String, Object>> getPuzzlesAjedrez() {
        return jdbc.queryForList(
                "SELECT id, codigo, titulo, descripcion, fen, solucion_san, nivel_dificultad FROM puzzle_ajedrez WHERE activo ORDER BY orden");
    }
}
