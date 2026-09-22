package com.athleteos.backend.service;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.Map;
import java.util.UUID;

@Service
public class NotificationConfigService {

    private final JdbcTemplate jdbc;

    public NotificationConfigService(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    public List<Map<String, Object>> getConfiguracion(UUID usuarioId) {
        crearDefectosSiFaltan(usuarioId);
        return jdbc.queryForList(
                """
                SELECT categoria, activa, tipo,
                       hora_inicio::text AS hora_inicio, hora_fin::text AS hora_fin,
                       intervalo_min, hora_fija::text AS hora_fija, minutos_antes,
                       vibracion, sonido
                FROM configuracion_notificacion
                WHERE usuario_id = ?
                ORDER BY categoria
                """,
                usuarioId);
    }

    /** Usuarios creados después de la migración V25 no tienen filas semilla; se crean en el primer GET. */
    private void crearDefectosSiFaltan(UUID usuarioId) {
        jdbc.update("""
                INSERT INTO configuracion_notificacion (usuario_id, categoria, tipo, hora_inicio, hora_fin, intervalo_min, vibracion, sonido)
                VALUES (?, 'AGUA', 'INTERVALO', '08:00', '22:00', 60, TRUE, TRUE)
                ON CONFLICT (usuario_id, categoria) DO NOTHING
                """, usuarioId);
        jdbc.update("""
                INSERT INTO configuracion_notificacion (usuario_id, categoria, tipo, minutos_antes, vibracion, sonido)
                VALUES (?, 'PRE_ENTRENO', 'HORA_FIJA', 15, TRUE, TRUE)
                ON CONFLICT (usuario_id, categoria) DO NOTHING
                """, usuarioId);
        jdbc.update("""
                INSERT INTO configuracion_notificacion (usuario_id, categoria, tipo, hora_fija, vibracion, sonido)
                VALUES (?, 'DESCONEXION', 'HORA_FIJA', '21:30', TRUE, FALSE)
                ON CONFLICT (usuario_id, categoria) DO NOTHING
                """, usuarioId);
    }

    public int actualizar(UUID usuarioId, String categoria, Map<String, Object> campos) {
        return jdbc.update(
                """
                UPDATE configuracion_notificacion SET
                    activa = COALESCE(?, activa),
                    hora_inicio = COALESCE(?::time, hora_inicio),
                    hora_fin = COALESCE(?::time, hora_fin),
                    intervalo_min = COALESCE(?, intervalo_min),
                    hora_fija = COALESCE(?::time, hora_fija),
                    minutos_antes = COALESCE(?, minutos_antes),
                    vibracion = COALESCE(?, vibracion),
                    sonido = COALESCE(?, sonido),
                    updated_at = now()
                WHERE usuario_id = ? AND categoria = ?
                """,
                campos.get("activa"), campos.get("horaInicio"), campos.get("horaFin"),
                campos.get("intervaloMin"), campos.get("horaFija"), campos.get("minutosAntes"),
                campos.get("vibracion"), campos.get("sonido"),
                usuarioId, categoria);
    }
}
