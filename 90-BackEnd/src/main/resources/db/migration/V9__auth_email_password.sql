-- ============================================================
-- V9: login con correo + contraseña, reemplaza la dependencia de
-- Google OAuth (bloqueada por configuración de Google Cloud fuera
-- de nuestro control). google_id se mantiene por si se reactiva
-- más adelante, pero deja de ser obligatorio.
-- ============================================================

ALTER TABLE usuario
    ADD COLUMN IF NOT EXISTS password_hash TEXT;

-- El email sigue siendo único (ya lo era) y ahora es el identificador de login real.
