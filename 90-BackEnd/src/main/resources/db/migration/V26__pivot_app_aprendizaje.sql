-- ============================================================
-- V26: la app se convierte en una app de aprendizaje pura
-- (calistenia/karate/boxeo/ajedrez). Se retira del flujo de usuario el
-- motor de plan de 90 días (fútbol/gym genérico/estudio por materias) y
-- el onboarding de nivel/intensidad — quedan las tablas y funciones
-- viejas intactas en la base (no se borran, por si se necesita revertir),
-- pero el onboarding nuevo ya no las usa.
--
-- Cada subtema de un dominio físico (calistenia/karate/boxeo) ahora carga
-- una prescripción real (series/reps o rounds/duración) para que, después
-- de ver el video, la app le diga al usuario exactamente cuánto hacer.
-- Ajedrez es contenido teórico/puzzles -> se deja sin prescripción.
--
-- Progresión series/reps por nivel_dificultad (1-5): estándar de
-- entrenamiento de resistencia muscular para población general (rango
-- 6-15 reps, 3-5 series, descanso creciente con la dificultad) — no hay
-- una prescripción publicada por ejercicio individual para los ~70
-- subtemas ya sembrados, así que se aplica esta progresión uniforme en
-- vez de inventar un número distinto por fila.
-- ============================================================

ALTER TABLE tema ADD COLUMN IF NOT EXISTS series_base SMALLINT;
ALTER TABLE tema ADD COLUMN IF NOT EXISTS repeticiones_base SMALLINT;
ALTER TABLE tema ADD COLUMN IF NOT EXISTS duracion_seg INTEGER;
ALTER TABLE tema ADD COLUMN IF NOT EXISTS descanso_seg SMALLINT;

-- ---------- CALISTENIA: reps-based, salvo ejercicios isométricos (duración) ----------
UPDATE tema SET series_base = 3, repeticiones_base = 12, descanso_seg = 45
WHERE dominio = 'CALISTENIA' AND padre_id IS NOT NULL AND nivel_dificultad = 1
  AND nombre !~* 'plancha|dead bug|movilidad';
UPDATE tema SET series_base = 3, repeticiones_base = 10, descanso_seg = 60
WHERE dominio = 'CALISTENIA' AND padre_id IS NOT NULL AND nivel_dificultad = 2
  AND nombre !~* 'plancha|dead bug|movilidad';
UPDATE tema SET series_base = 4, repeticiones_base = 10, descanso_seg = 75
WHERE dominio = 'CALISTENIA' AND padre_id IS NOT NULL AND nivel_dificultad = 3
  AND nombre !~* 'plancha|dead bug|movilidad';
UPDATE tema SET series_base = 4, repeticiones_base = 8, descanso_seg = 90
WHERE dominio = 'CALISTENIA' AND padre_id IS NOT NULL AND nivel_dificultad = 4
  AND nombre !~* 'plancha|dead bug|movilidad';
UPDATE tema SET series_base = 5, repeticiones_base = 6, descanso_seg = 120
WHERE dominio = 'CALISTENIA' AND padre_id IS NOT NULL AND nivel_dificultad = 5
  AND nombre !~* 'plancha|dead bug|movilidad';

-- isométricos: series x segundos de hold, en vez de reps
UPDATE tema SET series_base = 3, duracion_seg = 20, descanso_seg = 45
WHERE dominio = 'CALISTENIA' AND padre_id IS NOT NULL AND nivel_dificultad <= 2
  AND nombre ~* 'plancha|dead bug|movilidad';
UPDATE tema SET series_base = 3, duracion_seg = 35, descanso_seg = 60
WHERE dominio = 'CALISTENIA' AND padre_id IS NOT NULL AND nivel_dificultad = 3
  AND nombre ~* 'plancha|dead bug|movilidad';
UPDATE tema SET series_base = 4, duracion_seg = 45, descanso_seg = 75
WHERE dominio = 'CALISTENIA' AND padre_id IS NOT NULL AND nivel_dificultad >= 4
  AND nombre ~* 'plancha|dead bug|movilidad';

-- ---------- KARATE: reps-based, misma progresión que calistenia ----------
UPDATE tema SET series_base = 3, repeticiones_base = 12, descanso_seg = 30
WHERE dominio = 'KARATE' AND padre_id IS NOT NULL AND nivel_dificultad = 1;
UPDATE tema SET series_base = 3, repeticiones_base = 10, descanso_seg = 45
WHERE dominio = 'KARATE' AND padre_id IS NOT NULL AND nivel_dificultad = 2;
UPDATE tema SET series_base = 4, repeticiones_base = 10, descanso_seg = 45
WHERE dominio = 'KARATE' AND padre_id IS NOT NULL AND nivel_dificultad = 3;
UPDATE tema SET series_base = 4, repeticiones_base = 8, descanso_seg = 60
WHERE dominio = 'KARATE' AND padre_id IS NOT NULL AND nivel_dificultad >= 4;

-- ---------- BOXEO: rounds x duración (series_base = rounds), estándar de gimnasio de boxeo ----------
UPDATE tema SET series_base = 2, duracion_seg = 60, descanso_seg = 30
WHERE dominio = 'BOXEO' AND padre_id IS NOT NULL AND nivel_dificultad = 1;
UPDATE tema SET series_base = 2, duracion_seg = 90, descanso_seg = 45
WHERE dominio = 'BOXEO' AND padre_id IS NOT NULL AND nivel_dificultad = 2;
UPDATE tema SET series_base = 3, duracion_seg = 120, descanso_seg = 45
WHERE dominio = 'BOXEO' AND padre_id IS NOT NULL AND nivel_dificultad = 3;
UPDATE tema SET series_base = 3, duracion_seg = 150, descanso_seg = 60
WHERE dominio = 'BOXEO' AND padre_id IS NOT NULL AND nivel_dificultad >= 4;

-- ---------- obtener_ruta_aprendizaje: agrega la prescripción al resultado ----------
DROP FUNCTION IF EXISTS obtener_ruta_aprendizaje(uuid, text);
CREATE OR REPLACE FUNCTION obtener_ruta_aprendizaje(p_usuario_id UUID, p_dominio TEXT)
RETURNS TABLE(
    tema_id UUID, padre_id UUID, codigo TEXT, nombre TEXT, descripcion TEXT,
    orden SMALLINT, nivel_dificultad SMALLINT, video_url TEXT, video_titulo TEXT,
    contenido TEXT, fuente_url TEXT, es_subtema BOOLEAN, estado TEXT,
    series_base SMALLINT, repeticiones_base SMALLINT, duracion_seg INTEGER, descanso_seg SMALLINT
) AS $$
#variable_conflict use_column
BEGIN
    INSERT INTO usuario_tema_progreso (usuario_id, tema_id, estado)
    SELECT p_usuario_id, t.id, 'BLOQUEADO'
    FROM tema t
    WHERE t.dominio = p_dominio AND t.activo
      AND NOT EXISTS (SELECT 1 FROM usuario_tema_progreso up WHERE up.usuario_id = p_usuario_id AND up.tema_id = t.id)
    ON CONFLICT (usuario_id, tema_id) DO NOTHING;

    UPDATE usuario_tema_progreso up
    SET estado = 'DISPONIBLE'
    FROM tema t
    WHERE up.tema_id = t.id AND up.usuario_id = p_usuario_id AND t.dominio = p_dominio
      AND up.estado = 'BLOQUEADO'
      AND t.padre_id IN (SELECT id FROM tema WHERE dominio = p_dominio AND padre_id IS NULL AND orden = 1)
      AND t.orden = 1;

    RETURN QUERY
    SELECT t.id, t.padre_id, t.codigo, t.nombre, t.descripcion, t.orden, t.nivel_dificultad,
           t.video_url, t.video_titulo, t.contenido, t.fuente_url,
           (t.padre_id IS NOT NULL), COALESCE(up.estado, 'BLOQUEADO'),
           t.series_base, t.repeticiones_base, t.duracion_seg, t.descanso_seg
    FROM tema t
    LEFT JOIN usuario_tema_progreso up ON up.tema_id = t.id AND up.usuario_id = p_usuario_id
    WHERE t.dominio = p_dominio AND t.activo
    ORDER BY t.padre_id NULLS FIRST, t.orden;
END;
$$ LANGUAGE plpgsql;

-- ---------- onboarding simplificado: una sola pregunta, sin plan de 90 días ----------
CREATE OR REPLACE FUNCTION completar_onboarding_aprendizaje(p_usuario_id UUID)
RETURNS VOID AS $$
BEGIN
    UPDATE usuario SET onboarding_completado = TRUE WHERE id = p_usuario_id;

    INSERT INTO habito (usuario_id, nombre, tipo)
    SELECT p_usuario_id, nombre, tipo FROM (VALUES
        ('Hidratación al despertar', 'AGUA'),
        ('Dormir a la hora prevista', 'SUENO'),
        ('Sin pantalla después de las 22:30', 'PANTALLA'),
        ('Movilidad / estiramiento', 'MOVILIDAD')
    ) AS defaults(nombre, tipo)
    WHERE NOT EXISTS (SELECT 1 FROM habito h WHERE h.usuario_id = p_usuario_id);
END;
$$ LANGUAGE plpgsql;
