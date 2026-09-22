-- ============================================================
-- V4: nutrición. Semilla básica de alimentos (macros por 100g) +
-- registro real de comidas/hidratación. Open Food Facts se usa
-- desde el backend para ampliar el catálogo (sin API key).
-- ============================================================

CREATE TABLE IF NOT EXISTS alimento (
    id SERIAL PRIMARY KEY,
    nombre TEXT NOT NULL,
    categoria TEXT NOT NULL CHECK (categoria IN ('PROTEINA','CARBOHIDRATO','GRASA','FRUTA','VERDURA','LACTEO','OTRO')),
    kcal_100g NUMERIC(6,2) NOT NULL,
    proteina_100g NUMERIC(6,2) NOT NULL DEFAULT 0,
    carbos_100g NUMERIC(6,2) NOT NULL DEFAULT 0,
    grasa_100g NUMERIC(6,2) NOT NULL DEFAULT 0,
    fuente TEXT NOT NULL DEFAULT 'SEED',
    codigo_barras TEXT UNIQUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_alimento_nombre ON alimento USING gin (to_tsvector('spanish', nombre));

INSERT INTO alimento (nombre, categoria, kcal_100g, proteina_100g, carbos_100g, grasa_100g) VALUES
 ('Pechuga de pollo','PROTEINA',165,31,0,3.6),
 ('Huevo entero','PROTEINA',155,13,1.1,11),
 ('Atún en agua','PROTEINA',116,26,0,1),
 ('Lentejas cocidas','PROTEINA',116,9,20,0.4),
 ('Arroz blanco cocido','CARBOHIDRATO',130,2.7,28,0.3),
 ('Avena en hojuelas','CARBOHIDRATO',389,17,66,7),
 ('Pan integral','CARBOHIDRATO',247,13,41,4.2),
 ('Papa cocida','CARBOHIDRATO',87,2,20,0.1),
 ('Banano','FRUTA',89,1.1,23,0.3),
 ('Manzana','FRUTA',52,0.3,14,0.2),
 ('Espinaca','VERDURA',23,2.9,3.6,0.4),
 ('Brócoli','VERDURA',34,2.8,7,0.4),
 ('Aguacate','GRASA',160,2,9,15),
 ('Aceite de oliva','GRASA',884,0,0,100),
 ('Leche entera','LACTEO',61,3.2,4.8,3.3),
 ('Yogur griego natural','LACTEO',59,10,3.6,0.4),
 ('Almendras','GRASA',579,21,22,50),
 ('Frijoles negros cocidos','PROTEINA',132,8.9,24,0.5)
ON CONFLICT DO NOTHING;

CREATE TABLE IF NOT EXISTS plan_comida (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    usuario_id UUID NOT NULL REFERENCES usuario(id) ON DELETE CASCADE,
    fecha DATE NOT NULL,
    tipo TEXT NOT NULL CHECK (tipo IN ('DESAYUNO','ALMUERZO','CENA','SNACK')),
    hora_sugerida TIME,
    kcal_objetivo NUMERIC(6,2),
    proteina_objetivo NUMERIC(6,2),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (usuario_id, fecha, tipo)
);

CREATE TABLE IF NOT EXISTS registro_comida (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    usuario_id UUID NOT NULL REFERENCES usuario(id) ON DELETE CASCADE,
    plan_comida_id UUID REFERENCES plan_comida(id) ON DELETE SET NULL,
    fecha DATE NOT NULL DEFAULT CURRENT_DATE,
    tipo TEXT NOT NULL CHECK (tipo IN ('DESAYUNO','ALMUERZO','CENA','SNACK')),
    alimento_id INTEGER REFERENCES alimento(id),
    descripcion_libre TEXT,
    gramos NUMERIC(7,2),
    kcal NUMERIC(6,2) NOT NULL,
    proteina NUMERIC(6,2) NOT NULL DEFAULT 0,
    carbos NUMERIC(6,2) NOT NULL DEFAULT 0,
    grasa NUMERIC(6,2) NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_registro_comida_usuario_fecha ON registro_comida(usuario_id, fecha DESC);

CREATE TABLE IF NOT EXISTS registro_hidratacion (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    usuario_id UUID NOT NULL REFERENCES usuario(id) ON DELETE CASCADE,
    fecha DATE NOT NULL DEFAULT CURRENT_DATE,
    ml INTEGER NOT NULL CHECK (ml > 0),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_hidratacion_usuario_fecha ON registro_hidratacion(usuario_id, fecha DESC);

-- ---------- vista: resumen nutricional del día ----------
CREATE OR REPLACE VIEW vw_nutricion_diaria AS
SELECT
    usuario_id, fecha,
    COALESCE(SUM(kcal), 0) AS kcal_total,
    COALESCE(SUM(proteina), 0) AS proteina_total,
    COALESCE(SUM(carbos), 0) AS carbos_total,
    COALESCE(SUM(grasa), 0) AS grasa_total,
    COUNT(*) AS comidas_registradas
FROM registro_comida
GROUP BY usuario_id, fecha;

-- ---------- objetivo calórico estimado por perfil (Mifflin-St Jeor simplificado) ----------
CREATE OR REPLACE FUNCTION calcular_objetivo_calorico(p_usuario_id UUID)
RETURNS NUMERIC AS $$
DECLARE
    v_peso NUMERIC; v_altura NUMERIC; v_edad INT; v_tmb NUMERIC; v_intensidad TEXT; v_factor NUMERIC;
BEGIN
    SELECT pp.peso_kg, pp.altura_cm, EXTRACT(YEAR FROM AGE(pp.fecha_nacimiento))::INT
        INTO v_peso, v_altura, v_edad
    FROM perfil_personal pp WHERE pp.usuario_id = p_usuario_id;

    IF v_peso IS NULL OR v_altura IS NULL THEN
        RETURN NULL; -- datos insuficientes: el cliente debe pedirlos, no inventamos
    END IF;
    v_edad := COALESCE(v_edad, 25);

    -- Mifflin-St Jeor (estimación masculina por defecto; ajustable si se agrega sexo al perfil)
    v_tmb := (10 * v_peso) + (6.25 * v_altura) - (5 * v_edad) + 5;

    SELECT intensidad INTO v_intensidad FROM usuario WHERE id = p_usuario_id;
    v_factor := CASE v_intensidad WHEN 'INTENSA' THEN 1.75 WHEN 'INTERMEDIA' THEN 1.55 ELSE 1.35 END;

    RETURN ROUND(v_tmb * COALESCE(v_factor, 1.35));
END;
$$ LANGUAGE plpgsql STABLE;
