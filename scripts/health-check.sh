#!/usr/bin/env bash
# Verifica que una instancia de la webapi esté sana, consultando por SSH
# (así los puertos 8080/8081 no necesitan estar expuestos al exterior).
# Uso: health-check.sh <alias-ssh> <puerto> [intentos]
set -euo pipefail
source "$(dirname "$0")/config.sh"

ALIAS="${1:?uso: health-check.sh <alias-ssh> <puerto> [intentos]}"
PORT="${2:?falta el puerto}"
ATTEMPTS="${3:-15}"

for i in $(seq 1 "$ATTEMPTS"); do
    if BODY=$(ssh -o ConnectTimeout=5 "$ALIAS" "curl -fs -m 3 http://localhost:${PORT}/health" 2>/dev/null); then
        if [ "$BODY" = "Server Healthy!" ]; then
            echo "HEALTH OK: ${ALIAS}:${PORT} -> ${BODY}"
            exit 0
        fi
    fi
    sleep 2
done

echo "HEALTH FAIL: ${ALIAS}:${PORT} no responde tras ${ATTEMPTS} intentos"
exit 1
