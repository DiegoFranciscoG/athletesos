-- ============================================================
-- V7: test de onboarding (PRINCIPIANTE/INTERMEDIO/PROFESIONAL)
-- + transacción única que cierra el onboarding y dispara la
-- generación del programa de 90 días.
-- ============================================================

-- Puntaje: 6 preguntas, 0-2 puntos cada una (máx 12).
-- 0-4 => PRINCIPIANTE, 5-8 => INTERMEDIO, 9-12 => PROFESIONAL.
CREATE OR REPLACE FUNCTION calcular_nivel_onboarding(p_respuestas JSONB)
RETURNS TABLE(nivel TEXT, puntaje INT) AS $$
DECLARE
    v_puntaje INT;
BEGIN
    v_puntaje :=
        COALESCE((p_respuestas->>'experiencia_futbol')::INT, 0) +
        COALESCE((p_respuestas->>'experiencia_gym')::INT, 0) +
        COALESCE((p_respuestas->>'frecuencia_semanal')::INT, 0) +
        COALESCE((p_respuestas->>'habito_estudio')::INT, 0) +
        COALESCE((p_respuestas->>'autopercepcion')::INT, 0) +
        COALESCE((p_respuestas->>'disponibilidad_horas')::INT, 0);

    RETURN QUERY SELECT
        CASE WHEN v_puntaje <= 4 THEN 'PRINCIPIANTE'
             WHEN v_puntaje <= 8 THEN 'INTERMEDIO'
             ELSE 'PROFESIONAL' END,
        v_puntaje;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- ============================================================
-- completar_onboarding: única transacción que guarda el test,
-- fija nivel/intensidad, siembra hábitos por defecto y genera
-- el programa de 90 días. Idempotente vía generar_programa_90_dias.
-- ============================================================
CREATE OR REPLACE FUNCTION completar_onboarding(
    p_usuario_id UUID,
    p_respuestas JSONB,
    p_intensidad TEXT
) RETURNS UUID AS $$
DECLARE
    v_nivel TEXT;
    v_puntaje INT;
    v_programa_id UUID;
BEGIN
    IF p_intensidad NOT IN ('NORMAL', 'INTERMEDIA', 'INTENSA') THEN
        RAISE EXCEPTION 'Intensidad inválida: %', p_intensidad;
    END IF;

    SELECT nivel, puntaje INTO v_nivel, v_puntaje FROM calcular_nivel_onboarding(p_respuestas);

    INSERT INTO onboarding_respuesta (usuario_id, respuestas, puntaje_total, nivel_calculado)
    VALUES (p_usuario_id, p_respuestas, v_puntaje, v_nivel);

    UPDATE usuario
    SET nivel_habilidad = v_nivel,
        intensidad = p_intensidad,
        onboarding_completado = TRUE
    WHERE id = p_usuario_id;

    INSERT INTO habito (usuario_id, nombre, tipo)
    SELECT p_usuario_id, nombre, tipo FROM (VALUES
        ('Hidratación al despertar', 'AGUA'),
        ('Dormir a la hora prevista', 'SUENO'),
        ('Sin pantalla después de las 22:30', 'PANTALLA'),
        ('Movilidad / estiramiento', 'MOVILIDAD')
    ) AS defaults(nombre, tipo)
    WHERE NOT EXISTS (SELECT 1 FROM habito h WHERE h.usuario_id = p_usuario_id);

    v_programa_id := generar_programa_90_dias(p_usuario_id);

    RETURN v_programa_id;
END;
$$ LANGUAGE plpgsql;
