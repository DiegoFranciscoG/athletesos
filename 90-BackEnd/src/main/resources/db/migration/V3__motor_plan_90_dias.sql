-- ============================================================
-- V3: el motor del plan de 90 días. Toda la generación, lectura
-- de "qué toca ahora" y reprogramación vive en PL/pgSQL — Spring
-- Boot solo orquesta llamadas a estas funciones/vistas.
-- ============================================================

CREATE TABLE IF NOT EXISTS programa_90_dias (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    usuario_id UUID NOT NULL REFERENCES usuario(id) ON DELETE CASCADE,
    fecha_inicio DATE NOT NULL,
    fecha_fin DATE NOT NULL,
    nivel_habilidad TEXT NOT NULL,
    intensidad TEXT NOT NULL,
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX IF NOT EXISTS uq_programa_usuario_activo
    ON programa_90_dias(usuario_id) WHERE activo;

CREATE TABLE IF NOT EXISTS fase_programa (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    programa_id UUID NOT NULL REFERENCES programa_90_dias(id) ON DELETE CASCADE,
    numero SMALLINT NOT NULL CHECK (numero BETWEEN 1 AND 3),
    nombre TEXT NOT NULL,
    objetivo TEXT NOT NULL,
    dia_inicio SMALLINT NOT NULL,
    dia_fin SMALLINT NOT NULL,
    UNIQUE (programa_id, numero)
);

CREATE TABLE IF NOT EXISTS semana_programa (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    programa_id UUID NOT NULL REFERENCES programa_90_dias(id) ON DELETE CASCADE,
    numero_semana SMALLINT NOT NULL,
    fecha_inicio DATE NOT NULL,
    fecha_fin DATE NOT NULL,
    UNIQUE (programa_id, numero_semana)
);

CREATE TABLE IF NOT EXISTS dia_programa (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    programa_id UUID NOT NULL REFERENCES programa_90_dias(id) ON DELETE CASCADE,
    fase_id UUID NOT NULL REFERENCES fase_programa(id) ON DELETE CASCADE,
    semana_id UUID NOT NULL REFERENCES semana_programa(id) ON DELETE CASCADE,
    numero_dia SMALLINT NOT NULL,
    fecha DATE NOT NULL,
    dia_semana SMALLINT NOT NULL, -- ISO: 1=lunes .. 7=domingo
    es_dia_operativo BOOLEAN NOT NULL,
    UNIQUE (programa_id, numero_dia),
    UNIQUE (programa_id, fecha)
);
CREATE INDEX IF NOT EXISTS idx_dia_programa_fecha ON dia_programa(fecha);

CREATE TABLE IF NOT EXISTS actividad_programada (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    usuario_id UUID NOT NULL REFERENCES usuario(id) ON DELETE CASCADE,
    dia_programa_id UUID NOT NULL REFERENCES dia_programa(id) ON DELETE CASCADE,
    dia_original_id UUID REFERENCES dia_programa(id),
    fue_reprogramada BOOLEAN NOT NULL DEFAULT FALSE,
    tipo TEXT NOT NULL CHECK (tipo IN ('FUTBOL','GYM','ESTUDIO','HABITO','DESCANSO','REVISION_SEMANAL')),
    titulo TEXT NOT NULL,
    descripcion TEXT,
    hora_inicio TIME NOT NULL,
    duracion_min SMALLINT NOT NULL,
    prioridad SMALLINT NOT NULL DEFAULT 3 CHECK (prioridad BETWEEN 1 AND 5),
    dificultad SMALLINT,
    estado TEXT NOT NULL DEFAULT 'PENDIENTE' CHECK (estado IN
        ('PENDIENTE','ACTIVA','COMPLETADA','OMITIDA','REPROGRAMADA','CANCELADA','ADAPTADA')),
    ejercicio_futbol_id INTEGER REFERENCES ejercicio_futbol(id),
    ejercicio_gym_id INTEGER REFERENCES ejercicio_gym(id),
    orden SMALLINT NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_actividad_usuario_dia ON actividad_programada(usuario_id, dia_programa_id);
CREATE INDEX IF NOT EXISTS idx_actividad_estado ON actividad_programada(usuario_id, estado);

DROP TRIGGER IF EXISTS trg_actividad_updated_at ON actividad_programada;
CREATE TRIGGER trg_actividad_updated_at
    BEFORE UPDATE ON actividad_programada
    FOR EACH ROW EXECUTE FUNCTION fn_set_updated_at();

DROP TRIGGER IF EXISTS trg_actividad_auditoria ON actividad_programada;
CREATE TRIGGER trg_actividad_auditoria
    AFTER UPDATE ON actividad_programada
    FOR EACH ROW EXECUTE FUNCTION fn_auditar_cambio();

ALTER TABLE registro_sesion
    ADD CONSTRAINT fk_registro_sesion_actividad
    FOREIGN KEY (actividad_programada_id) REFERENCES actividad_programada(id) ON DELETE SET NULL;

-- ---------- helper: qué días de la semana según sesiones/semana ----------
CREATE OR REPLACE FUNCTION fn_dias_por_sesiones(p_sesiones SMALLINT)
RETURNS SMALLINT[] AS $$
BEGIN
    RETURN CASE p_sesiones
        WHEN 0 THEN ARRAY[]::SMALLINT[]
        WHEN 1 THEN ARRAY[3]::SMALLINT[]
        WHEN 2 THEN ARRAY[2,4]::SMALLINT[]
        WHEN 3 THEN ARRAY[1,3,5]::SMALLINT[]
        WHEN 4 THEN ARRAY[1,2,4,5]::SMALLINT[]
        ELSE ARRAY[1,2,3,4,5]::SMALLINT[]
    END;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- ============================================================
-- generar_programa_90_dias: idempotente. Si ya hay un programa
-- activo para el usuario, lo devuelve sin duplicar nada.
-- ============================================================
CREATE OR REPLACE FUNCTION generar_programa_90_dias(p_usuario_id UUID)
RETURNS UUID AS $$
DECLARE
    v_programa_id UUID;
    v_nivel TEXT;
    v_intensidad TEXT;
    v_fecha_inicio DATE := CURRENT_DATE;
    v_fase_id UUID;
    v_semana_id UUID;
    v_dia_id UUID;
    v_offset INT;
    v_fecha DATE;
    v_numero_dia SMALLINT;
    v_dow SMALLINT;
    v_es_operativo BOOLEAN;
    v_numero_semana SMALLINT;

    v_ses_futbol SMALLINT; v_ses_gym SMALLINT; v_ses_estudio SMALLINT; v_ses_habitos SMALLINT;
    v_dur_futbol SMALLINT; v_dur_gym SMALLINT; v_dur_estudio SMALLINT; v_dur_habitos SMALLINT;
    v_dias_futbol SMALLINT[]; v_dias_gym SMALLINT[];

    v_dificultad_max_futbol SMALLINT;
    v_dificultad_max_gym SMALLINT;
    v_count_futbol INT;
    v_count_gym INT;
    v_ejercicio_futbol_id INT;
    v_ejercicio_gym_id INT;

    v_materias TEXT[] := ARRAY['Java & Spring Boot','Flutter & Arquitectura','Bases de Datos','Inglés Técnico'];
BEGIN
    SELECT id INTO v_programa_id FROM programa_90_dias WHERE usuario_id = p_usuario_id AND activo LIMIT 1;
    IF v_programa_id IS NOT NULL THEN
        RETURN v_programa_id;
    END IF;

    SELECT nivel_habilidad, intensidad INTO v_nivel, v_intensidad FROM usuario WHERE id = p_usuario_id;
    IF v_nivel IS NULL OR v_intensidad IS NULL THEN
        RAISE EXCEPTION 'El usuario % no completó el onboarding (nivel/intensidad faltante)', p_usuario_id;
    END IF;

    INSERT INTO programa_90_dias (usuario_id, fecha_inicio, fecha_fin, nivel_habilidad, intensidad)
    VALUES (p_usuario_id, v_fecha_inicio, v_fecha_inicio + 89, v_nivel, v_intensidad)
    RETURNING id INTO v_programa_id;

    INSERT INTO fase_programa (programa_id, numero, nombre, objetivo, dia_inicio, dia_fin) VALUES
        (v_programa_id, 1, 'FASE 1: FUNDAMENTOS', 'Consolidar técnica base, rutina y hábitos.', 1, 30),
        (v_programa_id, 2, 'FASE 2: CONSTRUCCIÓN', 'Aumentar volumen y complejidad progresivamente.', 31, 60),
        (v_programa_id, 3, 'FASE 3: RENDIMIENTO', 'Maximizar intensidad y consolidar resultados.', 61, 90);

    FOR v_numero_semana IN 1..13 LOOP
        INSERT INTO semana_programa (programa_id, numero_semana, fecha_inicio, fecha_fin)
        VALUES (
            v_programa_id, v_numero_semana,
            v_fecha_inicio + (v_numero_semana - 1) * 7,
            LEAST(v_fecha_inicio + (v_numero_semana - 1) * 7 + 6, v_fecha_inicio + 89)
        );
    END LOOP;

    SELECT dificultad_max INTO v_dificultad_max_futbol FROM config_nivel WHERE nivel = v_nivel AND area = 'FUTBOL';
    SELECT dificultad_max INTO v_dificultad_max_gym FROM config_nivel WHERE nivel = v_nivel AND area = 'GYM';
    SELECT COUNT(*) INTO v_count_futbol FROM ejercicio_futbol WHERE dificultad <= v_dificultad_max_futbol AND activo;
    SELECT COUNT(*) INTO v_count_gym FROM ejercicio_gym WHERE dificultad <= v_dificultad_max_gym AND activo;

    SELECT sesiones_semana, duracion_min INTO v_ses_futbol, v_dur_futbol FROM config_intensidad WHERE intensidad = v_intensidad AND area = 'FUTBOL';
    SELECT sesiones_semana, duracion_min INTO v_ses_gym, v_dur_gym FROM config_intensidad WHERE intensidad = v_intensidad AND area = 'GYM';
    SELECT sesiones_semana, duracion_min INTO v_ses_estudio, v_dur_estudio FROM config_intensidad WHERE intensidad = v_intensidad AND area = 'ESTUDIO';
    SELECT sesiones_semana, duracion_min INTO v_ses_habitos, v_dur_habitos FROM config_intensidad WHERE intensidad = v_intensidad AND area = 'HABITOS';

    v_dias_futbol := fn_dias_por_sesiones(v_ses_futbol);
    v_dias_gym := fn_dias_por_sesiones(v_ses_gym);

    FOR v_offset IN 0..89 LOOP
        v_fecha := v_fecha_inicio + v_offset;
        v_numero_dia := v_offset + 1;
        v_dow := EXTRACT(ISODOW FROM v_fecha)::SMALLINT;
        v_es_operativo := v_dow BETWEEN 1 AND 5;

        SELECT id INTO v_fase_id FROM fase_programa
            WHERE programa_id = v_programa_id AND v_numero_dia BETWEEN dia_inicio AND dia_fin;
        SELECT id INTO v_semana_id FROM semana_programa
            WHERE programa_id = v_programa_id AND v_fecha BETWEEN fecha_inicio AND fecha_fin;

        INSERT INTO dia_programa (programa_id, fase_id, semana_id, numero_dia, fecha, dia_semana, es_dia_operativo)
        VALUES (v_programa_id, v_fase_id, v_semana_id, v_numero_dia, v_fecha, v_dow, v_es_operativo)
        RETURNING id INTO v_dia_id;

        IF v_es_operativo THEN
            IF v_dow = ANY(v_dias_futbol) AND v_count_futbol > 0 THEN
                SELECT id INTO v_ejercicio_futbol_id FROM ejercicio_futbol
                    WHERE dificultad <= v_dificultad_max_futbol AND activo
                    ORDER BY id OFFSET (v_numero_dia % v_count_futbol) LIMIT 1;

                INSERT INTO actividad_programada
                    (usuario_id, dia_programa_id, tipo, titulo, descripcion, hora_inicio, duracion_min, dificultad, ejercicio_futbol_id, orden)
                SELECT p_usuario_id, v_dia_id, 'FUTBOL', ef.nombre, ef.descripcion, '18:00', v_dur_futbol, ef.dificultad, ef.id, 1
                FROM ejercicio_futbol ef WHERE ef.id = v_ejercicio_futbol_id;
            END IF;

            IF v_dow = ANY(v_dias_gym) AND v_count_gym > 0 THEN
                SELECT id INTO v_ejercicio_gym_id FROM ejercicio_gym
                    WHERE dificultad <= v_dificultad_max_gym AND activo
                    ORDER BY id OFFSET (v_numero_dia % v_count_gym) LIMIT 1;

                INSERT INTO actividad_programada
                    (usuario_id, dia_programa_id, tipo, titulo, descripcion, hora_inicio, duracion_min, dificultad, ejercicio_gym_id, orden)
                SELECT p_usuario_id, v_dia_id, 'GYM', eg.nombre, eg.descripcion,
                       CASE WHEN v_dow = ANY(v_dias_futbol) THEN '17:00'::TIME ELSE '18:00'::TIME END,
                       v_dur_gym, eg.dificultad, eg.id, 2
                FROM ejercicio_gym eg WHERE eg.id = v_ejercicio_gym_id;
            END IF;

            INSERT INTO actividad_programada (usuario_id, dia_programa_id, tipo, titulo, descripcion, hora_inicio, duracion_min, orden)
            VALUES (p_usuario_id, v_dia_id, 'ESTUDIO', v_materias[1 + (v_numero_dia % array_length(v_materias, 1))],
                    'Bloque de estudio enfocado, sin distracciones.', '20:00', v_dur_estudio, 3);

            INSERT INTO actividad_programada (usuario_id, dia_programa_id, tipo, titulo, descripcion, hora_inicio, duracion_min, orden)
            VALUES (p_usuario_id, v_dia_id, 'HABITO', 'Rutina Nocturna',
                    'Higiene, preparar mochila/ropa, desconexión de pantallas.', '22:30', v_dur_habitos, 4);

        ELSIF v_dow = 6 THEN
            INSERT INTO actividad_programada (usuario_id, dia_programa_id, tipo, titulo, descripcion, hora_inicio, duracion_min, orden)
            VALUES (p_usuario_id, v_dia_id, 'DESCANSO', 'Recuperación & Movilidad',
                    'Movilidad, estiramiento y descanso activo.', '10:00', 30, 1);
        ELSE
            INSERT INTO actividad_programada (usuario_id, dia_programa_id, tipo, titulo, descripcion, hora_inicio, duracion_min, orden)
            VALUES (p_usuario_id, v_dia_id, 'REVISION_SEMANAL', 'Revisión Semanal',
                    'Qué funcionó, qué no, y preparar la semana siguiente.', '19:00', 30, 1);
        END IF;
    END LOOP;

    RETURN v_programa_id;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- vw_agenda_hoy: agenda del día actual por usuario con estado temporal.
-- ============================================================
CREATE OR REPLACE VIEW vw_agenda_hoy AS
SELECT
    ap.id, ap.usuario_id, ap.tipo, ap.titulo, ap.descripcion, ap.hora_inicio,
    ap.duracion_min, ap.estado, ap.dificultad, ap.orden,
    dp.fecha, dp.numero_dia, fp.numero AS fase_numero, fp.nombre AS fase_nombre,
    (ap.hora_inicio + (ap.duracion_min || ' minutes')::interval)::time AS hora_fin,
    CASE
        WHEN ap.estado = 'COMPLETADA' THEN 'COMPLETADA'
        WHEN CURRENT_TIME BETWEEN ap.hora_inicio AND (ap.hora_inicio + (ap.duracion_min || ' minutes')::interval)::time THEN 'ACTUAL'
        WHEN ap.hora_inicio > CURRENT_TIME THEN 'PROXIMA'
        ELSE 'PASADA'
    END AS estado_temporal
FROM actividad_programada ap
JOIN dia_programa dp ON dp.id = ap.dia_programa_id
JOIN fase_programa fp ON fp.id = dp.fase_id
WHERE dp.fecha = CURRENT_DATE
ORDER BY ap.hora_inicio, ap.orden;

CREATE OR REPLACE FUNCTION obtener_actividad_actual(p_usuario_id UUID)
RETURNS SETOF vw_agenda_hoy AS $$
    SELECT * FROM vw_agenda_hoy
    WHERE usuario_id = p_usuario_id AND estado_temporal = 'ACTUAL'
    ORDER BY hora_inicio LIMIT 1;
$$ LANGUAGE sql STABLE;

CREATE OR REPLACE FUNCTION obtener_siguiente_actividad(p_usuario_id UUID)
RETURNS SETOF vw_agenda_hoy AS $$
    SELECT * FROM vw_agenda_hoy
    WHERE usuario_id = p_usuario_id AND estado_temporal = 'PROXIMA'
    ORDER BY hora_inicio LIMIT 1;
$$ LANGUAGE sql STABLE;

-- ============================================================
-- reprogramar_actividad: mueve una actividad a otro día del mismo
-- programa (no crea historial nuevo de días, solo reapunta la FK).
-- ============================================================
CREATE OR REPLACE FUNCTION reprogramar_actividad(p_actividad_id UUID, p_nueva_fecha DATE)
RETURNS VOID AS $$
DECLARE
    v_programa_id UUID;
    v_dia_actual_id UUID;
    v_dia_nuevo_id UUID;
BEGIN
    SELECT dp.programa_id, ap.dia_programa_id INTO v_programa_id, v_dia_actual_id
    FROM actividad_programada ap JOIN dia_programa dp ON dp.id = ap.dia_programa_id
    WHERE ap.id = p_actividad_id;

    IF v_programa_id IS NULL THEN
        RAISE EXCEPTION 'Actividad % no encontrada', p_actividad_id;
    END IF;

    SELECT id INTO v_dia_nuevo_id FROM dia_programa WHERE programa_id = v_programa_id AND fecha = p_nueva_fecha;
    IF v_dia_nuevo_id IS NULL THEN
        RAISE EXCEPTION 'La fecha % está fuera del rango del programa de 90 días', p_nueva_fecha;
    END IF;

    UPDATE actividad_programada
    SET dia_programa_id = v_dia_nuevo_id,
        dia_original_id = COALESCE(dia_original_id, v_dia_actual_id),
        fue_reprogramada = TRUE,
        estado = 'PENDIENTE'
    WHERE id = p_actividad_id;
END;
$$ LANGUAGE plpgsql;
