-- ============================================================
-- V10: catálogo tenía dificultad máxima 4 en fútbol/gym, igual al
-- techo de INTERMEDIO — PROFESIONAL (techo 5) terminaba viendo el
-- mismo contenido. Se agregan ejercicios dificultad 5 exclusivos.
-- Confirmado con datos reales: antes de esto, INTERMEDIO y
-- PROFESIONAL compartían MAX(dificultad)=4 en el plan generado.
-- ============================================================

INSERT INTO ejercicio_futbol (categoria, nombre, descripcion, dificultad, instrucciones, errores_comunes) VALUES
 ('DEFINICION','Definición bajo presión con doble marca','Recibir de espaldas con dos defensores simulados y resolver en un toque hacia el arco.',5,'Escaneo constante antes de recibir, decisión en menos de 1 segundo.','Recibir sin haber decidido antes el primer toque.'),
 ('AGILIDAD','Cambios de dirección a máxima velocidad con oposición','Circuito de agilidad con un defensor activo aplicando presión real.',5,'Explosividad en cada cambio, centro de gravedad bajo.','Perder el equilibrio al cambiar de dirección a máxima velocidad.'),
 ('RESISTENCIA','Circuito intermitente de alta intensidad (HIIT específico)','Bloques de máxima intensidad con recuperación incompleta, simulando los últimos 15 minutos de un partido exigente.',5,'Mantener la técnica incluso con fatiga acumulada alta.','Bajar la técnica cuando aparece la fatiga.')
ON CONFLICT DO NOTHING;

INSERT INTO ejercicio_gym (grupo_muscular, nombre, descripcion, dificultad, instrucciones) VALUES
 ('PIERNA','Sentadilla búlgara con salto','Sentadilla unilateral explosiva con salto, alta demanda de estabilidad y potencia.',5,'Control en el aterrizaje, rodilla alineada con el pie en todo momento.'),
 ('EMPUJE','Press de banca con pausa + cadena/banda','Press de banca con pausa en el pecho y resistencia variable para máxima fuerza.',5,'Pausa completa de 1-2s en el pecho, explosividad en la subida.'),
 ('CORE','Plancha con arrastre de peso (sled/toalla)','Plancha dinámica arrastrando carga, máxima exigencia de core anti-extensión.',5,'Cadera estable durante todo el arrastre, sin perder la línea del cuerpo.')
ON CONFLICT DO NOTHING;
