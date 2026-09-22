-- ============================================================
-- V25: configuración de notificaciones tácticas (agua, pre-entreno,
-- desconexión) + meta de hidratación dinámica real, en reemplazo del
-- 2500 ml quemado que tenía NutritionController.
--
-- Fuentes (ver docs/investigacion.md):
--  - National Academies (IOM), Dietary Reference Intakes for Water:
--    ingesta adecuada ~3.7 L/día en hombres, ~80% desde bebida -> ~3.0 L base.
--  - ACSM Position Stand, Exercise and Fluid Replacement: 600-1200 ml/hora
--    de ejercicio intenso; se usa el punto medio (900 ml/h) como bono por
--    sesión de fútbol/gym programada ese día.
-- ============================================================

CREATE TABLE IF NOT EXISTS configuracion_notificacion (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    usuario_id UUID NOT NULL REFERENCES usuario(id) ON DELETE CASCADE,
    categoria TEXT NOT NULL CHECK (categoria IN ('AGUA','PRE_ENTRENO','DESCONEXION')),
    activa BOOLEAN NOT NULL DEFAULT TRUE,
    tipo TEXT NOT NULL CHECK (tipo IN ('INTERVALO','HORA_FIJA')),
    hora_inicio TIME,       -- solo INTERVALO: inicio de la ventana (ej. 08:00)
    hora_fin TIME,          -- solo INTERVALO: fin de la ventana (ej. 22:00)
    intervalo_min SMALLINT, -- solo INTERVALO: cada cuánto (ej. 60)
    hora_fija TIME,         -- solo HORA_FIJA: ej. 21:30 para desconexión
    minutos_antes SMALLINT, -- solo PRE_ENTRENO: aviso antes de la sesión (ej. 15)
    vibracion BOOLEAN NOT NULL DEFAULT TRUE,
    sonido BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (usuario_id, categoria)
);

-- ---------- meta de hidratación dinámica ----------
CREATE OR REPLACE FUNCTION obtener_meta_hidratacion_ml(p_usuario_id UUID, p_fecha DATE DEFAULT CURRENT_DATE)
RETURNS INTEGER AS $$
DECLARE
    v_base INTEGER := 3000; -- National Academies: hombres ~3.7 L/día total, ~80% desde bebida
    v_bono NUMERIC := 0;
BEGIN
    SELECT COALESCE(SUM(ap.duracion_min / 60.0 * 900), 0) INTO v_bono
    FROM actividad_programada ap
    JOIN dia_programa dp ON dp.id = ap.dia_programa_id
    WHERE ap.usuario_id = p_usuario_id AND dp.fecha = p_fecha AND ap.tipo IN ('FUTBOL','GYM');

    RETURN v_base + ROUND(v_bono);
END;
$$ LANGUAGE plpgsql STABLE;

-- ---------- seed de configuración por defecto para usuarios ya existentes ----------
-- (a futuro: enganchar esto a completar_onboarding() para usuarios nuevos;
-- por ahora se deja explícito para no tocar ese flujo real que ya funciona)
INSERT INTO configuracion_notificacion (usuario_id, categoria, tipo, hora_inicio, hora_fin, intervalo_min, vibracion, sonido)
SELECT id, 'AGUA', 'INTERVALO', '08:00', '22:00', 60, TRUE, TRUE FROM usuario
ON CONFLICT (usuario_id, categoria) DO NOTHING;

INSERT INTO configuracion_notificacion (usuario_id, categoria, tipo, minutos_antes, vibracion, sonido)
SELECT id, 'PRE_ENTRENO', 'HORA_FIJA', 15, TRUE, TRUE FROM usuario
ON CONFLICT (usuario_id, categoria) DO NOTHING;

INSERT INTO configuracion_notificacion (usuario_id, categoria, tipo, hora_fija, vibracion, sonido)
SELECT id, 'DESCONEXION', 'HORA_FIJA', '21:30', TRUE, FALSE FROM usuario
ON CONFLICT (usuario_id, categoria) DO NOTHING;
