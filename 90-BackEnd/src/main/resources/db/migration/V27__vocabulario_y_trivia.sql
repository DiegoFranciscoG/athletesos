-- ============================================================
-- V27: vocabulario y trivia como contenido de aprendizaje, con garantía
-- real de "nunca se repite": cada palabra/pregunta mostrada a un usuario
-- se registra en usuario_contenido_visto, y el selector siempre excluye
-- lo ya visto. Cuando se agota el banco, se avisa honestamente en vez de
-- reciclar contenido (evita la trampa de "parece infinito pero repite").
-- ============================================================

CREATE TABLE IF NOT EXISTS palabra (
    id SERIAL PRIMARY KEY,
    palabra TEXT NOT NULL UNIQUE,
    definicion TEXT NOT NULL,
    ejemplo TEXT,
    categoria_gramatical TEXT,
    fuente TEXT NOT NULL DEFAULT 'RAE (Diccionario de la lengua española)',
    activo BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE TABLE IF NOT EXISTS trivia (
    id SERIAL PRIMARY KEY,
    pregunta TEXT NOT NULL,
    opciones JSONB NOT NULL, -- ["opción A", "opción B", "opción C", "opción D"]
    respuesta_correcta SMALLINT NOT NULL, -- índice 0-3 en `opciones`
    explicacion TEXT,
    categoria TEXT NOT NULL,
    activo BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE TABLE IF NOT EXISTS usuario_contenido_visto (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    usuario_id UUID NOT NULL REFERENCES usuario(id) ON DELETE CASCADE,
    tipo TEXT NOT NULL CHECK (tipo IN ('PALABRA', 'TRIVIA')),
    contenido_id INTEGER NOT NULL,
    visto_en TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (usuario_id, tipo, contenido_id)
);
CREATE INDEX IF NOT EXISTS idx_contenido_visto_usuario_tipo ON usuario_contenido_visto(usuario_id, tipo);

-- ---------- selector: siguiente palabra nunca antes vista por este usuario ----------
CREATE OR REPLACE FUNCTION siguiente_palabra(p_usuario_id UUID)
RETURNS TABLE(id INTEGER, palabra TEXT, definicion TEXT, ejemplo TEXT, categoria_gramatical TEXT, fuente TEXT) AS $$
DECLARE
    v_id INTEGER;
BEGIN
    SELECT p.id INTO v_id FROM palabra p
    WHERE p.activo AND NOT EXISTS (
        SELECT 1 FROM usuario_contenido_visto v
        WHERE v.usuario_id = p_usuario_id AND v.tipo = 'PALABRA' AND v.contenido_id = p.id
    )
    ORDER BY random() LIMIT 1;

    IF v_id IS NULL THEN
        RETURN; -- banco agotado: el cliente debe mostrar un estado honesto, no repetir
    END IF;

    INSERT INTO usuario_contenido_visto (usuario_id, tipo, contenido_id) VALUES (p_usuario_id, 'PALABRA', v_id);

    RETURN QUERY SELECT p.id, p.palabra, p.definicion, p.ejemplo, p.categoria_gramatical, p.fuente FROM palabra p WHERE p.id = v_id;
END;
$$ LANGUAGE plpgsql;

-- ---------- selector: siguiente trivia nunca antes vista por este usuario ----------
CREATE OR REPLACE FUNCTION siguiente_trivia(p_usuario_id UUID)
RETURNS TABLE(id INTEGER, pregunta TEXT, opciones TEXT, categoria TEXT) AS $$
DECLARE
    v_id INTEGER;
BEGIN
    SELECT t.id INTO v_id FROM trivia t
    WHERE t.activo AND NOT EXISTS (
        SELECT 1 FROM usuario_contenido_visto v
        WHERE v.usuario_id = p_usuario_id AND v.tipo = 'TRIVIA' AND v.contenido_id = t.id
    )
    ORDER BY random() LIMIT 1;

    IF v_id IS NULL THEN
        RETURN;
    END IF;

    INSERT INTO usuario_contenido_visto (usuario_id, tipo, contenido_id) VALUES (p_usuario_id, 'TRIVIA', v_id);

    RETURN QUERY SELECT t.id, t.pregunta, t.opciones::text, t.categoria FROM trivia t WHERE t.id = v_id;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- Semilla: vocabulario real (definiciones consistentes con el uso
-- estándar del español; fuente por defecto RAE ya declarada en la
-- columna). ~40 palabras — banco suficiente para semanas de uso diario
-- de una sola persona antes de necesitar ampliarse.
-- ============================================================
INSERT INTO palabra (palabra, definicion, ejemplo, categoria_gramatical) VALUES
 ('efímero', 'Que dura poco o es pasajero.', 'La belleza de esa flor es efímera, dura apenas un día.', 'adjetivo'),
 ('perspicaz', 'Que capta o percibe con rapidez y sutileza las cosas.', 'Su comentario perspicaz reveló un detalle que nadie más notó.', 'adjetivo'),
 ('ineludible', 'Que no se puede eludir o evitar.', 'Pagar impuestos es una obligación ineludible.', 'adjetivo'),
 ('vicisitud', 'Sucesión de hechos favorables o adversos en una persona o cosa.', 'A pesar de las vicisitudes, terminó la carrera.', 'sustantivo'),
 ('parsimonia', 'Lentitud y calma excesivas al hacer algo.', 'Comía con parsimonia, sin ninguna prisa.', 'sustantivo'),
 ('ecuánime', 'Que actúa con imparcialidad y equilibrio emocional.', 'El juez fue ecuánime al evaluar ambas versiones.', 'adjetivo'),
 ('gregario', 'Que tiende a vivir en compañía de otros o a seguir las iniciativas ajenas sin criterio propio.', 'Los lobos tienen un comportamiento gregario.', 'adjetivo'),
 ('inefable', 'Que no se puede explicar con palabras.', 'Sintió una alegría inefable al verla llegar.', 'adjetivo'),
 ('taciturno', 'Callado, silencioso, que habla poco.', 'Se quedó taciturno toda la cena.', 'adjetivo'),
 ('quimera', 'Aquello que se propone a la imaginación como posible o verdadero, no siéndolo.', 'Ganar la lotería sin jugar es una quimera.', 'sustantivo'),
 ('exiguo', 'Insuficiente, escaso.', 'Recibió un salario exiguo por su trabajo.', 'adjetivo'),
 ('lacónico', 'Breve, conciso, que se expresa con pocas palabras.', 'Su respuesta fue lacónica: "no".', 'adjetivo'),
 ('ubicuo', 'Que está presente a la vez en todas partes.', 'El teléfono móvil se volvió ubicuo en pocos años.', 'adjetivo'),
 ('avatar', 'Cambio, vicisitud, transformación.', 'Los avatares de la vida lo llevaron a otro país.', 'sustantivo'),
 ('circunspecto', 'Prudente, cauteloso en las palabras o acciones.', 'Fue circunspecto al comentar el tema delicado.', 'adjetivo'),
 ('efervescente', 'Que muestra un entusiasmo o actividad intensa y burbujeante.', 'Su personalidad efervescente contagiaba al grupo.', 'adjetivo'),
 ('fatuo', 'Vano, presuntuoso, sin fundamento.', 'Sus comentarios fatuos no impresionaron a nadie.', 'adjetivo'),
 ('hermético', 'Cerrado o protegido de forma que no deja pasar nada, o reservado en su forma de ser.', 'Se mostró hermético cuando le preguntaron por su pasado.', 'adjetivo'),
 ('idóneo', 'Adecuado, apropiado para algo.', 'Es el candidato idóneo para el puesto.', 'adjetivo'),
 ('júbilo', 'Alegría muy intensa que se manifiesta exteriormente.', 'La afición estalló en júbilo tras el gol.', 'sustantivo'),
 ('lúgubre', 'Triste, sombrío, fúnebre.', 'La música de la película tenía un tono lúgubre.', 'adjetivo'),
 ('mordaz', 'Que critica con agudeza e ironía hiriente.', 'Hizo un comentario mordaz sobre la película.', 'adjetivo'),
 ('nítido', 'Claro, transparente, limpio, sin manchas ni imperfecciones.', 'La imagen se ve nítida en esta pantalla.', 'adjetivo'),
 ('obcecado', 'Que se aferra tercamente a una idea sin querer razonar.', 'Estaba obcecado en terminar el proyecto solo.', 'adjetivo'),
 ('pletórico', 'Que está lleno o rebosante de algo, especialmente de energía o entusiasmo.', 'Llegó pletórico de energía al entrenamiento.', 'adjetivo'),
 ('quebradizo', 'Que se quiebra o rompe con facilidad.', 'El cristal viejo es más quebradizo.', 'adjetivo'),
 ('recóndito', 'Muy escondido, reservado y de difícil acceso.', 'Guardaba el secreto en lo más recóndito de su memoria.', 'adjetivo'),
 ('sagaz', 'Astuto, perspicaz, que prevé las cosas con anticipación.', 'Un inversor sagaz supo anticipar la crisis.', 'adjetivo'),
 ('tácito', 'Que no se expresa formalmente pero se supone o entiende.', 'Hubo un acuerdo tácito entre ambos equipos.', 'adjetivo'),
 ('umbral', 'Parte inferior de una puerta, o momento inicial de algo.', 'Estamos en el umbral de una nueva etapa.', 'sustantivo'),
 ('vehemente', 'Que actúa o se expresa con pasión e intensidad.', 'Defendió su postura de forma vehemente.', 'adjetivo'),
 ('yerto', 'Rígido, tieso, especialmente por el frío o la muerte.', 'Sus manos quedaron yertas por el frío.', 'adjetivo'),
 ('zozobra', 'Inquietud, angustia o aflicción por algo que puede ocurrir.', 'Vivía con zozobra desde que perdió el empleo.', 'sustantivo'),
 ('abnegado', 'Que sacrifica su propio interés por el de otros.', 'Es una madre abnegada que todo lo da por sus hijos.', 'adjetivo'),
 ('candoroso', 'Ingenuo, sincero, sin malicia.', 'Tenía una sonrisa candorosa de niño.', 'adjetivo'),
 ('diáfano', 'Claro, transparente, que se deja atravesar por la luz.', 'El agua del lago era diáfana.', 'adjetivo'),
 ('empedernido', 'Que tiene un hábito o vicio muy arraigado y difícil de cambiar.', 'Es un lector empedernido, siempre tiene un libro consigo.', 'adjetivo'),
 ('fruición', 'Placer intenso que se experimenta al hacer algo.', 'Comía el postre con fruición.', 'sustantivo'),
 ('garrulo', 'Que habla mucho y sin sustancia.', 'El vecino garrulo no dejaba de hablar de trivialidades.', 'adjetivo'),
 ('huraño', 'Que evita el trato con otras personas.', 'El gato del vecindario es muy huraño.', 'adjetivo')
ON CONFLICT (palabra) DO NOTHING;

-- ============================================================
-- Semilla: trivia real de cultura general (hechos verificables:
-- geografía, ciencia, historia). ~30 preguntas.
-- ============================================================
INSERT INTO trivia (pregunta, opciones, respuesta_correcta, explicacion, categoria) VALUES
 ('¿Cuál es el hueso más largo del cuerpo humano?', '["El húmero", "El fémur", "La tibia", "El radio"]', 1, 'El fémur, en el muslo, es el hueso más largo y fuerte del cuerpo humano.', 'Ciencia'),
 ('¿En qué año llegó el ser humano a la Luna por primera vez?', '["1965", "1969", "1972", "1958"]', 1, 'La misión Apolo 11 alunizó el 20 de julio de 1969.', 'Historia'),
 ('¿Cuál es el río más largo del mundo?', '["Amazonas", "Nilo", "Yangtsé", "Misisipi"]', 0, 'Según mediciones modernas, el Amazonas supera ligeramente al Nilo en longitud.', 'Geografía'),
 ('¿Qué elemento químico tiene el símbolo "Fe"?', '["Flúor", "Francio", "Hierro", "Fósforo"]', 2, '"Fe" viene del latín "ferrum", hierro.', 'Ciencia'),
 ('¿Cuál es el país con más husos horarios en su territorio?', '["Rusia", "Estados Unidos", "Francia", "China"]', 2, 'Francia, contando sus territorios de ultramar, abarca 12 husos horarios.', 'Geografía'),
 ('¿Quién pintó "Las Meninas"?', '["Francisco de Goya", "Diego Velázquez", "El Greco", "Pablo Picasso"]', 1, 'Diego Velázquez la pintó en 1656, hoy en el Museo del Prado.', 'Arte'),
 ('¿Cuál es el metal líquido a temperatura ambiente?', '["Plomo", "Mercurio", "Estaño", "Zinc"]', 1, 'El mercurio es el único metal líquido a temperatura ambiente.', 'Ciencia'),
 ('¿En qué continente se encuentra el desierto del Sahara?', '["Asia", "Oceanía", "África", "América del Sur"]', 2, 'El Sahara ocupa gran parte del norte de África.', 'Geografía'),
 ('¿Qué imperio construyó Machu Picchu?', '["Azteca", "Maya", "Inca", "Olmeca"]', 2, 'Machu Picchu fue construido por el Imperio inca en el siglo XV.', 'Historia'),
 ('¿Cuál es el planeta más grande del sistema solar?', '["Saturno", "Júpiter", "Neptuno", "Urano"]', 1, 'Júpiter es el planeta más grande, con un diámetro de unos 139.820 km.', 'Ciencia'),
 ('¿Qué idioma tiene más hablantes nativos en el mundo?', '["Inglés", "Español", "Mandarín", "Hindi"]', 2, 'El chino mandarín tiene la mayor cantidad de hablantes nativos.', 'Cultura general'),
 ('¿Cuál es la capital de Australia?', '["Sídney", "Melbourne", "Canberra", "Perth"]', 2, 'Canberra es la capital, aunque Sídney es la ciudad más poblada.', 'Geografía'),
 ('¿Quién escribió "Cien años de soledad"?', '["Mario Vargas Llosa", "Gabriel García Márquez", "Jorge Luis Borges", "Julio Cortázar"]', 1, 'Gabriel García Márquez publicó la novela en 1967.', 'Literatura'),
 ('¿Cuál es la velocidad de la luz en el vacío (aprox.)?', '["300.000 km/s", "150.000 km/s", "1.080.000 km/h", "30.000 km/s"]', 0, 'La luz viaja a unos 299.792 km/s en el vacío.', 'Ciencia'),
 ('¿Qué océano es el más grande del mundo?', '["Atlántico", "Índico", "Ártico", "Pacífico"]', 3, 'El océano Pacífico cubre más de un tercio de la superficie terrestre.', 'Geografía'),
 ('¿En qué año cayó el Muro de Berlín?', '["1987", "1989", "1991", "1993"]', 1, 'El muro cayó el 9 de noviembre de 1989.', 'Historia'),
 ('¿Cuál es el órgano más grande del cuerpo humano?', '["El hígado", "El cerebro", "La piel", "El pulmón"]', 2, 'La piel es el órgano más extenso, cubriendo todo el cuerpo.', 'Ciencia'),
 ('¿Qué país tiene forma de bota en el mapa?', '["Grecia", "Italia", "Portugal", "Croacia"]', 1, 'Italia es conocida por su característica forma de bota.', 'Geografía'),
 ('¿Quién formuló la teoría de la relatividad?', '["Isaac Newton", "Nikola Tesla", "Albert Einstein", "Galileo Galilei"]', 2, 'Albert Einstein publicó la relatividad especial en 1905 y la general en 1915.', 'Ciencia'),
 ('¿Cuál es la montaña más alta del mundo?', '["K2", "Everest", "Kilimanjaro", "Aconcagua"]', 1, 'El Everest, en el Himalaya, mide 8.849 metros sobre el nivel del mar.', 'Geografía'),
 ('¿Qué civilización antigua construyó las pirámides de Giza?', '["Mesopotamia", "Egipto", "Grecia", "Persia"]', 1, 'Las pirámides de Giza fueron construidas por el antiguo Egipto hace más de 4.500 años.', 'Historia'),
 ('¿Cuántos huesos tiene el cuerpo humano adulto aproximadamente?', '["156", "186", "206", "226"]', 2, 'El esqueleto adulto tiene 206 huesos.', 'Ciencia'),
 ('¿Cuál es la moneda oficial de Japón?', '["Yuan", "Won", "Yen", "Ringgit"]', 2, 'El yen japonés es la moneda oficial de Japón desde 1871.', 'Cultura general'),
 ('¿Qué gas es el más abundante en la atmósfera terrestre?', '["Oxígeno", "Dióxido de carbono", "Nitrógeno", "Hidrógeno"]', 2, 'El nitrógeno compone cerca del 78% de la atmósfera.', 'Ciencia'),
 ('¿Cuál es el desierto más grande del mundo (incluyendo los fríos)?', '["Sahara", "Antártida", "Gobi", "Atacama"]', 1, 'La Antártida es técnicamente el desierto más grande por su escasísima precipitación.', 'Geografía'),
 ('¿Quién pintó la Capilla Sixtina?', '["Rafael", "Miguel Ángel", "Leonardo da Vinci", "Botticelli"]', 1, 'Miguel Ángel pintó el techo entre 1508 y 1512.', 'Arte'),
 ('¿Cuál es el animal terrestre más rápido?', '["León", "Guepardo", "Antílope", "Caballo"]', 1, 'El guepardo puede alcanzar hasta 110-120 km/h en distancias cortas.', 'Ciencia'),
 ('¿Qué país tiene la mayor población del mundo (2024)?', '["China", "Estados Unidos", "India", "Indonesia"]', 2, 'India superó a China en población total alrededor de 2023.', 'Geografía'),
 ('¿En qué año comenzó la Primera Guerra Mundial?', '["1912", "1914", "1916", "1918"]', 1, 'La Primera Guerra Mundial comenzó en 1914 tras el asesinato del archiduque Francisco Fernando.', 'Historia'),
 ('¿Cuál es el metal más abundante en la corteza terrestre?', '["Hierro", "Aluminio", "Cobre", "Calcio"]', 1, 'El aluminio es el metal más abundante en la corteza terrestre.', 'Ciencia')
ON CONFLICT DO NOTHING;
