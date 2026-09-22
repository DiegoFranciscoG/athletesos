#!/usr/bin/env bash
# Arranca el backend cargando secretos desde .env (no desde variables de
# entorno de Windows, que se acumulan/corrompen entre sesiones distintas).
set -euo pipefail
cd "$(dirname "$0")"

if [ ! -f .env ]; then
  echo "Falta .env — copia .env.example y completa los valores." >&2
  exit 1
fi

set -a
source .env
set +a

./mvnw.cmd spring-boot:run
