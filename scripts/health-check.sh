#!/usr/bin/env bash
# Verifica que una instancia de la webapi esté sana.
# Uso: health-check.sh <host> <puerto> [intentos]
set -euo pipefail
source "$(dirname "$0")/config.sh"

HOST="${1:?uso: health-check.sh <host> <puerto> [intentos]}"
PORT="${2:?falta el puerto}"
ATTEMPTS="${3:-15}"

for i in $(seq 1 "$ATTEMPTS"); do
    if BODY=$(curl -fs -m 3 "http://${HOST}:${PORT}/health" 2>/dev/null); then
        if [ "$BODY" = "Server Healthy!" ]; then
            echo "HEALTH OK: ${HOST}:${PORT} -> ${BODY}"
            exit 0
        fi
    fi
    sleep 2
done

echo "HEALTH FAIL: ${HOST}:${PORT} no responde tras ${ATTEMPTS} intentos"
exit 1
