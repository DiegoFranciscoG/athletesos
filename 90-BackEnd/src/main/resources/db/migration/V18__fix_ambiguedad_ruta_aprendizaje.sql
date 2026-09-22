-- ============================================================
-- V18: obtener_ruta_aprendizaje() declara una columna de salida
-- llamada tema_id (RETURNS TABLE), que colisiona con la columna real
-- tema_id de usuario_tema_progreso usada sin calificar dentro del
-- propio cuerpo (en el INSERT ... ON CONFLICT (usuario_id, tema_id)).
-- PL/pgSQL no sabe si "tema_id" ahi es la variable de salida o la
-- columna de la tabla -> "column reference tema_id is ambiguous".
-- Fix: #variable_conflict use_column le dice a la funcion que, ante
-- esa ambiguedad, siempre gane la columna real de la consulta.
-- ============================================================

CREATE OR REPLACE FUNCTION obtener_ruta_aprendizaje(p_usuario_id UUID, p_dominio TEXT)
RETURNS TABLE(
    tema_id UUID, padre_id UUID, codigo TEXT, nombre TEXT, descripcion TEXT,
    orden SMALLINT, nivel_dificultad SMALLINT, video_url TEXT, video_titulo TEXT,
    contenido TEXT, fuente_url TEXT, es_subtema BOOLEAN, estado TEXT
) AS $$
#variable_conflict use_column
BEGIN
    INSERT INTO usuario_tema_progreso (usuario_id, tema_id, estado)
    SELECT p_usuario_id, t.id, 'BLOQUEADO'
    FROM tema t
    WHERE t.dominio = p_dominio AND t.activo
      AND NOT EXISTS (SELECT 1 FROM usuario_tema_progreso up WHERE up.usuario_id = p_usuario_id AND up.tema_id = t.id)
    ON CONFLICT (usuario_id, tema_id) DO NOTHING;

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
