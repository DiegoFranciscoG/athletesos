-- ============================================================
-- V24: al reverificar los 3 puzzles de ajedrez con python-chess
-- (motor independiente del que use para razonar las posiciones a
-- mano), confirme que las 3 posiciones son legales y las 3
-- soluciones son jugadas legales y correctas. Pero encontre que
-- "pieza_colgada_1" en realidad tiene al rey blanco en jaque desde
-- el inicio (la dama negra en h4 controla la diagonal h4-e1) -- la
-- jugada Nxh4 sigue siendo la solucion correcta (captura la pieza
-- que da jaque Y de paso gana la dama), pero la descripcion original
-- no mencionaba el jaque. Se corrige para ser exacta.
-- ============================================================

UPDATE puzzle_ajedrez
SET descripcion = 'Juegan blancas y están en jaque. Hay una jugada que resuelve el jaque Y gana la pieza que te está atacando — encuéntrala.'
WHERE codigo = 'pieza_colgada_1';
