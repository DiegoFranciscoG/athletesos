-- ============================================================
-- V22: ruta de aprendizaje de BOXEO. El boxeo no tiene una
-- federacion unica con examenes de cinturon como el karate, pero SI
-- tiene una progresion tecnica universal reconocida en cualquier
-- gimnasio del mundo: postura -> golpes rectos (1-2) -> juego de
-- piernas -> ganchos/uppercuts (3-4-5-6) -> combinaciones -> defensa
-- -> aplicacion. Verificado contra guias de boxeo reales (Legends
-- Boxing, Spartans Boxing Club, Golpea Mas Fuerte).
-- ============================================================

DO $$
DECLARE
    v_padre_id UUID;
BEGIN
    -- 1. Postura y guardia
    INSERT INTO tema (dominio, padre_id, codigo, nombre, descripcion, orden, nivel_dificultad, fuente_url)
    VALUES ('BOXEO', NULL, 'boxeo_1_postura', 'Postura y guardia',
            'La base de todo: cómo pararte y proteger tu mentón antes de lanzar un solo golpe.', 1, 1,
            'Legends Boxing / Golpea Más Fuerte — guías de boxeo para principiantes')
    ON CONFLICT (dominio, padre_id, orden) DO NOTHING RETURNING id INTO v_padre_id;
    IF v_padre_id IS NULL THEN SELECT id INTO v_padre_id FROM tema WHERE dominio='BOXEO' AND padre_id IS NULL AND orden=1; END IF;
    INSERT INTO tema (dominio, padre_id, codigo, nombre, descripcion, orden, nivel_dificultad, video_url, video_titulo, contenido, fuente_url) VALUES
        ('BOXEO', v_padre_id, 'boxeo_1_1', 'Postura ortodoxa/zurda', 'Pies a la altura de los hombros, pie de atrás retrasado, rodillas semiflexionadas, peso repartido.', 1, 1,
         'https://www.youtube.com/watch?v=TbSQmU6w-0E', 'Tutorial de boxeo: posición de guardia y desplazamientos',
         'Diestro = postura ortodoxa (pie izquierdo adelante). Zurdo = postura zurda/southpaw (pie derecho adelante). Alinea la punta del pie de adelante con el talón del de atrás.',
         'Legends Boxing / Daniel Vernaza (video verificado)'),
        ('BOXEO', v_padre_id, 'boxeo_1_2', 'Guardia alta', 'Puños arriba protegiendo el mentón, codos pegados al cuerpo protegiendo las costillas.', 2, 1, NULL, NULL,
         'Barbilla agachada sin perder la vista del rival. Manos cerca de la cara, no extendidas.',
         'Legends Boxing / Golpea Más Fuerte')
    ON CONFLICT (dominio, padre_id, orden) DO NOTHING;

    -- 2. Golpes rectos (1-2)
    INSERT INTO tema (dominio, padre_id, codigo, nombre, descripcion, orden, nivel_dificultad, fuente_url)
    VALUES ('BOXEO', NULL, 'boxeo_2_rectos', 'Golpes rectos: Jab y Cross (1-2)',
            'Los dos golpes más usados en todo el boxeo — velocidad y medida antes que potencia.', 2, 1,
            'Legends Boxing — "From Zero to Jab"')
    ON CONFLICT (dominio, padre_id, orden) DO NOTHING RETURNING id INTO v_padre_id;
    IF v_padre_id IS NULL THEN SELECT id INTO v_padre_id FROM tema WHERE dominio='BOXEO' AND padre_id IS NULL AND orden=2; END IF;
    INSERT INTO tema (dominio, padre_id, codigo, nombre, descripcion, orden, nivel_dificultad, contenido, fuente_url) VALUES
        ('BOXEO', v_padre_id, 'boxeo_2_1', 'Jab (golpe 1)', 'Golpe recto de la mano adelantada. No busca potencia: mide distancia y prepara el resto de la combinación.', 1, 1,
         'Extiende el brazo adelantado en línea recta, gira el puño al impactar, retrae rápido a la guardia.', 'Legends Boxing'),
        ('BOXEO', v_padre_id, 'boxeo_2_2', 'Cross (golpe 2)', 'Golpe recto de la mano trasera, el más potente de los dos rectos — rota la cadera y el talón trasero.', 2, 2,
         'Gira cadera y hombro trasero hacia el objetivo, el talón de atrás rota hacia afuera, el brazo termina extendido.', 'Legends Boxing')
    ON CONFLICT (dominio, padre_id, orden) DO NOTHING;

    -- 3. Juego de piernas
    INSERT INTO tema (dominio, padre_id, codigo, nombre, descripcion, orden, nivel_dificultad, fuente_url)
    VALUES ('BOXEO', NULL, 'boxeo_3_piernas', 'Juego de piernas',
            'Cómo crear potencia, controlar distancia y evitar golpes moviéndote, no solo con los brazos.', 3, 2,
            'Marksman Boxing Coaching / Precision Striking — guías de footwork')
    ON CONFLICT (dominio, padre_id, orden) DO NOTHING RETURNING id INTO v_padre_id;
    IF v_padre_id IS NULL THEN SELECT id INTO v_padre_id FROM tema WHERE dominio='BOXEO' AND padre_id IS NULL AND orden=3; END IF;
    INSERT INTO tema (dominio, padre_id, codigo, nombre, descripcion, orden, nivel_dificultad, contenido, fuente_url) VALUES
        ('BOXEO', v_padre_id, 'boxeo_3_1', 'Avanzar y retroceder', 'Para avanzar: primero el pie delantero, luego el trasero lo sigue. Para retroceder: al revés.', 1, 2,
         'Nunca cruces los pies. Pasos cortos, mantén siempre la base de la guardia.', 'Marksman Boxing Coaching'),
        ('BOXEO', v_padre_id, 'boxeo_3_2', 'Desplazamiento lateral', 'Moverte en círculo alrededor del rival sin perder el equilibrio ni la guardia.', 2, 2,
         'El pie del lado hacia donde te mueves va primero, el otro lo sigue manteniendo la distancia entre pies.', 'Precision Striking')
    ON CONFLICT (dominio, padre_id, orden) DO NOTHING;

    -- 4. Ganchos y uppercuts (3-4-5-6)
    INSERT INTO tema (dominio, padre_id, codigo, nombre, descripcion, orden, nivel_dificultad, fuente_url)
    VALUES ('BOXEO', NULL, 'boxeo_4_ganchos', 'Ganchos y uppercuts (3-4-5-6)',
            'Los golpes curvos y ascendentes — necesitan más técnica de cadera que los rectos.', 4, 3,
            'Fighters Corner — guía de técnicas de boxeo')
    ON CONFLICT (dominio, padre_id, orden) DO NOTHING RETURNING id INTO v_padre_id;
    IF v_padre_id IS NULL THEN SELECT id INTO v_padre_id FROM tema WHERE dominio='BOXEO' AND padre_id IS NULL AND orden=4; END IF;
    INSERT INTO tema (dominio, padre_id, codigo, nombre, descripcion, orden, nivel_dificultad, contenido, fuente_url) VALUES
        ('BOXEO', v_padre_id, 'boxeo_4_1', 'Gancho de adelante (golpe 3)', 'Golpe curvo y corto con el brazo delantero, gira sobre la punta del pie delantero.', 1, 3,
         'Codo a 90°, el giro sale de la cadera y el pie delantero pivota, no solo del brazo.', 'Fighters Corner'),
        ('BOXEO', v_padre_id, 'boxeo_4_2', 'Gancho de atrás (golpe 4)', 'La versión con más potencia del gancho, con el brazo trasero.', 2, 3,
         'Mismo principio que el gancho delantero pero rotando más cadera por la distancia extra.', 'Fighters Corner'),
        ('BOXEO', v_padre_id, 'boxeo_4_3', 'Uppercuts (golpes 5-6)', 'Golpes ascendentes a corta distancia, ideales para pasar por debajo de la guardia rival.', 3, 3,
         'Flexiona ligeramente la rodilla del lado que golpea y empuja hacia arriba usando la pierna, no solo el brazo.', 'Fighters Corner')
    ON CONFLICT (dominio, padre_id, orden) DO NOTHING;

    -- 5. Combinaciones
    INSERT INTO tema (dominio, padre_id, codigo, nombre, descripcion, orden, nivel_dificultad, fuente_url)
    VALUES ('BOXEO', NULL, 'boxeo_5_combos', 'Combinaciones básicas',
            'Unir los golpes sueltos en secuencias reales — de 2 golpes hasta 5.', 5, 3,
            'Legends Boxing — combinaciones para principiantes')
    ON CONFLICT (dominio, padre_id, orden) DO NOTHING RETURNING id INTO v_padre_id;
    IF v_padre_id IS NULL THEN SELECT id INTO v_padre_id FROM tema WHERE dominio='BOXEO' AND padre_id IS NULL AND orden=5; END IF;
    INSERT INTO tema (dominio, padre_id, codigo, nombre, descripcion, orden, nivel_dificultad, contenido, fuente_url) VALUES
        ('BOXEO', v_padre_id, 'boxeo_5_1', '1-2 (Jab-Cross)', 'La combinación más básica: el doble jab marca distancia, el cross remata con potencia.', 1, 2,
         'Practica hasta que el 1-2 salga sin pensar antes de sumar más golpes.', 'Legends Boxing'),
        ('BOXEO', v_padre_id, 'boxeo_5_2', '1-2-3 (Jab-Cross-Gancho)', 'Mezcla golpes rectos y curvos en la misma secuencia.', 2, 3,
         'El gancho final sale del pivote del pie delantero, no de estirar más el brazo.', 'Legends Boxing'),
        ('BOXEO', v_padre_id, 'boxeo_5_3', '1-1-2-3-2', 'Combinación larga de 5 golpes — exige ritmo, equilibrio y guardia alta todo el tiempo.', 3, 4,
         'Empieza lento y con espejo antes de intentarlo en saco o con compañero.', 'Legends Boxing')
    ON CONFLICT (dominio, padre_id, orden) DO NOTHING;

    -- 6. Defensa
    INSERT INTO tema (dominio, padre_id, codigo, nombre, descripcion, orden, nivel_dificultad, fuente_url)
    VALUES ('BOXEO', NULL, 'boxeo_6_defensa', 'Defensa: esquiva, bloqueo y parada',
            'No recibir el golpe es tan importante como lanzarlo.', 6, 4,
            'Fighters Corner — guía de defensa en boxeo')
    ON CONFLICT (dominio, padre_id, orden) DO NOTHING RETURNING id INTO v_padre_id;
    IF v_padre_id IS NULL THEN SELECT id INTO v_padre_id FROM tema WHERE dominio='BOXEO' AND padre_id IS NULL AND orden=6; END IF;
    INSERT INTO tema (dominio, padre_id, codigo, nombre, descripcion, orden, nivel_dificultad, contenido, fuente_url) VALUES
        ('BOXEO', v_padre_id, 'boxeo_6_1', 'Bloqueo con guantes/antebrazos', 'Absorbe el golpe con los guantes pegados a la cara y los codos a las costillas.', 1, 3,
         'No cierres los ojos ni bajes la guardia al bloquear — sigues viendo al rival.', 'Fighters Corner'),
        ('BOXEO', v_padre_id, 'boxeo_6_2', 'Esquiva (slip) y agache (roll)', 'Mueve la cabeza fuera de la línea del golpe en vez de bloquear siempre.', 2, 4,
         'Dobla ligeramente las rodillas y mueve la cabeza a los lados, no hacia adelante (evita el uppercut).', 'Fighters Corner'),
        ('BOXEO', v_padre_id, 'boxeo_6_3', 'Parada (parry)', 'Desvía el golpe rival con un pequeño toque de mano en vez de bloquearlo de frente.', 3, 4,
         'Un toque corto y a tiempo basta — no persigas la mano del rival ni te desequilibres.', 'Fighters Corner')
    ON CONFLICT (dominio, padre_id, orden) DO NOTHING;

    -- 7. Aplicación
    INSERT INTO tema (dominio, padre_id, codigo, nombre, descripcion, orden, nivel_dificultad, fuente_url)
    VALUES ('BOXEO', NULL, 'boxeo_7_aplicacion', 'Aplicación: sombra y saco',
            'Unir todo lo anterior en movimiento real, solo o con saco.', 7, 4,
            'Spartans Boxing Club — guía completa para principiantes')
    ON CONFLICT (dominio, padre_id, orden) DO NOTHING RETURNING id INTO v_padre_id;
    IF v_padre_id IS NULL THEN SELECT id INTO v_padre_id FROM tema WHERE dominio='BOXEO' AND padre_id IS NULL AND orden=7; END IF;
    INSERT INTO tema (dominio, padre_id, codigo, nombre, descripcion, orden, nivel_dificultad, contenido, fuente_url) VALUES
        ('BOXEO', v_padre_id, 'boxeo_7_1', 'Sombra (shadow boxing)', 'Practica combinaciones completas frente al espejo, sin oponente ni saco.', 1, 3,
         '3 rounds de 2-3 min imaginando un rival real: guardia, movimiento, combinación, guardia otra vez.', 'Spartans Boxing Club'),
        ('BOXEO', v_padre_id, 'boxeo_7_2', 'Trabajo de saco', 'Aplica potencia real a tus combinaciones con resistencia física del saco.', 2, 4,
         'No pierdas la técnica por golpear fuerte — si la guardia baja, reduce potencia y corrige postura primero.', 'Spartans Boxing Club')
    ON CONFLICT (dominio, padre_id, orden) DO NOTHING;
END $$;
