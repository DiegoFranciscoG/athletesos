-- ============================================================
-- V14: cierra dos huecos encontrados en la certificacion del motor:
--
-- 1) DESAFIOS: desafio_usuario nunca se insertaba desde ningun lado
--    (la UI de Flutter ya existia y esperaba datos reales). Se agrega
--    asignar_desafio_semanal(), llamada al completar onboarding y cada
--    dia desde job_cierre_diario() para refrescar retos vencidos. El
--    progreso se incrementa automaticamente via el trigger existente
--    de actividad_programada (futbol/gym/estudio). Hidratacion queda
--    fuera de esta ronda (necesitaria un trigger nuevo en
--    registro_hidratacion, no existe todavia).
--
-- 2) FASES: dificultad y duracion de futbol/gym eran identicas en las
--    3 fases del programa (medido en la auditoria: 2.86 / 3.14 / 2.90
--    de dificultad promedio, sin patron real). Ahora la fase 1 limita
--    a un techo de dificultad mas bajo, la fase 2 sube, la fase 3 usa
--    el techo completo del nivel; la duracion tambien escala +10%/+20%
--    por fase. Principiante (techo=2) no tiene mucho rango para esto
--    porque su catalogo solo llega a dificultad 2 -- es esperado.
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
    v_ejercicio_futbol_id INT;
    v_ejercicio_gym_id INT;

    -- por-fase: techo de dificultad efectivo, tamano de catalogo elegible y duracion escalada
    v_fase_actual SMALLINT;
    v_dif_efectiva_futbol SMALLINT; v_dif_efectiva_gym SMALLINT;
    v_count_futbol_fase INT; v_count_gym_fase INT;
    v_dur_futbol_fase SMALLINT; v_dur_gym_fase SMALLINT;

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

    SELECT sesiones_semana, duracion_min INTO v_ses_futbol, v_dur_futbol FROM config_intensidad WHERE intensidad = v_intensidad AND area = 'FUTBOL';
    SELECT sesiones_semana, duracion_min INTO v_ses_gym, v_dur_gym FROM config_intensidad WHERE intensidad = v_intensidad AND area = 'GYM';
    SELECT sesiones_semana, duracion_min INTO v_ses_estudio, v_dur_estudio FROM config_intensidad WHERE intensidad = v_intensidad AND area = 'ESTUDIO';
    SELECT sesiones_semana, duracion_min INTO v_ses_habitos, v_dur_habitos FROM config_intensidad WHERE intensidad = v_intensidad AND area = 'HABITOS';

    v_dias_futbol := fn_dias_por_sesiones(v_ses_futbol);
    v_dias_gym := fn_dias_por_sesiones(v_ses_gym);
    v_dias_estudio := fn_dias_por_sesiones(v_ses_estudio);
    v_dias_habitos := fn_dias_por_sesiones(v_ses_habitos);

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

        -- Progresion real por fase: techo de dificultad y duracion suben en construccion/rendimiento.
        v_fase_actual := CASE WHEN v_numero_dia <= 30 THEN 1 WHEN v_numero_dia <= 60 THEN 2 ELSE 3 END;
        v_dif_efectiva_futbol := CASE v_fase_actual
            WHEN 1 THEN GREATEST(1, CEIL(v_dificultad_max_futbol * 0.6))
            WHEN 2 THEN GREATEST(1, CEIL(v_dificultad_max_futbol * 0.8))
            ELSE v_dificultad_max_futbol END;
        v_dif_efectiva_gym := CASE v_fase_actual
            WHEN 1 THEN GREATEST(1, CEIL(v_dificultad_max_gym * 0.6))
            WHEN 2 THEN GREATEST(1, CEIL(v_dificultad_max_gym * 0.8))
            ELSE v_dificultad_max_gym END;
        v_dur_futbol_fase := CASE v_fase_actual WHEN 1 THEN v_dur_futbol WHEN 2 THEN ROUND(v_dur_futbol * 1.10) ELSE ROUND(v_dur_futbol * 1.20) END;
        v_dur_gym_fase := CASE v_fase_actual WHEN 1 THEN v_dur_gym WHEN 2 THEN ROUND(v_dur_gym * 1.10) ELSE ROUND(v_dur_gym * 1.20) END;

        SELECT COUNT(*) INTO v_count_futbol_fase FROM ejercicio_futbol WHERE dificultad <= v_dif_efectiva_futbol AND activo;
        SELECT COUNT(*) INTO v_count_gym_fase FROM ejercicio_gym WHERE dificultad <= v_dif_efectiva_gym AND activo;

        IF v_es_operativo THEN
            IF v_dow = ANY(v_dias_futbol) AND v_count_futbol_fase > 0 THEN
                SELECT id INTO v_ejercicio_futbol_id FROM ejercicio_futbol
                    WHERE dificultad <= v_dif_efectiva_futbol AND activo
                    ORDER BY id OFFSET (v_numero_dia % v_count_futbol_fase) LIMIT 1;

                INSERT INTO actividad_programada
                    (usuario_id, dia_programa_id, tipo, titulo, descripcion, hora_inicio, duracion_min, dificultad, ejercicio_futbol_id, orden)
                SELECT p_usuario_id, v_dia_id, 'FUTBOL', ef.nombre, ef.descripcion, '18:00', v_dur_futbol_fase, ef.dificultad, ef.id, 1
                FROM ejercicio_futbol ef WHERE ef.id = v_ejercicio_futbol_id;
            END IF;

            IF v_dow = ANY(v_dias_gym) AND v_count_gym_fase > 0 THEN
                SELECT id INTO v_ejercicio_gym_id FROM ejercicio_gym
                    WHERE dificultad <= v_dif_efectiva_gym AND activo
                    ORDER BY id OFFSET (v_numero_dia % v_count_gym_fase) LIMIT 1;

                INSERT INTO actividad_programada
                    (usuario_id, dia_programa_id, tipo, titulo, descripcion, hora_inicio, duracion_min, dificultad, ejercicio_gym_id, orden)
                SELECT p_usuario_id, v_dia_id, 'GYM', eg.nombre, eg.descripcion,
                       CASE WHEN v_dow = ANY(v_dias_futbol) THEN '17:00'::TIME ELSE '18:00'::TIME END,
                       v_dur_gym_fase, eg.dificultad, eg.id, 2
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

-- ============================================================
-- asignar_desafio_semanal: da de alta un reto activo para el usuario
-- si no tiene ninguno vigente. Idempotente (no duplica si ya tiene uno
-- con fecha_fin >= hoy). Rota entre los retos disponibles de su
-- intensidad usando la semana ISO del año como semilla determinista.
-- ============================================================
CREATE OR REPLACE FUNCTION asignar_desafio_semanal(p_usuario_id UUID)
RETURNS UUID AS $$
DECLARE
    v_intensidad TEXT;
    v_tiene_activo BOOLEAN;
    v_desafio_id INT;
    v_count INT;
    v_idx INT;
    v_lunes DATE;
    v_domingo DATE;
    v_desafio_usuario_id UUID;
BEGIN
    SELECT intensidad INTO v_intensidad FROM usuario WHERE id = p_usuario_id;
    IF v_intensidad IS NULL THEN
        RETURN NULL;
    END IF;

    SELECT EXISTS(
        SELECT 1 FROM desafio_usuario WHERE usuario_id = p_usuario_id AND fecha_fin >= CURRENT_DATE
    ) INTO v_tiene_activo;
    IF v_tiene_activo THEN
        RETURN NULL;
    END IF;

    SELECT COUNT(*) INTO v_count FROM desafio WHERE intensidad = v_intensidad;
    IF v_count = 0 THEN
        RETURN NULL;
    END IF;

    v_idx := EXTRACT(WEEK FROM CURRENT_DATE)::INT % v_count;
    SELECT id INTO v_desafio_id FROM desafio WHERE intensidad = v_intensidad ORDER BY id OFFSET v_idx LIMIT 1;

    v_lunes := CURRENT_DATE - (EXTRACT(ISODOW FROM CURRENT_DATE)::INT - 1);
    v_domingo := v_lunes + 6;

    INSERT INTO desafio_usuario (usuario_id, desafio_id, fecha_inicio, fecha_fin, progreso, completado)
    VALUES (p_usuario_id, v_desafio_id, v_lunes, v_domingo, 0, FALSE)
    RETURNING id INTO v_desafio_usuario_id;

    RETURN v_desafio_usuario_id;
END;
$$ LANGUAGE plpgsql;

-- completar_onboarding ya genera el programa; ahora tambien asigna el primer reto.
CREATE OR REPLACE FUNCTION completar_onboarding(
    p_usuario_id UUID,
    p_respuestas JSONB,
    p_intensidad TEXT,
    p_materia_ids JSONB
) RETURNS UUID AS $$
DECLARE
    v_nivel TEXT;
    v_puntaje INT;
    v_programa_id UUID;
    v_materia_id INT;
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

    IF p_materia_ids IS NOT NULL AND jsonb_typeof(p_materia_ids) = 'array' THEN
        FOR v_materia_id IN SELECT jsonb_array_elements_text(p_materia_ids)::INT LOOP
            INSERT INTO usuario_materia (usuario_id, materia_id)
            VALUES (p_usuario_id, v_materia_id)
            ON CONFLICT (usuario_id, materia_id) DO NOTHING;
        END LOOP;
    END IF;

    INSERT INTO habito (usuario_id, nombre, tipo)
    SELECT p_usuario_id, nombre, tipo FROM (VALUES
        ('Hidratación al despertar', 'AGUA'),
        ('Dormir a la hora prevista', 'SUENO'),
        ('Sin pantalla después de las 22:30', 'PANTALLA'),
        ('Movilidad / estiramiento', 'MOVILIDAD')
    ) AS defaults(nombre, tipo)
    WHERE NOT EXISTS (SELECT 1 FROM habito h WHERE h.usuario_id = p_usuario_id);

    v_programa_id := generar_programa_90_dias(p_usuario_id);
    PERFORM asignar_desafio_semanal(p_usuario_id);

    RETURN v_programa_id;
END;
$$ LANGUAGE plpgsql;

-- job_cierre_diario ahora tambien refresca retos vencidos de usuarios con programa activo.
CREATE OR REPLACE FUNCTION job_cierre_diario()
RETURNS JSONB AS $$
DECLARE
    v_rachas_reseteadas INT;
    v_actividades_omitidas INT;
    v_desafios_asignados INT := 0;
    v_usuario_id UUID;
BEGIN
    UPDATE racha SET racha_actual = 0, updated_at = now()
    WHERE ultima_fecha < CURRENT_DATE - 1 AND racha_actual > 0;
    GET DIAGNOSTICS v_rachas_reseteadas = ROW_COUNT;

    UPDATE actividad_programada ap
    SET estado = 'OMITIDA'
    WHERE ap.estado = 'PENDIENTE'
      AND ap.dia_programa_id IN (SELECT id FROM dia_programa WHERE fecha < CURRENT_DATE);
    GET DIAGNOSTICS v_actividades_omitidas = ROW_COUNT;

    FOR v_usuario_id IN
        SELECT DISTINCT usuario_id FROM programa_90_dias WHERE activo
    LOOP
        IF asignar_desafio_semanal(v_usuario_id) IS NOT NULL THEN
            v_desafios_asignados := v_desafios_asignados + 1;
        END IF;
    END LOOP;

    RETURN jsonb_build_object(
        'rachas_reseteadas', v_rachas_reseteadas,
        'actividades_omitidas', v_actividades_omitidas,
        'desafios_asignados', v_desafios_asignados,
        'ejecutado_en', now()
    );
END;
$$ LANGUAGE plpgsql;

-- fn_actividad_completada ahora tambien hace avanzar el reto activo que
-- coincida en tipo (futbol/gym/estudio) cuando se completa una actividad.
CREATE OR REPLACE FUNCTION fn_actividad_completada()
RETURNS TRIGGER AS $$
DECLARE
    v_fecha DATE;
    v_xp INT;
    v_racha_tipo TEXT;
    v_tipo_desafio TEXT;
BEGIN
    IF NEW.estado = 'COMPLETADA' AND (OLD.estado IS DISTINCT FROM 'COMPLETADA') THEN
        SELECT fecha INTO v_fecha FROM dia_programa WHERE id = NEW.dia_programa_id;

        v_xp := CASE NEW.tipo
            WHEN 'FUTBOL' THEN 20 WHEN 'GYM' THEN 20 WHEN 'ESTUDIO' THEN 15
            WHEN 'HABITO' THEN 10 WHEN 'REVISION_SEMANAL' THEN 10 ELSE 5 END;

        INSERT INTO xp_evento (usuario_id, tipo, xp, origen_tabla, origen_id)
        VALUES (NEW.usuario_id, NEW.tipo, v_xp, 'actividad_programada', NEW.id::TEXT);

        v_racha_tipo := CASE NEW.tipo
            WHEN 'FUTBOL' THEN 'FUTBOL' WHEN 'GYM' THEN 'GYM' WHEN 'ESTUDIO' THEN 'ESTUDIO'
            WHEN 'HABITO' THEN 'HABITOS' ELSE NULL END;

        IF v_racha_tipo IS NOT NULL THEN
            PERFORM fn_actualizar_racha(NEW.usuario_id, v_racha_tipo, v_fecha);
        END IF;

        v_tipo_desafio := CASE NEW.tipo
            WHEN 'FUTBOL' THEN 'SESIONES_FUTBOL' WHEN 'GYM' THEN 'SESIONES_GYM' WHEN 'ESTUDIO' THEN 'SESIONES_ESTUDIO'
            ELSE NULL END;
        IF v_tipo_desafio IS NOT NULL THEN
            UPDATE desafio_usuario du
            SET progreso = du.progreso + 1,
                completado = (du.progreso + 1) >= d.meta
            FROM desafio d
            WHERE du.desafio_id = d.id AND d.tipo = v_tipo_desafio
              AND du.usuario_id = NEW.usuario_id
              AND du.fecha_inicio <= v_fecha AND du.fecha_fin >= v_fecha
              AND NOT du.completado;
        END IF;

        INSERT INTO registro_sesion (usuario_id, tipo, actividad_programada_id, titulo, fecha, duracion_real_min)
        VALUES (NEW.usuario_id,
                CASE WHEN NEW.tipo IN ('FUTBOL','GYM','ESTUDIO') THEN NEW.tipo ELSE 'HABITO' END,
                NEW.id, NEW.titulo, v_fecha, NEW.duracion_min);
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
