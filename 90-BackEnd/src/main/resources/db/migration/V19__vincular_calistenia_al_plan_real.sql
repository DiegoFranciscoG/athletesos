-- ============================================================
-- V19: la ruta de aprendizaje de CALISTENIA vivia separada del plan
-- real programado (que ya tiene hora_inicio, como todo lo demas).
-- Diego no encontraba donde ver el ejercicio porque el unico acceso
-- era un icono chico -- y encima no estaba conectado a "que toca
-- ahora" con su hora real.
--
-- Fix: cada tema de calistenia se vincula al ejercicio_gym que lo
-- origino. Cuando el usuario completa su bloque de GYM real del dia
-- (el que ya aparece en Home/Plan con su hora programada), el mismo
-- trigger que ya reparte XP y racha ahora TAMBIEN hace avanzar la
-- ruta de calistenia automaticamente -- sin pantalla separada, sin
-- accion extra, sin depender de encontrar un icono escondido.
-- ============================================================

ALTER TABLE tema ADD COLUMN IF NOT EXISTS ejercicio_gym_id INTEGER REFERENCES ejercicio_gym(id);

UPDATE tema t SET ejercicio_gym_id = eg.id
FROM ejercicio_gym eg
WHERE t.dominio = 'CALISTENIA' AND t.padre_id IS NOT NULL AND t.nombre = eg.nombre;

CREATE INDEX IF NOT EXISTS idx_tema_ejercicio_gym ON tema(ejercicio_gym_id) WHERE ejercicio_gym_id IS NOT NULL;

CREATE OR REPLACE FUNCTION fn_actividad_completada()
RETURNS TRIGGER AS $$
DECLARE
    v_fecha DATE;
    v_xp INT;
    v_racha_tipo TEXT;
    v_tipo_desafio TEXT;
    v_tema_id UUID;
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

        -- Bloque de GYM real (con su hora ya programada) -> avanza la ruta de calistenia.
        IF NEW.tipo = 'GYM' AND NEW.ejercicio_gym_id IS NOT NULL THEN
            SELECT id INTO v_tema_id FROM tema
            WHERE ejercicio_gym_id = NEW.ejercicio_gym_id AND dominio = 'CALISTENIA' AND activo;
            IF v_tema_id IS NOT NULL THEN
                PERFORM completar_tema(NEW.usuario_id, v_tema_id);
            END IF;
        END IF;

        INSERT INTO registro_sesion (usuario_id, tipo, actividad_programada_id, titulo, fecha, duracion_real_min)
        VALUES (NEW.usuario_id,
                CASE WHEN NEW.tipo IN ('FUTBOL','GYM','ESTUDIO') THEN NEW.tipo ELSE 'HABITO' END,
                NEW.id, NEW.titulo, v_fecha, NEW.duracion_min);
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
