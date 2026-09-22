-- ============================================================
-- V11: catálogo real de materias/carreras + selección del usuario
-- durante el onboarding. Reemplaza la rotación fija de 4 materias
-- hardcodeadas en generar_programa_90_dias por una lista elegida
-- por el usuario, guardada en Postgres.
-- ============================================================

CREATE TABLE IF NOT EXISTS materia (
    id SERIAL PRIMARY KEY,
    codigo TEXT NOT NULL UNIQUE,
    nombre TEXT NOT NULL,
    categoria TEXT NOT NULL CHECK (categoria IN
        ('HISTORIA','CIENCIA','MATEMATICA','NEGOCIOS','TECNOLOGIA','DERECHO','ARQUITECTURA','IDIOMA','FILOSOFIA','ARTE')),
    descripcion TEXT NOT NULL,
    activo BOOLEAN NOT NULL DEFAULT TRUE
);

INSERT INTO materia (codigo, nombre, categoria, descripcion) VALUES
 ('historia_ecuador','Historia de Ecuador','HISTORIA','Línea de tiempo por épocas: preincaico, colonia, independencia y república.'),
 ('historia_mundial','Historia mundial','HISTORIA','De las grandes civilizaciones a la globalización.'),
 ('biologia','Biología','CIENCIA','Célula, genética, evolución y biología humana.'),
 ('fisica','Física','CIENCIA','Mecánica, energía y fenómenos físicos aplicados.'),
 ('biotecnologia','Biotecnología','CIENCIA','Aplicaciones biológicas a la industria, salud y agricultura.'),
 ('matematica','Matemática','MATEMATICA','Álgebra, geometría y razonamiento cuantitativo.'),
 ('contabilidad','Contabilidad','NEGOCIOS','Partida doble, estados financieros y ejercicios prácticos.'),
 ('administracion','Administración de empresas','NEGOCIOS','Gestión, liderazgo y marketing básico.'),
 ('derecho','Derecho','NEGOCIOS','Nociones de derecho civil, mercantil y laboral.'),
 ('arquitectura','Arquitectura','ARQUITECTURA','Principios de diseño, estilos históricos y bocetos de espacios.'),
 ('ingenieria_software','Ingeniería de software','TECNOLOGIA','Estructuras de datos, bases de datos, POO y arquitectura de apps.'),
 ('ingles','Inglés','IDIOMA','Vocabulario, gramática, listening y conversación diaria.'),
 ('frances','Francés','IDIOMA','Bases de francés: vocabulario, gramática y conversación.'),
 ('lenguaje','Lenguaje y léxico','IDIOMA','Ampliar vocabulario y expresión oral/escrita en español.'),
 ('filosofia_estoica','Filosofía estoica','FILOSOFIA','Marco Aurelio, Séneca, Epicteto — filosofía aplicada al día a día.'),
 ('fotografia','Fotografía','ARTE','Composición, manejo manual de cámara y edición básica.')
ON CONFLICT (codigo) DO NOTHING;

CREATE TABLE IF NOT EXISTS usuario_materia (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    usuario_id UUID NOT NULL REFERENCES usuario(id) ON DELETE CASCADE,
    materia_id INTEGER NOT NULL REFERENCES materia(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (usuario_id, materia_id)
);
CREATE INDEX IF NOT EXISTS idx_usuario_materia ON usuario_materia(usuario_id);

-- ============================================================
-- actividad_programada gana una referencia opcional a materia,
-- para que el bloque de "ESTUDIO" apunte a una materia real del
-- catálogo en vez de solo un texto libre.
-- ============================================================
ALTER TABLE actividad_programada
    ADD COLUMN IF NOT EXISTS materia_id INTEGER REFERENCES materia(id);

-- ============================================================
-- generar_programa_90_dias se reemplaza: la rotación de ESTUDIO
-- ahora usa las materias que el usuario eligió (usuario_materia).
-- Si no eligió ninguna, usa un set general por defecto.
-- Se preserva el resto de la lógica sin cambios.
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

            v_materia_idx := 1 + (v_numero_dia % v_count_materias);
            INSERT INTO actividad_programada (usuario_id, dia_programa_id, tipo, titulo, descripcion, hora_inicio, duracion_min, materia_id, orden)
            VALUES (p_usuario_id, v_dia_id, 'ESTUDIO', v_materia_nombres[v_materia_idx],
                    'Bloque de estudio enfocado, sin distracciones.', '20:00', v_dur_estudio, v_materia_ids[v_materia_idx], 3);

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
-- completar_onboarding gana un parámetro opcional con las materias
-- elegidas (array de ids). Se sobrecarga para no romper llamadas
-- existentes sin ese parámetro.
-- ============================================================
CREATE OR REPLACE FUNCTION completar_onboarding(
    p_usuario_id UUID,
    p_respuestas JSONB,
    p_intensidad TEXT,
    p_materia_ids JSONB  -- array JSON de enteros, p.ej. [1,2,3]; se pasa así (no INTEGER[]) porque
                          -- el binding de arrays nativos vía JDBC es frágil — JSONB ya es el patrón probado.
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

    RETURN v_programa_id;
END;
$$ LANGUAGE plpgsql;

-- Sobrecarga de compatibilidad: sin materias explícitas (usa el default de generar_programa_90_dias)
CREATE OR REPLACE FUNCTION completar_onboarding(
    p_usuario_id UUID,
    p_respuestas JSONB,
    p_intensidad TEXT
) RETURNS UUID AS $$
    SELECT completar_onboarding(p_usuario_id, p_respuestas, p_intensidad, NULL::JSONB);
$$ LANGUAGE sql;
