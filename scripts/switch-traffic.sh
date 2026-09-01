#!/usr/bin/env bash
# Cambia el backend activo en el Nginx de server41.
# Uso: switch-traffic.sh BLUE|GREEN
# Es también el mecanismo de rollback: volver al color anterior.
set -euo pipefail
source "$(dirname "$0")/config.sh"

TARGET="${1:?uso: switch-traffic.sh BLUE|GREEN}"
if [ "$TARGET" != "BLUE" ] && [ "$TARGET" != "GREEN" ]; then
    echo "ERROR: objetivo inválido '${TARGET}' (esperado BLUE o GREEN)"
    exit 1
fi

echo "Cambiando tráfico hacia ${TARGET}..."
ssh "$LB_HOST_ALIAS" "$SWITCH_CMD $TARGET"

# Verificación inmediata a través del balanceador
sleep 1
RESP=$(curl -fs -m 5 "http://${LB_HOST}/api/instance")
echo "Verificación por el LB: ${RESP}"

INSTANCE=$(echo "$RESP" | grep -oP '"instance":\s*"\K[^"]+')
if [ "$INSTANCE" != "$TARGET" ]; then
    echo "ERROR: el LB sigue sirviendo ${INSTANCE}"
    exit 1
fi
echo "SWITCH OK: todo el tráfico va a ${TARGET}"
