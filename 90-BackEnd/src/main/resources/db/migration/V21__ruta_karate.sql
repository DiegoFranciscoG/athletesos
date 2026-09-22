-- ============================================================
-- V21: ruta de aprendizaje de KARATE -- 9 grados reales del
-- programa oficial de la KUGB (Karate Union of Great Britain,
-- federacion real), de 9° Kyu (cinturon blanco) a 1° Kyu (marron con
-- 2 franjas), verificado via kugb.org/rules-policies/grading-syllabus-rules/.
-- Cada grado tiene 3 subtemas: Kihon (tecnicas base), Kata (forma) y
-- Kumite (combate pactado), en ese orden de dificultad dentro del grado.
-- ============================================================

DO $$
DECLARE
    v_padre_id UUID;
    v_orden INT;
    v_dificultad SMALLINT;
    grado RECORD;
BEGIN
    FOR grado IN
        SELECT * FROM (VALUES
            (1, 'Cinturón Blanco → Naranja (9° Kyu)',
                'Oi tsuki, age uke, chudan soto uke, mae geri.',
                'Kihon Kata',
                'Sanbon o Gohon kumite (oi tsuki jodan y chudan).'),
            (2, 'Cinturón Naranja → Rojo (8° Kyu)',
                'Se suma chudan uchi uke, shuto uke, yoko geri keage y yoko geri kekomi.',
                'Heian Shodan',
                'Sanbon o Gohon kumite (oi tsuki jodan y chudan).'),
            (3, 'Cinturón Rojo → Amarillo (7° Kyu)',
                'Oi tsuki y age uke combinados con gyaku tsuki; se refuerzan los bloqueos con contraataque.',
                'Heian Nidan',
                'Sanbon o Gohon kumite (oi tsuki jodan y chudan).'),
            (4, 'Cinturón Amarillo → Verde (6° Kyu)',
                'Chudan soto uke con empi uchi, chudan uchi uke con gyaku tsuki; se introduce mawashi geri.',
                'Heian Sandan',
                'Kihon Ippon kumite (oi tsuki jodan/chudan, ambos lados).'),
            (5, 'Cinturón Verde → Morado (5° Kyu)',
                'Shuto uke con nukite; se suma mae geri al kihon ippon kumite.',
                'Heian Yondan',
                'Kihon Ippon kumite (jodan/chudan oi tsuki + chudan mae geri, ambos lados).'),
            (6, 'Cinturón Morado → Morado y Blanco (4° Kyu)',
                'Sanbon tsuki, combinaciones de age uke, secuencias de bloqueo complejas; se suma yoko geri.',
                'Heian Godan',
                'Kihon Ippon kumite (se agrega chudan yoko geri).'),
            (7, 'Cinturón Morado y Blanco → Marrón (3° Kyu)',
                'Sanbon tsuki con combinaciones complejas de defensa/ataque; se introduce ushiro geri.',
                'Tekki Shodan',
                'Kihon Ippon kumite (se agrega jodan mawashi geri).'),
            (8, 'Cinturón Marrón → Marrón 1 Franja (2° Kyu)',
                'Combinaciones extendidas con mae geri, yoko geri, mawashi geri y ushiro geri en secuencia.',
                'Bassai Dai (+ Heian a elección del examinador)',
                'Jiyu Ippon kumite: 6 ataques pactados, solo lado derecho.'),
            (9, 'Cinturón Marrón 1 Franja → Marrón 2 Franjas (1° Kyu)',
                'Kizami tsuki combinado con secuencias de mae/yoko/mawashi/ushiro geri.',
                'Bassai Dai (+ Heian a elección del examinador)',
                'Jiyu Ippon kumite: los mismos 6 ataques pactados.')
        ) AS g(orden, nombre, kihon, kata, kumite)
    LOOP
        v_dificultad := LEAST(5, CEIL(grado.orden * 5.0 / 9))::SMALLINT;

        INSERT INTO tema (dominio, padre_id, codigo, nombre, descripcion, orden, nivel_dificultad, fuente_url)
        VALUES ('KARATE', NULL, 'karate_grado_' || grado.orden, grado.nombre,
                'Programa oficial KUGB para este grado: kihon, kata y kumite.',
                grado.orden, v_dificultad,
                'KUGB - Karate Union of Great Britain, kugb.org/rules-policies/grading-syllabus-rules/')
        ON CONFLICT (dominio, padre_id, orden) DO NOTHING
        RETURNING id INTO v_padre_id;

        IF v_padre_id IS NULL THEN
            SELECT id INTO v_padre_id FROM tema WHERE dominio = 'KARATE' AND padre_id IS NULL AND orden = grado.orden;
        END IF;

        INSERT INTO tema (dominio, padre_id, codigo, nombre, descripcion, orden, nivel_dificultad, contenido, fuente_url)
        VALUES
            ('KARATE', v_padre_id, 'karate_' || grado.orden || '_kihon', 'Kihon: técnicas base', grado.kihon, 1, v_dificultad,
             'Practica cada técnica en el aire (kihon), en línea recta, con la cadera coordinada al golpe/bloqueo. Repite hasta que sea automático antes de pasar al kata.',
             'KUGB - kugb.org/rules-policies/grading-syllabus-rules/'),
            ('KARATE', v_padre_id, 'karate_' || grado.orden || '_kata', 'Kata: ' || grado.kata, 'Forma completa de este grado: ' || grado.kata || '.', 2, v_dificultad,
             'El kata es una secuencia fija de técnicas contra oponentes imaginarios. Apréndelo por partes (embusen) antes de unir todo el recorrido.',
             'KUGB - kugb.org/rules-policies/grading-syllabus-rules/'),
            ('KARATE', v_padre_id, 'karate_' || grado.orden || '_kumite', 'Kumite: ' || grado.kumite, grado.kumite, 3, v_dificultad,
             'El kumite pactado de este grado se practica con un compañero: ataque anunciado, defensa y contraataque predefinidos. Nunca sustituye la supervisión de un instructor presencial.',
             'KUGB - kugb.org/rules-policies/grading-syllabus-rules/')
        ON CONFLICT (dominio, padre_id, orden) DO NOTHING;
    END LOOP;
END $$;

-- Primer video real verificado (titulo de la pagina confirmado, no inventado).
UPDATE tema SET video_url = 'https://www.youtube.com/watch?v=WdYOSw7BwmI',
                video_titulo = 'TUTORIAL en ESPAÑOL paso a paso - Kata Heian Shodan karate do Shotokan'
WHERE dominio = 'KARATE' AND codigo = 'karate_2_kata';
