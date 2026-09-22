-- ============================================================
-- V5: estado diario, hábitos libres, rachas, XP y desafíos
-- semanales. Las rachas y el XP se calculan con triggers, nunca
-- en Dart/Java, para que sean imposibles de falsear desde el cliente.
-- ============================================================

CREATE TABLE IF NOT EXISTS estado_diario (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    usuario_id UUID NOT NULL REFERENCES usuario(id) ON DELETE CASCADE,
    fecha DATE NOT NULL DEFAULT CURRENT_DATE,
    energia SMALLINT CHECK (energia BETWEEN 1 AND 10),
    fatiga SMALLINT CHECK (fatiga BETWEEN 1 AND 10),
    estres SMALLINT CHECK (estres BETWEEN 1 AND 10),
    horas_sueno NUMERIC(4,2),
    comentario TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (usuario_id, fecha)
);

CREATE TABLE IF NOT EXISTS habito (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    usuario_id UUID NOT NULL REFERENCES usuario(id) ON DELETE CASCADE,
    nombre TEXT NOT NULL,
    tipo TEXT NOT NULL CHECK (tipo IN ('AGUA','SUENO','ESTUDIO','PANTALLA','MOVILIDAD','OTRO')),
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS registro_habito (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    usuario_id UUID NOT NULL REFERENCES usuario(id) ON DELETE CASCADE,
    habito_id UUID NOT NULL REFERENCES habito(id) ON DELETE CASCADE,
    fecha DATE NOT NULL DEFAULT CURRENT_DATE,
    completado BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (habito_id, fecha)
);

CREATE TABLE IF NOT EXISTS racha (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    usuario_id UUID NOT NULL REFERENCES usuario(id) ON DELETE CASCADE,
    tipo TEXT NOT NULL CHECK (tipo IN ('FUTBOL','GYM','ESTUDIO','HABITOS')),
    racha_actual INT NOT NULL DEFAULT 0,
    racha_maxima INT NOT NULL DEFAULT 0,
    ultima_fecha DATE,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (usuario_id, tipo)
);

CREATE TABLE IF NOT EXISTS xp_evento (
    id BIGSERIAL PRIMARY KEY,
    usuario_id UUID NOT NULL REFERENCES usuario(id) ON DELETE CASCADE,
    tipo TEXT NOT NULL,
    xp INT NOT NULL,
    origen_tabla TEXT,
    origen_id TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_xp_evento_usuario ON xp_evento(usuario_id, created_at DESC);

CREATE TABLE IF NOT EXISTS nivel_usuario (
    usuario_id UUID PRIMARY KEY REFERENCES usuario(id) ON DELETE CASCADE,
    xp_total INT NOT NULL DEFAULT 0,
    nivel INT NOT NULL DEFAULT 1,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS desafio (
    id SERIAL PRIMARY KEY,
    codigo TEXT NOT NULL UNIQUE,
    nombre TEXT NOT NULL,
    descripcion TEXT NOT NULL,
    tipo TEXT NOT NULL CHECK (tipo IN ('SESIONES_FUTBOL','SESIONES_GYM','SESIONES_ESTUDIO','HIDRATACION_DIAS','HABITOS_DIAS')),
    meta INT NOT NULL,
    intensidad TEXT NOT NULL CHECK (intensidad IN ('NORMAL','INTERMEDIA','INTENSA')),
    duracion_dias INT NOT NULL DEFAULT 7,
    xp_recompensa INT NOT NULL DEFAULT 50
);

INSERT INTO desafio (codigo, nombre, descripcion, tipo, meta, intensidad, xp_recompensa) VALUES
 ('FUTBOL_3_NORMAL','3 sesiones de fútbol','Completa 3 sesiones de fútbol esta semana.','SESIONES_FUTBOL',3,'NORMAL',60),
 ('FUTBOL_4_INTERMEDIA','4 sesiones de fútbol','Completa 4 sesiones de fútbol esta semana.','SESIONES_FUTBOL',4,'INTERMEDIA',80),
 ('FUTBOL_5_INTENSA','5 sesiones de fútbol','Completa las 5 sesiones de fútbol de la semana.','SESIONES_FUTBOL',5,'INTENSA',100),
 ('ESTUDIO_4_NORMAL','4 sesiones de estudio','Completa 4 sesiones de estudio esta semana.','SESIONES_ESTUDIO',4,'NORMAL',60),
 ('ESTUDIO_5_INTERMEDIA','5 sesiones de estudio','Completa 5 sesiones de estudio esta semana.','SESIONES_ESTUDIO',5,'INTERMEDIA',80),
 ('HIDRATACION_5_NORMAL','5 días de hidratación','Registra tu meta de agua 5 días esta semana.','HIDRATACION_DIAS',5,'NORMAL',40),
 ('HIDRATACION_7_INTENSA','7 días de hidratación','Registra tu meta de agua los 7 días de la semana.','HIDRATACION_DIAS',7,'INTENSA',70)
ON CONFLICT (codigo) DO NOTHING;

CREATE TABLE IF NOT EXISTS desafio_usuario (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    usuario_id UUID NOT NULL REFERENCES usuario(id) ON DELETE CASCADE,
    desafio_id INT NOT NULL REFERENCES desafio(id),
    fecha_inicio DATE NOT NULL DEFAULT CURRENT_DATE,
    fecha_fin DATE NOT NULL,
    progreso INT NOT NULL DEFAULT 0,
    completado BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_desafio_usuario ON desafio_usuario(usuario_id, completado);

-- ============================================================
-- fn_actualizar_racha: upsert de racha con lógica de contigüidad.
-- ============================================================
CREATE OR REPLACE FUNCTION fn_actualizar_racha(p_usuario_id UUID, p_tipo TEXT, p_fecha DATE)
RETURNS VOID AS $$
DECLARE
    v_actual INT; v_maxima INT; v_ultima DATE;
BEGIN
    SELECT racha_actual, racha_maxima, ultima_fecha INTO v_actual, v_maxima, v_ultima
    FROM racha WHERE usuario_id = p_usuario_id AND tipo = p_tipo FOR UPDATE;

    IF NOT FOUND THEN
        INSERT INTO racha (usuario_id, tipo, racha_actual, racha_maxima, ultima_fecha)
        VALUES (p_usuario_id, p_tipo, 1, 1, p_fecha);
        RETURN;
    END IF;

    IF v_ultima = p_fecha THEN
        RETURN; -- ya contado hoy, evita inflar la racha con múltiples eventos el mismo día
    ELSIF v_ultima = p_fecha - 1 THEN
        v_actual := v_actual + 1;
    ELSE
        v_actual := 1; -- se rompió la racha
    END IF;

    v_maxima := GREATEST(v_maxima, v_actual);
    UPDATE racha SET racha_actual = v_actual, racha_maxima = v_maxima, ultima_fecha = p_fecha, updated_at = now()
    WHERE usuario_id = p_usuario_id AND tipo = p_tipo;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- trigger: al completar una actividad_programada -> XP + racha
-- ============================================================
CREATE OR REPLACE FUNCTION fn_actividad_completada()
RETURNS TRIGGER AS $$
DECLARE
    v_fecha DATE;
    v_xp INT;
    v_racha_tipo TEXT;
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

        INSERT INTO registro_sesion (usuario_id, tipo, actividad_programada_id, titulo, fecha, duracion_real_min)
        VALUES (NEW.usuario_id,
                CASE WHEN NEW.tipo IN ('FUTBOL','GYM','ESTUDIO') THEN NEW.tipo ELSE 'HABITO' END,
                NEW.id, NEW.titulo, v_fecha, NEW.duracion_min);
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_actividad_completada ON actividad_programada;
CREATE TRIGGER trg_actividad_completada
    AFTER UPDATE ON actividad_programada
    FOR EACH ROW EXECUTE FUNCTION fn_actividad_completada();

-- ---------- trigger: hábito libre marcado -> racha HABITOS también ----------
CREATE OR REPLACE FUNCTION fn_registro_habito_insertado()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.completado THEN
        PERFORM fn_actualizar_racha(NEW.usuario_id, 'HABITOS', NEW.fecha);
        INSERT INTO xp_evento (usuario_id, tipo, xp, origen_tabla, origen_id)
        VALUES (NEW.usuario_id, 'HABITO', 5, 'registro_habito', NEW.id::TEXT);
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_registro_habito ON registro_habito;
CREATE TRIGGER trg_registro_habito
    AFTER INSERT ON registro_habito
    FOR EACH ROW EXECUTE FUNCTION fn_registro_habito_insertado();

-- ---------- trigger: xp_evento -> recalcular nivel_usuario (500 xp/nivel) ----------
CREATE OR REPLACE FUNCTION fn_recalcular_nivel()
RETURNS TRIGGER AS $$
DECLARE
    v_total INT;
BEGIN
    INSERT INTO nivel_usuario (usuario_id, xp_total, nivel)
    VALUES (NEW.usuario_id, NEW.xp, GREATEST(1, (NEW.xp / 500) + 1))
    ON CONFLICT (usuario_id) DO UPDATE
        SET xp_total = nivel_usuario.xp_total + NEW.xp,
            nivel = GREATEST(1, ((nivel_usuario.xp_total + NEW.xp) / 500) + 1),
            updated_at = now()
    RETURNING xp_total INTO v_total;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_xp_evento ON xp_evento;
CREATE TRIGGER trg_xp_evento
    AFTER INSERT ON xp_evento
    FOR EACH ROW EXECUTE FUNCTION fn_recalcular_nivel();
