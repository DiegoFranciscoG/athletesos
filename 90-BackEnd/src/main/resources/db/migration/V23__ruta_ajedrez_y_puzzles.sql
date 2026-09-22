-- ============================================================
-- V23: ruta de aprendizaje de AJEDREZ (teoría, mismo patrón que
-- karate/boxeo) + tabla de puzzles reales para el modo interactivo
-- jugable que se construye en Flutter con el motor real de reglas
-- (paquete `chess`, puerto de chess.js). Contenido de reglas basado
-- en las FIDE Laws of Chess oficiales (handbook.fide.com/chapter/e012023).
-- Los 3 puzzles estan verificados a mano casilla por casilla (no
-- copiados de una base de datos externa sin revisar).
-- ============================================================

DO $$
DECLARE
    v_padre_id UUID;
BEGIN
    INSERT INTO tema (dominio, padre_id, codigo, nombre, descripcion, orden, nivel_dificultad, fuente_url)
    VALUES ('AJEDREZ', NULL, 'ajedrez_1_reglas', 'Reglas básicas',
            'Objetivo del juego, el tablero y cómo empieza una partida.', 1, 1,
            'FIDE Laws of Chess (oficial) — handbook.fide.com/chapter/e012023')
    ON CONFLICT (dominio, padre_id, orden) DO NOTHING RETURNING id INTO v_padre_id;
    IF v_padre_id IS NULL THEN SELECT id INTO v_padre_id FROM tema WHERE dominio='AJEDREZ' AND padre_id IS NULL AND orden=1; END IF;
    INSERT INTO tema (dominio, padre_id, codigo, nombre, descripcion, orden, nivel_dificultad, contenido, fuente_url) VALUES
        ('AJEDREZ', v_padre_id, 'ajedrez_1_1', 'El objetivo y el tablero', 'Dos jugadores, 16 piezas cada uno, tablero de 64 casillas. Ganas dando jaque mate al rey rival.', 1, 1,
         'El tablero se coloca con una casilla clara en la esquina inferior derecha de cada jugador. Blancas siempre mueven primero.', 'FIDE Laws of Chess'),
        ('AJEDREZ', v_padre_id, 'ajedrez_1_2', 'Notación algebraica', 'Cada casilla tiene un nombre único: columna (a-h) + fila (1-8). Ej: e4, g7.', 2, 1,
         'Aprender esto te permite leer partidas, puzzles y anotar tus propias jugadas.', 'FIDE Laws of Chess')
    ON CONFLICT (dominio, padre_id, orden) DO NOTHING;

    INSERT INTO tema (dominio, padre_id, codigo, nombre, descripcion, orden, nivel_dificultad, fuente_url)
    VALUES ('AJEDREZ', NULL, 'ajedrez_2_piezas', 'Movimiento de las piezas',
            'Cómo se mueve cada pieza — la base de todo lo demás.', 2, 1,
            'FIDE Laws of Chess (oficial)')
    ON CONFLICT (dominio, padre_id, orden) DO NOTHING RETURNING id INTO v_padre_id;
    IF v_padre_id IS NULL THEN SELECT id INTO v_padre_id FROM tema WHERE dominio='AJEDREZ' AND padre_id IS NULL AND orden=2; END IF;
    INSERT INTO tema (dominio, padre_id, codigo, nombre, descripcion, orden, nivel_dificultad, contenido, fuente_url) VALUES
        ('AJEDREZ', v_padre_id, 'ajedrez_2_1', 'Peón', 'Avanza 1 casilla (2 en su primer movimiento), captura en diagonal.', 1, 1, 'Nunca retrocede ni captura hacia adelante.', 'FIDE Laws of Chess'),
        ('AJEDREZ', v_padre_id, 'ajedrez_2_2', 'Torre', 'Se mueve en línea recta: filas y columnas, cualquier distancia.', 2, 1, 'Pieza clave para el enroque y para dar jaque mate en el pasillo (fila/columna final).', 'FIDE Laws of Chess'),
        ('AJEDREZ', v_padre_id, 'ajedrez_2_3', 'Alfil', 'Se mueve en diagonal, cualquier distancia. Se queda siempre en casillas del mismo color.', 3, 1, 'Cada jugador tiene un alfil de casillas claras y otro de oscuras.', 'FIDE Laws of Chess'),
        ('AJEDREZ', v_padre_id, 'ajedrez_2_4', 'Caballo', 'Se mueve en L: 2 casillas en una dirección + 1 perpendicular. Es la única pieza que salta sobre otras.', 4, 2, 'Su movimiento en L es el que más cuesta visualizar al principio — practícalo mucho.', 'FIDE Laws of Chess'),
        ('AJEDREZ', v_padre_id, 'ajedrez_2_5', 'Dama (Reina)', 'La pieza más poderosa: combina el movimiento de torre y alfil.', 5, 2, 'Vale aproximadamente 9 peones — protégela siempre.', 'FIDE Laws of Chess'),
        ('AJEDREZ', v_padre_id, 'ajedrez_2_6', 'Rey', 'Se mueve 1 casilla en cualquier dirección. Nunca puede moverse a una casilla atacada.', 6, 2, 'Perder al rey (jaque mate) termina la partida — protegerlo es la prioridad número uno.', 'FIDE Laws of Chess')
    ON CONFLICT (dominio, padre_id, orden) DO NOTHING;

    INSERT INTO tema (dominio, padre_id, codigo, nombre, descripcion, orden, nivel_dificultad, fuente_url)
    VALUES ('AJEDREZ', NULL, 'ajedrez_3_jaque', 'Jaque y jaque mate',
            'Cuándo el rey está en peligro y cuándo la partida termina.', 3, 2,
            'FIDE Laws of Chess (oficial)')
    ON CONFLICT (dominio, padre_id, orden) DO NOTHING RETURNING id INTO v_padre_id;
    IF v_padre_id IS NULL THEN SELECT id INTO v_padre_id FROM tema WHERE dominio='AJEDREZ' AND padre_id IS NULL AND orden=3; END IF;
    INSERT INTO tema (dominio, padre_id, codigo, nombre, descripcion, orden, nivel_dificultad, contenido, fuente_url) VALUES
        ('AJEDREZ', v_padre_id, 'ajedrez_3_1', 'Jaque', 'El rey está atacado directamente. Debes responder de inmediato: mover el rey, bloquear o capturar la pieza que ataca.', 1, 2, 'No puedes hacer ningún otro movimiento mientras estés en jaque.', 'FIDE Laws of Chess'),
        ('AJEDREZ', v_padre_id, 'ajedrez_3_2', 'Jaque mate', 'El rey está en jaque y no hay ninguna jugada legal para salir de él. La partida termina.', 2, 2, 'Practica reconociendo mates simples: torre en la última fila, dama apoyada por el rey.', 'FIDE Laws of Chess'),
        ('AJEDREZ', v_padre_id, 'ajedrez_3_3', 'Ahogado (tablas)', 'El jugador en turno NO está en jaque pero no tiene ningún movimiento legal. La partida es tablas (empate), no una victoria.', 3, 2, 'Cuidado al ir ganando con mucha ventaja de material: no dejes al rival ahogado sin querer.', 'FIDE Laws of Chess')
    ON CONFLICT (dominio, padre_id, orden) DO NOTHING;

    INSERT INTO tema (dominio, padre_id, codigo, nombre, descripcion, orden, nivel_dificultad, fuente_url)
    VALUES ('AJEDREZ', NULL, 'ajedrez_4_especiales', 'Movimientos especiales',
            'Enroque, captura al paso y coronación — las 3 reglas especiales del ajedrez.', 4, 3,
            'FIDE Laws of Chess (oficial)')
    ON CONFLICT (dominio, padre_id, orden) DO NOTHING RETURNING id INTO v_padre_id;
    IF v_padre_id IS NULL THEN SELECT id INTO v_padre_id FROM tema WHERE dominio='AJEDREZ' AND padre_id IS NULL AND orden=4; END IF;
    INSERT INTO tema (dominio, padre_id, codigo, nombre, descripcion, orden, nivel_dificultad, contenido, fuente_url) VALUES
        ('AJEDREZ', v_padre_id, 'ajedrez_4_1', 'Enroque', 'Mueves el rey 2 casillas hacia la torre y la torre salta al otro lado del rey — en el mismo turno.', 1, 3, 'Solo es legal si ni el rey ni esa torre se movieron antes, no hay piezas entre ellos, y el rey no está ni pasa ni termina en jaque.', 'FIDE Laws of Chess'),
        ('AJEDREZ', v_padre_id, 'ajedrez_4_2', 'Captura al paso (en passant)', 'Si un peón rival avanza 2 casillas y queda junto al tuyo, puedes capturarlo como si hubiera avanzado solo 1 — pero solo en el turno inmediato siguiente.', 2, 3, 'Es la regla que más sorprende a los principiantes porque parece "ilegal" la primera vez que la ves.', 'FIDE Laws of Chess'),
        ('AJEDREZ', v_padre_id, 'ajedrez_4_3', 'Coronación', 'Si un peón llega a la última fila, se convierte en la pieza que quieras (normalmente dama).', 3, 2, 'Casi siempre conviene coronar a dama, salvo casos raros donde otra pieza evita un ahogado o da mate directo.', 'FIDE Laws of Chess')
    ON CONFLICT (dominio, padre_id, orden) DO NOTHING;

    INSERT INTO tema (dominio, padre_id, codigo, nombre, descripcion, orden, nivel_dificultad, fuente_url)
    VALUES ('AJEDREZ', NULL, 'ajedrez_5_tacticas', 'Tácticas básicas',
            'Trucos que ganan material o dan mate — la base de "jugar bien".', 5, 3,
            'Teoría clásica de ajedrez (dominio público)')
    ON CONFLICT (dominio, padre_id, orden) DO NOTHING RETURNING id INTO v_padre_id;
    IF v_padre_id IS NULL THEN SELECT id INTO v_padre_id FROM tema WHERE dominio='AJEDREZ' AND padre_id IS NULL AND orden=5; END IF;
    INSERT INTO tema (dominio, padre_id, codigo, nombre, descripcion, orden, nivel_dificultad, contenido, fuente_url) VALUES
        ('AJEDREZ', v_padre_id, 'ajedrez_5_1', 'Clavada (pin)', 'Atacas una pieza que no se puede mover porque detrás está el rey (o algo más valioso).', 1, 3, 'Una pieza clavada al rey no puede moverse aunque quiera — es ilegal exponer al rey.', 'Teoría clásica de ajedrez'),
        ('AJEDREZ', v_padre_id, 'ajedrez_5_2', 'Horquilla (fork)', 'Una sola pieza ataca dos objetivos al mismo tiempo — el rival solo puede salvar uno.', 2, 3, 'El caballo es el rey de las horquillas porque ataca casillas que ninguna otra pieza cubre.', 'Teoría clásica de ajedrez'),
        ('AJEDREZ', v_padre_id, 'ajedrez_5_3', 'Ataque a la pieza sin defensa', 'Revisa siempre qué piezas rivales quedaron sin protección después de cada jugada — tuya y del rival.', 3, 2, 'Practica esto en el modo Puzzles: son posiciones reales donde hay una jugada ganadora concreta.', 'Teoría clásica de ajedrez')
    ON CONFLICT (dominio, padre_id, orden) DO NOTHING;
END $$;

-- ============================================================
-- Puzzles reales para el modo interactivo. Verificados a mano
-- (posicion legal + jugada solucion confirmada casilla por casilla).
-- ============================================================
CREATE TABLE IF NOT EXISTS puzzle_ajedrez (
    id SERIAL PRIMARY KEY,
    codigo TEXT NOT NULL UNIQUE,
    titulo TEXT NOT NULL,
    descripcion TEXT NOT NULL,
    fen TEXT NOT NULL,
    solucion_san TEXT NOT NULL,
    nivel_dificultad SMALLINT NOT NULL CHECK (nivel_dificultad BETWEEN 1 AND 5),
    orden SMALLINT NOT NULL,
    activo BOOLEAN NOT NULL DEFAULT TRUE
);

INSERT INTO puzzle_ajedrez (codigo, titulo, descripcion, fen, solucion_san, nivel_dificultad, orden) VALUES
    ('mate_pasillo_1', 'Mate en el pasillo', 'Juegan blancas. El rey negro está encerrado por sus propios peones — encuentra el mate en 1.',
     '6k1/5ppp/8/8/8/8/8/4R1K1 w - - 0 1', 'Re8#', 2, 1),
    ('dama_apoyada_1', 'Dama apoyada por el rey', 'Juegan blancas. Lleva la dama a una casilla donde dé jaque mate protegida por tu propio rey.',
     '7k/1Q6/6K1/8/8/8/8/8 w - - 0 1', 'Qg7#', 2, 2),
    ('pieza_colgada_1', 'Captura la pieza sin proteger', 'Juegan blancas. Una pieza negra quedó completamente sin defensa — gánala.',
     '4k3/8/8/8/7q/5N2/8/4K3 w - - 0 1', 'Nxh4', 1, 3)
ON CONFLICT (codigo) DO NOTHING;
