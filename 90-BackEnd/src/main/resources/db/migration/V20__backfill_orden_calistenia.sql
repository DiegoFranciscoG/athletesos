-- ============================================================
-- V20: el plan real de 90 dias elige el ejercicio de GYM por
-- rotacion (numero_dia % catalogo), no por dificultad -- puede
-- tocar "Sentadilla goblet" (orden 2) un dia antes que "Sentadilla
-- con peso corporal" (orden 1) de la misma categoria. Si eso pasaba,
-- la ruta marcaba orden 2 completado y desbloqueaba orden 3, dejando
-- orden 1 "colgado" sin completar -- rompiendo la secuencia estricta
-- que la propia ruta promete.
--
-- Fix: cuando el enlace automatico completa un subtema, tambien
-- rellena (completar_tema) todos los subtemas anteriores del mismo
-- tema padre que aun no estuvieran completados, en orden ascendente.
-- completar_tema() ya es idempotente, asi que repetirlo no duplica
-- nada ni rompe si ya estaban completos.
-- ============================================================

CREATE OR REPLACE FUNCTION fn_actividad_completada()
RETURNS TRIGGER AS $$
DECLARE
    v_fecha DATE;
    v_xp INT;
    v_racha_tipo TEXT;
    v_tipo_desafio TEXT;
    v_tema_id UUID;
    v_padre_id UUID;
    v_orden_objetivo SMALLINT;
    v_subtema_previo RECORD;
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

        IF NEW.tipo = 'GYM' AND NEW.ejercicio_gym_id IS NOT NULL THEN
            SELECT id, padre_id, orden INTO v_tema_id, v_padre_id, v_orden_objetivo FROM tema
            WHERE ejercicio_gym_id = NEW.ejercicio_gym_id AND dominio = 'CALISTENIA' AND activo;

            IF v_tema_id IS NOT NULL THEN
                FOR v_subtema_previo IN
                    SELECT t.id FROM tema t
                    LEFT JOIN usuario_tema_progreso up ON up.tema_id = t.id AND up.usuario_id = NEW.usuario_id
                    WHERE t.padre_id = v_padre_id AND t.orden < v_orden_objetivo AND t.activo
                      AND COALESCE(up.estado, 'BLOQUEADO') != 'COMPLETADO'
                    ORDER BY t.orden
                LOOP
                    PERFORM completar_tema(NEW.usuario_id, v_subtema_previo.id);
                END LOOP;

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
