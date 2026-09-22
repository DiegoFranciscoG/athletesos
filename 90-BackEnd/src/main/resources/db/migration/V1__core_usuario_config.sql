-- ============================================================
-- V1: usuario extendido + configuración de nivel/intensidad
-- Todo dato de negocio (roles, config del motor de planes) vive
-- aquí, no en Dart/Java. Idempotente: usa IF NOT EXISTS / ON CONFLICT.
-- ============================================================

-- ---------- función utilitaria: updated_at automático ----------
CREATE OR REPLACE FUNCTION fn_set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ---------- auditoría genérica ----------
CREATE TABLE IF NOT EXISTS auditoria (
    id BIGSERIAL PRIMARY KEY,
    usuario_id UUID,
    tabla TEXT NOT NULL,
    operacion TEXT NOT NULL CHECK (operacion IN ('INSERT','UPDATE','DELETE')),
    registro_id TEXT,
    detalle JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_auditoria_usuario ON auditoria(usuario_id, created_at DESC);

CREATE OR REPLACE FUNCTION fn_auditar_cambio()
RETURNS TRIGGER AS $$
DECLARE
    v_usuario_id UUID;
BEGIN
    BEGIN
        v_usuario_id := COALESCE(NEW.usuario_id, OLD.usuario_id);
    EXCEPTION WHEN undefined_column THEN
        v_usuario_id := NULL;
    END;

    INSERT INTO auditoria(usuario_id, tabla, operacion, registro_id, detalle)
    VALUES (
        v_usuario_id,
        TG_TABLE_NAME,
        TG_OP,
        COALESCE((to_jsonb(COALESCE(NEW, OLD))->>'id'), NULL),
        to_jsonb(COALESCE(NEW, OLD))
    );
    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

-- ---------- usuario: roles, nivel de habilidad, intensidad ----------
ALTER TABLE usuario
    ADD COLUMN IF NOT EXISTS rol TEXT NOT NULL DEFAULT 'ATLETA'
        CHECK (rol IN ('ATLETA', 'ADMIN')),
    ADD COLUMN IF NOT EXISTS nivel_habilidad TEXT
        CHECK (nivel_habilidad IN ('PRINCIPIANTE', 'INTERMEDIO', 'PROFESIONAL')),
    ADD COLUMN IF NOT EXISTS intensidad TEXT
        CHECK (intensidad IN ('NORMAL', 'INTERMEDIA', 'INTENSA')),
    ADD COLUMN IF NOT EXISTS onboarding_completado BOOLEAN NOT NULL DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS zona_horaria TEXT NOT NULL DEFAULT 'America/Mexico_City',
    ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT now();

DROP TRIGGER IF EXISTS trg_usuario_updated_at ON usuario;
CREATE TRIGGER trg_usuario_updated_at
    BEFORE UPDATE ON usuario
    FOR EACH ROW EXECUTE FUNCTION fn_set_updated_at();

DROP TRIGGER IF EXISTS trg_usuario_auditoria ON usuario;
CREATE TRIGGER trg_usuario_auditoria
    AFTER UPDATE ON usuario
    FOR EACH ROW EXECUTE FUNCTION fn_auditar_cambio();

-- ---------- objetivo_usuario ----------
CREATE TABLE IF NOT EXISTS objetivo_usuario (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    usuario_id UUID NOT NULL REFERENCES usuario(id) ON DELETE CASCADE,
    area TEXT NOT NULL CHECK (area IN ('FUTBOL','FISICO','ESTUDIO','NUTRICION','SUENO','PANTALLA')),
    descripcion TEXT NOT NULL,
    prioridad SMALLINT NOT NULL DEFAULT 3 CHECK (prioridad BETWEEN 1 AND 5),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (usuario_id, area)
);
CREATE INDEX IF NOT EXISTS idx_objetivo_usuario ON objetivo_usuario(usuario_id);

-- ---------- onboarding_respuesta: guarda el test crudo ----------
CREATE TABLE IF NOT EXISTS onboarding_respuesta (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    usuario_id UUID NOT NULL REFERENCES usuario(id) ON DELETE CASCADE,
    respuestas JSONB NOT NULL,
    puntaje_total INTEGER NOT NULL,
    nivel_calculado TEXT NOT NULL CHECK (nivel_calculado IN ('PRINCIPIANTE','INTERMEDIO','PROFESIONAL')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_onboarding_usuario ON onboarding_respuesta(usuario_id);

-- ---------- config_nivel: dificultad/progresión por nivel de habilidad ----------
CREATE TABLE IF NOT EXISTS config_nivel (
    id SERIAL PRIMARY KEY,
    nivel TEXT NOT NULL CHECK (nivel IN ('PRINCIPIANTE','INTERMEDIO','PROFESIONAL')),
    area TEXT NOT NULL CHECK (area IN ('FUTBOL','GYM')),
    dificultad_max SMALLINT NOT NULL CHECK (dificultad_max BETWEEN 1 AND 5),
    progresion_semanal_pct NUMERIC(5,2) NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (nivel, area)
);

DROP TRIGGER IF EXISTS trg_config_nivel_updated_at ON config_nivel;
CREATE TRIGGER trg_config_nivel_updated_at
    BEFORE UPDATE ON config_nivel
    FOR EACH ROW EXECUTE FUNCTION fn_set_updated_at();

INSERT INTO config_nivel (nivel, area, dificultad_max, progresion_semanal_pct) VALUES
    ('PRINCIPIANTE', 'FUTBOL', 2, 3.0),
    ('INTERMEDIO',   'FUTBOL', 4, 5.0),
    ('PROFESIONAL',  'FUTBOL', 5, 8.0),
    ('PRINCIPIANTE', 'GYM',    2, 3.0),
    ('INTERMEDIO',   'GYM',    4, 5.0),
    ('PROFESIONAL',  'GYM',    5, 8.0)
ON CONFLICT (nivel, area) DO NOTHING;

-- ---------- config_intensidad: volumen/frecuencia por dial de intensidad ----------
CREATE TABLE IF NOT EXISTS config_intensidad (
    id SERIAL PRIMARY KEY,
    intensidad TEXT NOT NULL CHECK (intensidad IN ('NORMAL','INTERMEDIA','INTENSA')),
    area TEXT NOT NULL CHECK (area IN ('FUTBOL','GYM','ESTUDIO','HABITOS')),
    sesiones_semana SMALLINT NOT NULL CHECK (sesiones_semana BETWEEN 0 AND 7),
    duracion_min SMALLINT NOT NULL,
    series_base SMALLINT NOT NULL DEFAULT 0,
    repeticiones_base SMALLINT NOT NULL DEFAULT 0,
    descanso_seg SMALLINT NOT NULL DEFAULT 0,
    volumen_pct NUMERIC(5,2) NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (intensidad, area)
);

DROP TRIGGER IF EXISTS trg_config_intensidad_updated_at ON config_intensidad;
CREATE TRIGGER trg_config_intensidad_updated_at
    BEFORE UPDATE ON config_intensidad
    FOR EACH ROW EXECUTE FUNCTION fn_set_updated_at();

INSERT INTO config_intensidad (intensidad, area, sesiones_semana, duracion_min, series_base, repeticiones_base, descanso_seg, volumen_pct) VALUES
    ('NORMAL',      'FUTBOL', 3, 50, 3, 8,  60, 80),
    ('INTERMEDIA',  'FUTBOL', 4, 65, 4, 10, 45, 100),
    ('INTENSA',     'FUTBOL', 5, 80, 5, 12, 30, 120),

    ('NORMAL',      'GYM',    2, 40, 3, 10, 90, 80),
    ('INTERMEDIA',  'GYM',    3, 50, 4, 10, 75, 100),
    ('INTENSA',     'GYM',    4, 60, 5, 8,  60, 120),

    ('NORMAL',      'ESTUDIO',3, 45, 0, 0,  0,  80),
    ('INTERMEDIA',  'ESTUDIO',4, 60, 0, 0,  0,  100),
    ('INTENSA',     'ESTUDIO',5, 75, 0, 0,  0,  120),

    ('NORMAL',      'HABITOS',5, 15, 0, 0,  0,  80),
    ('INTERMEDIA',  'HABITOS',5, 15, 0, 0,  0,  100),
    ('INTENSA',     'HABITOS',5, 20, 0, 0,  0,  120)
ON CONFLICT (intensidad, area) DO NOTHING;
