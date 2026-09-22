-- ============================================================
-- V2: catálogo semilla de ejercicios (fútbol/gym) + registro genérico
-- de sesiones. video_url se cura a mano por ahora (sin YouTube Data API).
-- ============================================================

CREATE TABLE IF NOT EXISTS ejercicio_futbol (
    id SERIAL PRIMARY KEY,
    categoria TEXT NOT NULL CHECK (categoria IN
        ('CONDUCCION','CONTROL','PASE','DEFINICION','VELOCIDAD','AGILIDAD','RESISTENCIA','PIERNA_NO_DOMINANTE')),
    nombre TEXT NOT NULL,
    descripcion TEXT NOT NULL,
    dificultad SMALLINT NOT NULL CHECK (dificultad BETWEEN 1 AND 5),
    instrucciones TEXT,
    errores_comunes TEXT,
    video_url TEXT,
    video_titulo TEXT,
    ts_explicacion_seg INTEGER,
    ts_ejecucion_seg INTEGER,
    ts_error_seg INTEGER,
    activo BOOLEAN NOT NULL DEFAULT TRUE
);

INSERT INTO ejercicio_futbol (categoria, nombre, descripcion, dificultad, instrucciones, errores_comunes) VALUES
 ('CONDUCCION','Conducción con conos - línea recta','Control de balón guiando entre conos en línea recta, ambos pies.',1,'Toques cortos, cabeza arriba, superficie externa e interna.','Balón demasiado lejos del pie, mirar el balón todo el tiempo.'),
 ('CONDUCCION','Conducción con cambios de dirección','Conos en zigzag para practicar cambios de ritmo y dirección.',2,'Cambiar de dirección con el exterior del pie, mantener el balón cerca.','Perder el control al cambiar de dirección rápido.'),
 ('CONDUCCION','Conducción bajo presión','Conducción con un defensor pasivo aplicando presión progresiva.',4,'Proteger el balón con el cuerpo, cambios de ritmo para desmarcar.','Exponer el balón al lado del defensor.'),
 ('CONTROL','Control orientado - pared','Recibir el balón de una pared y orientar el primer toque hacia el espacio libre.',2,'El primer toque debe salir del cuerpo hacia el espacio, no pegado al pie.','Primer toque muerto que no avanza.'),
 ('CONTROL','Control aéreo con amortiguación','Recibir balones por alto amortiguando con pecho, muslo o pie.',3,'Relajar la superficie de contacto en el momento del impacto.','Superficie rígida que rebota el balón lejos.'),
 ('CONTROL','Control y giro en espacio reducido','Recibir de espaldas a la portería y girar en un toque.',4,'Orientar el cuerpo antes de recibir, usar el apoyo correcto.','Girar sin haber escaneado el espacio antes.'),
 ('PASE','Pase corto de precisión','Series de pase y recepción a corta distancia con ambos pies.',1,'Golpe con interior del pie, pase raso y firme.','Golpear con la punta del pie, falta de dirección.'),
 ('PASE','Pase largo dirigido','Pases de media/larga distancia a un objetivo marcado.',3,'Apoyo del pie de soporte apuntando al objetivo, contacto en el centro del balón.','Levantar la cabeza tarde, golpe con el empeine desalineado.'),
 ('DEFINICION','Definición al segundo palo','Recibir pase cruzado y definir al segundo palo con presión simulada.',3,'Escaneo antes de recibir, remate con el interior colocado.','Cierre tardío de la carrera, definir sin mirar la portería.'),
 ('DEFINICION','Definición uno contra uno','Duelo individual con el arquero tras conducción.',4,'Cambiar el ritmo antes del disparo, definir con el pie más cómodo.','Disparar sin engañar al arquero, exceso de toques.'),
 ('VELOCIDAD','Sprints cortos 10-20m','Series de velocidad pura con recuperación completa.',2,'Salida explosiva, técnica de carrera con brazos activos.','Zancada demasiado larga al inicio.'),
 ('VELOCIDAD','Velocidad con balón','Conducción a máxima velocidad controlada en línea recta.',4,'Toques amplios pero controlados, mirar el espacio.','Perder el balón por toques demasiado largos.'),
 ('AGILIDAD','Escalera de agilidad','Patrones de pies en escalera para coordinación y velocidad de piernas.',2,'Apoyos rápidos y ligeros, brazos coordinados.','Apoyos pesados, perder el ritmo.'),
 ('RESISTENCIA','Circuito intermitente','Bloques de esfuerzo/descanso simulando la intermitencia del partido.',3,'Mantener intensidad alta en los bloques de esfuerzo.','Bajar el ritmo antes de tiempo.'),
 ('PIERNA_NO_DOMINANTE','Pase y control solo pierna no dominante','Todo el ejercicio de pase/control usando exclusivamente la pierna no dominante.',3,'Repetir los mismos patrones que con la pierna dominante, sin prisa.','Evitar la pierna no dominante en momentos de presión.')
ON CONFLICT DO NOTHING;

CREATE TABLE IF NOT EXISTS ejercicio_gym (
    id SERIAL PRIMARY KEY,
    grupo_muscular TEXT NOT NULL CHECK (grupo_muscular IN
        ('PIERNA','GLUTEO','CORE','EMPUJE','TRACCION','MOVILIDAD','CARDIO')),
    nombre TEXT NOT NULL,
    descripcion TEXT NOT NULL,
    dificultad SMALLINT NOT NULL CHECK (dificultad BETWEEN 1 AND 5),
    instrucciones TEXT,
    activo BOOLEAN NOT NULL DEFAULT TRUE
);

INSERT INTO ejercicio_gym (grupo_muscular, nombre, descripcion, dificultad, instrucciones) VALUES
 ('PIERNA','Sentadilla con peso corporal','Sentadilla básica enfocada en técnica.',1,'Rodillas alineadas con los pies, espalda neutra.'),
 ('PIERNA','Sentadilla goblet','Sentadilla sosteniendo una carga al pecho.',2,'Codos dentro de las rodillas al bajar, torso erguido.'),
 ('PIERNA','Sentadilla trasera (back squat)','Sentadilla con barra en la espalda.',4,'Core activado, descenso controlado por debajo de paralelo.'),
 ('GLUTEO','Puente de glúteo','Activación de glúteo desde el suelo.',1,'Empuje con talones, aprieta glúteo arriba.'),
 ('GLUTEO','Peso muerto rumano','Bisagra de cadera cargando el posterior.',3,'Barra pegada a las piernas, espalda neutra todo el recorrido.'),
 ('CORE','Plancha frontal','Isométrico de core.',1,'Cuerpo en línea recta, glúteo y abdomen activados.'),
 ('CORE','Plancha con toques de hombro','Plancha añadiendo estabilidad anti-rotación.',2,'Cadera estable al tocar cada hombro.'),
 ('CORE','Dead bug','Control de core con extremidades opuestas.',2,'Espalda baja pegada al suelo durante todo el movimiento.'),
 ('EMPUJE','Flexiones de pecho','Empuje horizontal con peso corporal.',2,'Cuerpo recto, bajar el pecho cerca del suelo.'),
 ('EMPUJE','Press de banca con mancuernas','Empuje horizontal con carga externa.',3,'Escápulas retraídas, bajada controlada.'),
 ('TRACCION','Remo con banda/mancuerna','Tracción horizontal para espalda.',2,'Codos pegados al cuerpo, apretar escápulas.'),
 ('MOVILIDAD','Movilidad de cadera 90/90','Rango de movimiento de cadera para prevención de lesiones.',1,'Movimiento controlado, sin rebotes.')
ON CONFLICT DO NOTHING;

-- ---------- registro_sesion: registro genérico de actividad completada ----------
CREATE TABLE IF NOT EXISTS registro_sesion (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    usuario_id UUID NOT NULL REFERENCES usuario(id) ON DELETE CASCADE,
    tipo TEXT NOT NULL CHECK (tipo IN ('FUTBOL','GYM','ESTUDIO','CONCENTRACION','HABITO')),
    actividad_programada_id UUID, -- FK se agrega en V3 tras crear la tabla
    titulo TEXT NOT NULL,
    fecha DATE NOT NULL DEFAULT CURRENT_DATE,
    duracion_real_min INTEGER,
    series_completadas SMALLINT,
    series_totales SMALLINT,
    carga_percibida SMALLINT CHECK (carga_percibida BETWEEN 1 AND 10),
    notas TEXT,
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_registro_sesion_usuario_fecha ON registro_sesion(usuario_id, fecha DESC);
CREATE INDEX IF NOT EXISTS idx_registro_sesion_tipo ON registro_sesion(usuario_id, tipo);
