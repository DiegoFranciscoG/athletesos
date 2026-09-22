package com.athleteos.backend.service;

import tools.jackson.databind.ObjectMapper;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.Map;
import java.util.UUID;

/**
 * Vocabulario y trivia con garantía real de no-repetición: cada función SQL
 * (siguiente_palabra / siguiente_trivia) excluye todo lo que ya está en
 * usuario_contenido_visto para ese usuario antes de elegir al azar. Si el
 * banco se agota, la lista vuelve vacía (nunca se recicla contenido).
 */
@Service
public class ContenidoAprendizajeService {

    private final JdbcTemplate jdbc;
    private final ObjectMapper objectMapper;

    public ContenidoAprendizajeService(JdbcTemplate jdbc, ObjectMapper objectMapper) {
        this.jdbc = jdbc;
        this.objectMapper = objectMapper;
    }

    public Map<String, Object> siguientePalabra(UUID usuarioId) {
        List<Map<String, Object>> rows = jdbc.queryForList("SELECT * FROM siguiente_palabra(?)", usuarioId);
        return rows.isEmpty() ? null : rows.get(0);
    }

    public Map<String, Object> siguienteTrivia(UUID usuarioId) {
        List<Map<String, Object>> rows = jdbc.queryForList("SELECT * FROM siguiente_trivia(?)", usuarioId);
        if (rows.isEmpty()) return null;
        Map<String, Object> row = new java.util.LinkedHashMap<>(rows.get(0));
        String opcionesJson = (String) row.remove("opciones");
        row.put("opciones", opcionesJson != null ? objectMapper.readValue(opcionesJson, List.class) : List.of());
        return row;
    }

    /** Solo se consulta la respuesta correcta DESPUÉS de que el usuario ya eligió una opción. */
    public Map<String, Object> responderTrivia(int triviaId, int opcionElegida) {
        List<Map<String, Object>> rows = jdbc.queryForList(
                "SELECT respuesta_correcta, explicacion FROM trivia WHERE id = ?", triviaId);
        if (rows.isEmpty()) return null;
        int correcta = ((Number) rows.get(0).get("respuesta_correcta")).intValue();
        return Map.of(
                "correcto", correcta == opcionElegida,
                "respuestaCorrecta", correcta,
                "explicacion", rows.get(0).get("explicacion") != null ? rows.get(0).get("explicacion") : ""
        );
    }
}
