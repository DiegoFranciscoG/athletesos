-- ============================================================
-- V17: motor generico de "ruta de aprendizaje" -- temas y subtemas
-- bloqueados hasta completar el anterior, de facil a dificil. Es
-- deliberadamente generico (columna `dominio`) para que AJEDREZ,
-- BOXEO, KARATE, CALISTENIA y las materias universitarias (CONOCIMIENTO)
-- reutilicen la MISMA tabla y las MISMAS 2 funciones, en vez de
-- reescribir la logica de desbloqueo una vez por modulo.
--
-- Jerarquia de 2 niveles: tema raiz (padre_id NULL, categoria, sin
-- contenido propio) -> subtemas (contenido real, completables). Al
-- completar el ultimo subtema de un tema, el tema se marca completado
-- y se desbloquea el primer subtema del siguiente tema del dominio.
--
-- Esta ronda solo se siembra CALISTENIA, reutilizando el catalogo
-- ejercicio_gym YA verificado y deduplicado (V16) -- no se inventa
-- contenido nuevo de ajedrez/boxeo/karate sin fuente confiable.
-- ============================================================

CREATE TABLE IF NOT EXISTS tema (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    dominio TEXT NOT NULL CHECK (dominio IN ('CALISTENIA','AJEDREZ','BOXEO','KARATE','CONOCIMIENTO')),
    padre_id UUID REFERENCES tema(id) ON DELETE CASCADE,
    codigo TEXT NOT NULL UNIQUE,
    nombre TEXT NOT NULL,
    descripcion TEXT NOT NULL,
    orden SMALLINT NOT NULL,
    nivel_dificultad SMALLINT NOT NULL CHECK (nivel_dificultad BETWEEN 1 AND 5),
    video_url TEXT,
    video_titulo TEXT,
    contenido TEXT,
    fuente_url TEXT NOT NULL,
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (dominio, padre_id, orden)
);
CREATE INDEX IF NOT EXISTS idx_tema_dominio_padre ON tema(dominio, padre_id, orden);

CREATE TABLE IF NOT EXISTS usuario_tema_progreso (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    usuario_id UUID NOT NULL REFERENCES usuario(id) ON DELETE CASCADE,
    tema_id UUID NOT NULL REFERENCES tema(id) ON DELETE CASCADE,
    estado TEXT NOT NULL DEFAULT 'BLOQUEADO' CHECK (estado IN ('BLOQUEADO','DISPONIBLE','EN_PROGRESO','COMPLETADO')),
    completado_en TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (usuario_id, tema_id)
);
CREATE INDEX IF NOT EXISTS idx_utp_usuario ON usuario_tema_progreso(usuario_id, tema_id);

DROP TRIGGER IF EXISTS trg_utp_updated_at ON usuario_tema_progreso;
CREATE TRIGGER trg_utp_updated_at
    BEFORE UPDATE ON usuario_tema_progreso
    FOR EACH ROW EXECUTE FUNCTION fn_set_updated_at();

-- ============================================================
-- obtener_ruta_aprendizaje: arbol completo de un dominio con el
-- estado de desbloqueo REAL de ese usuario. Si el usuario nunca
-- interactuo con este dominio, bootstrapea: primer subtema de cada
-- tema raiz = DISPONIBLE, el resto BLOQUEADO.
-- ============================================================
CREATE OR REPLACE FUNCTION obtener_ruta_aprendizaje(p_usuario_id UUID, p_dominio TEXT)
RETURNS TABLE(
    tema_id UUID, padre_id UUID, codigo TEXT, nombre TEXT, descripcion TEXT,
    orden SMALLINT, nivel_dificultad SMALLINT, video_url TEXT, video_titulo TEXT,
    contenido TEXT, fuente_url TEXT, es_subtema BOOLEAN, estado TEXT
) AS $$
BEGIN
    -- Bootstrap: crea filas BLOQUEADO para cualquier tema de este dominio que el usuario aun no tenga.
    INSERT INTO usuario_tema_progreso (usuario_id, tema_id, estado)
    SELECT p_usuario_id, t.id, 'BLOQUEADO'
    FROM tema t
    WHERE t.dominio = p_dominio AND t.activo
      AND NOT EXISTS (SELECT 1 FROM usuario_tema_progreso up WHERE up.usuario_id = p_usuario_id AND up.tema_id = t.id)
    ON CONFLICT (usuario_id, tema_id) DO NOTHING;

    -- El primer subtema de cada tema raiz arranca DISPONIBLE (si sigue BLOQUEADO desde el bootstrap).
    UPDATE usuario_tema_progreso up
    SET estado = 'DISPONIBLE'
    FROM tema t
    WHERE up.tema_id = t.id AND up.usuario_id = p_usuario_id AND t.dominio = p_dominio
      AND up.estado = 'BLOQUEADO'
      AND t.padre_id IN (SELECT id FROM tema WHERE dominio = p_dominio AND padre_id IS NULL AND orden = 1)
      AND t.orden = 1;

    RETURN QUERY
    SELECT t.id, t.padre_id, t.codigo, t.nombre, t.descripcion, t.orden, t.nivel_dificultad,
           t.video_url, t.video_titulo, t.contenido, t.fuente_url,
           (t.padre_id IS NOT NULL), COALESCE(up.estado, 'BLOQUEADO')
    FROM tema t
    LEFT JOIN usuario_tema_progreso up ON up.tema_id = t.id AND up.usuario_id = p_usuario_id
    WHERE t.dominio = p_dominio AND t.activo
    ORDER BY t.padre_id NULLS FIRST, t.orden;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- completar_tema: marca un subtema como COMPLETADO y desbloquea lo
-- que corresponda (siguiente subtema del mismo tema, o si era el
-- ultimo, el tema padre se completa y se desbloquea el primer
-- subtema del siguiente tema del dominio).
-- ============================================================
CREATE OR REPLACE FUNCTION completar_tema(p_usuario_id UUID, p_tema_id UUID)
RETURNS TEXT AS $$
DECLARE
    v_dominio TEXT; v_padre_id UUID; v_orden SMALLINT;
    v_siguiente_subtema_id UUID;
    v_quedan_pendientes INT;
    v_tema_padre_id UUID;
    v_siguiente_tema_padre_id UUID;
    v_primer_subtema_siguiente UUID;
BEGIN
    SELECT dominio, padre_id, orden INTO v_dominio, v_padre_id, v_orden FROM tema WHERE id = p_tema_id;
    IF v_dominio IS NULL THEN
        RAISE EXCEPTION 'Tema % no encontrado', p_tema_id;
    END IF;

    INSERT INTO usuario_tema_progreso (usuario_id, tema_id, estado, completado_en)
    VALUES (p_usuario_id, p_tema_id, 'COMPLETADO', now())
    ON CONFLICT (usuario_id, tema_id) DO UPDATE SET estado = 'COMPLETADO', completado_en = now();

    IF v_padre_id IS NULL THEN
        RETURN 'COMPLETADO';  -- un tema raiz sin subtemas se completa directo, sin cascada.
    END IF;

    -- Desbloquea el siguiente subtema hermano (mismo padre, siguiente orden).
    SELECT id INTO v_siguiente_subtema_id FROM tema
    WHERE padre_id = v_padre_id AND orden = v_orden + 1 AND activo;

    IF v_siguiente_subtema_id IS NOT NULL THEN
        INSERT INTO usuario_tema_progreso (usuario_id, tema_id, estado)
        VALUES (p_usuario_id, v_siguiente_subtema_id, 'DISPONIBLE')
        ON CONFLICT (usuario_id, tema_id) DO UPDATE
            SET estado = 'DISPONIBLE' WHERE usuario_tema_progreso.estado = 'BLOQUEADO';
        RETURN 'SIGUIENTE_SUBTEMA_DESBLOQUEADO';
    END IF;

    -- Era el ultimo subtema: completar el tema padre y saltar al siguiente tema del dominio.
    SELECT COUNT(*) INTO v_quedan_pendientes FROM tema t
    LEFT JOIN usuario_tema_progreso up ON up.tema_id = t.id AND up.usuario_id = p_usuario_id
    WHERE t.padre_id = v_padre_id AND t.activo AND COALESCE(up.estado, 'BLOQUEADO') != 'COMPLETADO';

    IF v_quedan_pendientes > 0 THEN
        RETURN 'SUBTEMA_COMPLETADO';
    END IF;

    INSERT INTO usuario_tema_progreso (usuario_id, tema_id, estado, completado_en)
    VALUES (p_usuario_id, v_padre_id, 'COMPLETADO', now())
    ON CONFLICT (usuario_id, tema_id) DO UPDATE SET estado = 'COMPLETADO', completado_en = now();

    SELECT orden INTO v_orden FROM tema WHERE id = v_padre_id;
    SELECT id INTO v_siguiente_tema_padre_id FROM tema
    WHERE dominio = v_dominio AND padre_id IS NULL AND orden = v_orden + 1 AND activo;

    IF v_siguiente_tema_padre_id IS NOT NULL THEN
        SELECT id INTO v_primer_subtema_siguiente FROM tema
        WHERE padre_id = v_siguiente_tema_padre_id AND orden = 1 AND activo;
        IF v_primer_subtema_siguiente IS NOT NULL THEN
            INSERT INTO usuario_tema_progreso (usuario_id, tema_id, estado)
            VALUES (p_usuario_id, v_primer_subtema_siguiente, 'DISPONIBLE')
            ON CONFLICT (usuario_id, tema_id) DO UPDATE
                SET estado = 'DISPONIBLE' WHERE usuario_tema_progreso.estado = 'BLOQUEADO';
        END IF;
        RETURN 'TEMA_COMPLETADO_SIGUIENTE_DESBLOQUEADO';
    END IF;

    RETURN 'DOMINIO_COMPLETADO';
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- Semilla CALISTENIA: reutiliza ejercicio_gym (ya real y
-- deduplicado), agrupado por grupo_muscular, ordenado por
-- dificultad -- fuente_url apunta al propio catalogo interno
-- porque ya paso por verificacion antes (V2/V10).
-- ============================================================
DO $$
DECLARE
    v_grupo TEXT;
    v_grupo_nombre TEXT;
    v_tema_padre_id UUID;
    v_orden_padre SMALLINT := 0;
    v_orden_hijo SMALLINT;
    v_ej RECORD;
BEGIN
    FOR v_grupo, v_grupo_nombre IN
        SELECT * FROM (VALUES
            ('PIERNA','Piernas'), ('GLUTEO','Glúteos'), ('CORE','Core'),
            ('EMPUJE','Empuje'), ('TRACCION','Tracción'), ('MOVILIDAD','Movilidad')
        ) AS g(codigo, nombre)
    LOOP
        v_orden_padre := v_orden_padre + 1;
        INSERT INTO tema (dominio, padre_id, codigo, nombre, descripcion, orden, nivel_dificultad, fuente_url)
        VALUES ('CALISTENIA', NULL, 'calistenia_' || lower(v_grupo), v_grupo_nombre,
                'Progresión de ' || lower(v_grupo_nombre) || ' con el propio peso corporal, de más fácil a más difícil.',
                v_orden_padre, 1, 'Catálogo interno AthletesOS (ejercicio_gym, verificado en V2/V10)')
        ON CONFLICT (dominio, padre_id, orden) DO NOTHING
        RETURNING id INTO v_tema_padre_id;

        IF v_tema_padre_id IS NULL THEN
            SELECT id INTO v_tema_padre_id FROM tema WHERE dominio = 'CALISTENIA' AND padre_id IS NULL AND orden = v_orden_padre;
        END IF;

        v_orden_hijo := 0;
        FOR v_ej IN
            SELECT id, nombre, descripcion, dificultad, video_url, video_titulo, instrucciones
            FROM ejercicio_gym WHERE grupo_muscular = v_grupo AND activo ORDER BY dificultad, nombre
        LOOP
            v_orden_hijo := v_orden_hijo + 1;
            INSERT INTO tema (dominio, padre_id, codigo, nombre, descripcion, orden, nivel_dificultad,
                               video_url, video_titulo, contenido, fuente_url)
            VALUES ('CALISTENIA', v_tema_padre_id, 'calistenia_' || lower(v_grupo) || '_' || v_orden_hijo,
                    v_ej.nombre, v_ej.descripcion, v_orden_hijo, v_ej.dificultad,
                    v_ej.video_url, v_ej.video_titulo, v_ej.instrucciones,
                    'Catálogo interno AthletesOS (ejercicio_gym id=' || v_ej.id || ')')
            ON CONFLICT (dominio, padre_id, orden) DO NOTHING;
        END LOOP;
    END LOOP;
END $$;
