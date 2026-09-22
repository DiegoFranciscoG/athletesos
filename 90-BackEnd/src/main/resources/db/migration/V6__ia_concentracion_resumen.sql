-- ============================================================
-- V6: chat de IA, sesiones de concentración, motor determinista
-- de adaptación diaria, resumen semanal y vista de dashboard.
-- ============================================================

CREATE TABLE IF NOT EXISTS conversacion_ia (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    usuario_id UUID NOT NULL REFERENCES usuario(id) ON DELETE CASCADE,
    titulo TEXT NOT NULL DEFAULT 'Cockpit AI',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS mensaje_ia (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    conversacion_id UUID NOT NULL REFERENCES conversacion_ia(id) ON DELETE CASCADE,
    usuario_id UUID NOT NULL REFERENCES usuario(id) ON DELETE CASCADE,
    rol TEXT NOT NULL CHECK (rol IN ('user','assistant')),
    contenido TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_mensaje_ia_conversacion ON mensaje_ia(conversacion_id, created_at);

CREATE TABLE IF NOT EXISTS recomendacion_ia (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    usuario_id UUID NOT NULL REFERENCES usuario(id) ON DELETE CASCADE,
    tipo TEXT NOT NULL,
    contenido JSONB NOT NULL,
    aplicada BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS patron_detectado (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    usuario_id UUID NOT NULL REFERENCES usuario(id) ON DELETE CASCADE,
    tipo TEXT NOT NULL,
    descripcion TEXT NOT NULL,
    evidencia JSONB,
    confianza NUMERIC(4,2),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS sesion_concentracion (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    usuario_id UUID NOT NULL REFERENCES usuario(id) ON DELETE CASCADE,
    actividad_programada_id UUID REFERENCES actividad_programada(id) ON DELETE SET NULL,
    mision_titulo TEXT NOT NULL,
    nivel_blindaje TEXT NOT NULL DEFAULT 'MODERADO' CHECK (nivel_blindaje IN ('SUAVE','MODERADO','ESTRICTO')),
    duracion_objetivo_min INT NOT NULL,
    duracion_real_min INT,
    apps_permitidas JSONB NOT NULL DEFAULT '[]'::jsonb,
    apps_bloqueadas JSONB NOT NULL DEFAULT '[]'::jsonb,
    desviaciones INT NOT NULL DEFAULT 0,
    notas_mentales JSONB NOT NULL DEFAULT '[]'::jsonb,
    completada BOOLEAN NOT NULL DEFAULT FALSE,
    fecha_inicio TIMESTAMPTZ NOT NULL DEFAULT now(),
    fecha_fin TIMESTAMPTZ
);
CREATE INDEX IF NOT EXISTS idx_sesion_concentracion_usuario ON sesion_concentracion(usuario_id, fecha_inicio DESC);

-- ============================================================
-- evaluar_dia_usuario: motor determinista de recomendación de carga.
-- La IA interpreta esto, no lo reemplaza.
-- ============================================================
CREATE OR REPLACE FUNCTION evaluar_dia_usuario(p_usuario_id UUID, p_fecha DATE)
RETURNS JSONB AS $$
DECLARE
    v_energia SMALLINT; v_fatiga SMALLINT; v_estres SMALLINT; v_horas_sueno NUMERIC;
    v_nivel_carga TEXT; v_motivo TEXT;
BEGIN
    SELECT energia, fatiga, estres, horas_sueno INTO v_energia, v_fatiga, v_estres, v_horas_sueno
    FROM estado_diario WHERE usuario_id = p_usuario_id AND fecha = p_fecha;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('nivel_carga', 'NORMAL', 'motivo', 'Sin registro de estado diario todavía.');
    END IF;

    IF (v_horas_sueno IS NOT NULL AND v_horas_sueno < 6) OR (v_fatiga IS NOT NULL AND v_fatiga >= 8) THEN
        v_nivel_carga := 'REDUCIR';
        v_motivo := format('Sueño %.1fh y fatiga %s/10: se reduce el volumen de hoy para evitar sobreentrenamiento.',
                            COALESCE(v_horas_sueno, 0), COALESCE(v_fatiga, 0));
    ELSIF (v_energia IS NOT NULL AND v_energia >= 8) AND (v_fatiga IS NULL OR v_fatiga <= 3) THEN
        v_nivel_carga := 'AUMENTAR';
        v_motivo := format('Energía alta (%s/10) y fatiga baja: hay margen para más intensidad hoy.', v_energia);
    ELSE
        v_nivel_carga := 'NORMAL';
        v_motivo := 'Estado dentro de rango normal, se mantiene el plan tal cual.';
    END IF;

    RETURN jsonb_build_object(
        'nivel_carga', v_nivel_carga, 'motivo', v_motivo,
        'energia', v_energia, 'fatiga', v_fatiga, 'estres', v_estres, 'horas_sueno', v_horas_sueno
    );
END;
$$ LANGUAGE plpgsql STABLE;

-- ============================================================
-- generar_resumen_semanal: % de cumplimiento por tipo en una semana.
-- ============================================================
CREATE OR REPLACE FUNCTION generar_resumen_semanal(p_usuario_id UUID, p_semana_id UUID)
RETURNS JSONB AS $$
DECLARE
    v_resultado JSONB;
BEGIN
    SELECT jsonb_object_agg(tipo, pct) INTO v_resultado
    FROM (
        SELECT ap.tipo,
               ROUND(100.0 * COUNT(*) FILTER (WHERE ap.estado = 'COMPLETADA') / NULLIF(COUNT(*), 0)) AS pct
        FROM actividad_programada ap
        JOIN dia_programa dp ON dp.id = ap.dia_programa_id
        WHERE ap.usuario_id = p_usuario_id AND dp.semana_id = p_semana_id
        GROUP BY ap.tipo
    ) t;

    RETURN COALESCE(v_resultado, '{}'::jsonb);
END;
$$ LANGUAGE plpgsql STABLE;

-- ============================================================
-- vw_dashboard_usuario: progreso del programa activo, hoy.
-- ============================================================
CREATE OR REPLACE VIEW vw_dashboard_usuario AS
SELECT
    u.id AS usuario_id,
    p.id AS programa_id,
    p.intensidad,
    p.nivel_habilidad,
    dp.numero_dia,
    fp.numero AS fase_numero,
    fp.nombre AS fase_nombre,
    fp.objetivo AS fase_objetivo,
    ROUND(100.0 * (dp.numero_dia - fp.dia_inicio + 1) / (fp.dia_fin - fp.dia_inicio + 1)) AS fase_progreso_pct,
    ROUND(100.0 * dp.numero_dia / 90) AS programa_progreso_pct,
    (SELECT COUNT(*) FROM actividad_programada a WHERE a.dia_programa_id = dp.id) AS actividades_hoy_total,
    (SELECT COUNT(*) FROM actividad_programada a WHERE a.dia_programa_id = dp.id AND a.estado = 'COMPLETADA') AS actividades_hoy_completadas
FROM usuario u
JOIN programa_90_dias p ON p.usuario_id = u.id AND p.activo
JOIN dia_programa dp ON dp.programa_id = p.id AND dp.fecha = CURRENT_DATE
JOIN fase_programa fp ON fp.id = dp.fase_id;

CREATE OR REPLACE VIEW vw_resumen_hidratacion_hoy AS
SELECT usuario_id, COALESCE(SUM(ml), 0) AS ml_total
FROM registro_hidratacion WHERE fecha = CURRENT_DATE GROUP BY usuario_id;
