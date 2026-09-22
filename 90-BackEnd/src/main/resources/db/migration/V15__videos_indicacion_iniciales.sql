-- ============================================================
-- V15: primer set de videos de indicacion REALES y verificados
-- (confirmado via busqueda + fetch que el titulo de la pagina
-- coincide, no son IDs inventados). Se cubren los 5 ejercicios de
-- dificultad 1 -- los que usa CUALQUIER usuario, incluido
-- PRINCIPIANTE, para maximizar el impacto de este primer lote.
--
-- Los timestamps internos (ts_explicacion_seg/ts_ejecucion_seg/
-- ts_error_seg) se dejan NULL a propósito: no se puede verificar el
-- segundo exacto de cada momento sin ver el video completo, y no se
-- va a inventar precision que no existe. TrainingController/Flutter
-- ya manejan esos campos como opcionales.
--
-- Hallazgo de paso: ejercicio_gym nunca tuvo columnas de video (solo
-- ejercicio_futbol las tenia desde V2), asi que GYM jamas pudo mostrar
-- un video aunque quisieramos. Se agregan aqui para que el mismo
-- sistema funcione en ambas categorias.
-- ============================================================

ALTER TABLE ejercicio_gym
    ADD COLUMN IF NOT EXISTS video_url TEXT,
    ADD COLUMN IF NOT EXISTS video_titulo TEXT,
    ADD COLUMN IF NOT EXISTS ts_explicacion_seg INTEGER,
    ADD COLUMN IF NOT EXISTS ts_ejecucion_seg INTEGER,
    ADD COLUMN IF NOT EXISTS ts_error_seg INTEGER;

UPDATE ejercicio_futbol SET
    video_url = 'https://www.youtube.com/watch?v=vnngDOCy9C8',
    video_titulo = '6 Simple Cone Weave Dribbling Drills for Beginners'
WHERE nombre = 'Conducción con conos - línea recta';

UPDATE ejercicio_futbol SET
    video_url = 'https://www.youtube.com/watch?v=oIpRuzvsU80',
    video_titulo = 'THE BASICS OF PASSING - beginner tutorial'
WHERE nombre = 'Pase corto de precisión';

UPDATE ejercicio_gym SET
    video_url = 'https://www.youtube.com/watch?v=CKcDiJnLaLY',
    video_titulo = 'How to Do Bodyweight Squats Correctly (Perfect Form Tutorial)'
WHERE nombre = 'Sentadilla con peso corporal';

UPDATE ejercicio_gym SET
    video_url = 'https://www.youtube.com/watch?v=n6JiF2jp2Ns',
    video_titulo = 'How to Do the Glute Bridge Properly (Beginner Guide)'
WHERE nombre = 'Puente de glúteo';

UPDATE ejercicio_gym SET
    video_url = 'https://www.youtube.com/watch?v=BQu26ABuVS0',
    video_titulo = 'How to Plank Properly for Beginners - Step By Step Tutorial'
WHERE nombre = 'Plancha frontal';
