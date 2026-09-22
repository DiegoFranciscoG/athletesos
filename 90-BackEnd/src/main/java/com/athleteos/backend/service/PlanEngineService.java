package com.athleteos.backend.service;

import tools.jackson.databind.ObjectMapper;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;

import java.time.LocalDate;
import java.util.List;
import java.util.Map;
import java.util.UUID;

/**
 * Puerta de entrada a la lógica de negocio que vive en Postgres (funciones,
 * triggers, vistas). Spring Boot no reimplementa reglas de planificación:
 * solo llama a estas funciones y da forma a la respuesta HTTP.
 */
@Service
public class PlanEngineService {

    private final JdbcTemplate jdbc;
    private final ObjectMapper objectMapper;

    public PlanEngineService(JdbcTemplate jdbc, ObjectMapper objectMapper) {
        this.jdbc = jdbc;
        this.objectMapper = objectMapper;
    }

    // ---------- onboarding ----------

    /** App de aprendizaje: sin test de nivel ni plan de 90 días, solo marca onboarding listo y siembra los hábitos base. */
    public void completarOnboardingAprendizaje(UUID usuarioId) {
        // completar_onboarding_aprendizaje() devuelve VOID; jdbc.update() falla sobre un
        // SELECT (executeUpdate no lo acepta), así que se consume con queryForList.
        jdbc.queryForList("SELECT completar_onboarding_aprendizaje(?::uuid)", usuarioId);
    }

    /**
     * Lee nivel_habilidad/intensidad directo por JDBC (no JPA): usuarioRepository
     * ya tiene esta fila en caché de sesión desde antes del onboarding (Open Session
     * In View), así que un findById() ahí devolvería datos viejos, no los recién
     * escritos por completar_onboarding() vía SQL nativo.
     */
    public Map<String, Object> getUsuarioNivelIntensidad(UUID usuarioId) {
        List<Map<String, Object>> rows = jdbc.queryForList(
                "SELECT nivel_habilidad, intensidad FROM usuario WHERE id = ?", usuarioId);
        return rows.isEmpty() ? null : rows.get(0);
    }

    // ---------- dashboard / agenda ----------

    public Map<String, Object> getDashboard(UUID usuarioId) {
        String sql = "SELECT * FROM vw_dashboard_usuario WHERE usuario_id = ?";
        List<Map<String, Object>> rows = jdbc.queryForList(sql, usuarioId);
        return rows.isEmpty() ? null : rows.get(0);
    }

    public Map<String, Object> getActividadActual(UUID usuarioId) {
        List<Map<String, Object>> rows = jdbc.queryForList(
                "SELECT * FROM obtener_actividad_actual(?)", usuarioId);
        return rows.isEmpty() ? null : rows.get(0);
    }

    public List<Map<String, Object>> getAgendaHoy(UUID usuarioId) {
        return jdbc.queryForList("SELECT * FROM vw_agenda_hoy WHERE usuario_id = ? ORDER BY hora_inicio", usuarioId);
    }

    // ---------- adaptación diaria ----------

    public Map<String, Object> evaluarDia(UUID usuarioId, LocalDate fecha) {
        String json = jdbc.queryForObject(
                "SELECT evaluar_dia_usuario(?, ?)::text", String.class, usuarioId, fecha);
        return parseJson(json);
    }

    // ---------- progreso / rachas ----------

    public List<Map<String, Object>> getRachas(UUID usuarioId) {
        return jdbc.queryForList("SELECT tipo, racha_actual, racha_maxima, ultima_fecha FROM racha WHERE usuario_id = ?", usuarioId);
    }

    // ---------- admin ----------

    public List<Map<String, Object>> getConfigIntensidad() {
        return jdbc.queryForList("SELECT * FROM config_intensidad ORDER BY area, intensidad");
    }

    public List<Map<String, Object>> getConfigNivel() {
        return jdbc.queryForList("SELECT * FROM config_nivel ORDER BY area, nivel");
    }

    public void actualizarConfigIntensidad(int id, Map<String, Object> campos) {
        jdbc.update("""
            UPDATE config_intensidad
            SET sesiones_semana = ?, duracion_min = ?, series_base = ?, repeticiones_base = ?,
                descanso_seg = ?, volumen_pct = ?
            WHERE id = ?
            """,
            campos.get("sesionesSemana"), campos.get("duracionMin"), campos.get("seriesBase"),
            campos.get("repeticionesBase"), campos.get("descansoSeg"), campos.get("volumenPct"), id);
    }

    public List<Map<String, Object>> getAuditoriaReciente(int limit) {
        return jdbc.queryForList("SELECT * FROM auditoria ORDER BY created_at DESC LIMIT ?", limit);
    }

    // ---------- helpers ----------

    private Map<String, Object> parseJson(String json) {
        try {
            if (json == null) return Map.of();
            return objectMapper.readValue(json, Map.class);
        } catch (Exception e) {
            throw new IllegalStateException("Respuesta JSON inválida desde Postgres: " + json, e);
        }
    }
}
