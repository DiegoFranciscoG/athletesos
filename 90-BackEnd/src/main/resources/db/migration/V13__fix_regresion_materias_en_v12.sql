-- ============================================================
-- V13: V12 corrigió la frecuencia de ESTUDIO/HABITO pero se basó
-- por error en el cuerpo de V3 (rotacion de 4 materias hardcodeadas)
-- en vez del de V11 (materias reales elegidas por el usuario via
-- usuario_materia). Esto revirtio silenciosamente la feature de
-- materias dinamicas para cualquier programa generado mientras V12
-- estuvo activa. Se fusionan ambos fixes en un solo cuerpo correcto.
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
    v_dias_futbol SMALLINT[]; v_dias_gym SMALLINT[]; v_dias_estudio SMALLINT[]; v_dias_habitos SMALLINT[];

    v_dificultad_max_futbol SMALLINT;
    v_dificultad_max_gym SMALLINT;
    v_count_futbol INT;
    v_count_gym INT;
    v_ejercicio_futbol_id INT;
    v_ejercicio_gym_id INT;

    v_materia_ids INT[];
    v_materia_nombres TEXT[];
    v_count_materias INT;
    v_materia_idx INT;
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
    v_dias_estudio := fn_dias_por_sesiones(v_ses_estudio);
    v_dias_habitos := fn_dias_por_sesiones(v_ses_habitos);

    -- Materias elegidas por el usuario en el onboarding; si no eligió ninguna,
    -- usa un set general por defecto (nunca queda sin contenido de estudio).
    SELECT array_agg(materia_id), array_agg(m.nombre) INTO v_materia_ids, v_materia_nombres
    FROM usuario_materia um JOIN materia m ON m.id = um.materia_id
    WHERE um.usuario_id = p_usuario_id;

    IF v_materia_ids IS NULL OR array_length(v_materia_ids, 1) = 0 THEN
        SELECT array_agg(id), array_agg(nombre) INTO v_materia_ids, v_materia_nombres
        FROM materia WHERE codigo IN ('ingenieria_software','ingles','historia_ecuador','filosofia_estoica');
    END IF;
    v_count_materias := array_length(v_materia_ids, 1);

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

            IF v_dow = ANY(v_dias_estudio) THEN
                v_materia_idx := 1 + (v_numero_dia % v_count_materias);
                INSERT INTO actividad_programada (usuario_id, dia_programa_id, tipo, titulo, descripcion, hora_inicio, duracion_min, materia_id, orden)
                VALUES (p_usuario_id, v_dia_id, 'ESTUDIO', v_materia_nombres[v_materia_idx],
                        'Bloque de estudio enfocado, sin distracciones.', '20:00', v_dur_estudio, v_materia_ids[v_materia_idx], 3);
            END IF;

            IF v_dow = ANY(v_dias_habitos) THEN
                INSERT INTO actividad_programada (usuario_id, dia_programa_id, tipo, titulo, descripcion, hora_inicio, duracion_min, orden)
                VALUES (p_usuario_id, v_dia_id, 'HABITO', 'Rutina Nocturna',
                        'Higiene, preparar mochila/ropa, desconexión de pantallas.', '22:30', v_dur_habitos, 4);
            END IF;

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
