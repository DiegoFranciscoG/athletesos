-- ============================================================
-- V16: el catalogo semilla de V2 (15 ejercicios de futbol, 12 de
-- gym) quedo duplicado exactamente 2 veces -- probablemente durante
-- el reset de baseline-version de Flyway de una sesion anterior, que
-- volvio a ejecutar el INSERT de V2 sobre una tabla que "CREATE TABLE
-- IF NOT EXISTS" dejo intacta. El "ON CONFLICT DO NOTHING" de V2 no
-- protegia nada porque nunca existio un UNIQUE(nombre) contra el cual
-- chocar. Confirmado con evidencia real: PRINCIPIANTE (dificultad<=2)
-- tenia 12 filas de futbol pero solo 6 nombres distintos.
--
-- Se deduplica quedandose con el id mas bajo de cada nombre repetido
-- (no hay actividad_programada viva en este momento -- se verifico
-- 0 usuarios antes de aplicar esto -- asi que no hay FK que reapuntar)
-- y se agrega UNIQUE(nombre) para que esto no pueda volver a pasar.
-- ============================================================

DELETE FROM ejercicio_futbol ef
WHERE ef.id NOT IN (
    SELECT MIN(id) FROM ejercicio_futbol GROUP BY nombre
);

DELETE FROM ejercicio_gym eg
WHERE eg.id NOT IN (
    SELECT MIN(id) FROM ejercicio_gym GROUP BY nombre
);

ALTER TABLE ejercicio_futbol ADD CONSTRAINT uq_ejercicio_futbol_nombre UNIQUE (nombre);
ALTER TABLE ejercicio_gym ADD CONSTRAINT uq_ejercicio_gym_nombre UNIQUE (nombre);
