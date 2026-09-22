-- ============================================================
-- V8: cierre diario. Neon (free) no siempre expone pg_cron, así
-- que el disparador viene de un @Scheduled de Spring — pero toda
-- la lógica de qué hacer sigue viviendo aquí, no en Java.
-- ============================================================

CREATE OR REPLACE FUNCTION job_cierre_diario()
RETURNS JSONB AS $$
DECLARE
    v_rachas_reseteadas INT;
    v_actividades_omitidas INT;
BEGIN
    -- Si la última actividad de una racha fue antes de ayer, la racha se rompió.
    UPDATE racha SET racha_actual = 0, updated_at = now()
    WHERE ultima_fecha < CURRENT_DATE - 1 AND racha_actual > 0;
    GET DIAGNOSTICS v_rachas_reseteadas = ROW_COUNT;

    -- Actividades de días ya pasados que nunca se marcaron: quedan OMITIDA, no pendientes eternos.
    UPDATE actividad_programada ap
    SET estado = 'OMITIDA'
    WHERE ap.estado = 'PENDIENTE'
      AND ap.dia_programa_id IN (SELECT id FROM dia_programa WHERE fecha < CURRENT_DATE);
    GET DIAGNOSTICS v_actividades_omitidas = ROW_COUNT;

    RETURN jsonb_build_object(
        'rachas_reseteadas', v_rachas_reseteadas,
        'actividades_omitidas', v_actividades_omitidas,
        'ejecutado_en', now()
    );
END;
$$ LANGUAGE plpgsql;
