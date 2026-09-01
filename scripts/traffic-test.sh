#!/usr/bin/env bash
# Envía N solicitudes al balanceador y muestra qué instancia atiende cada una.
# Uso: traffic-test.sh [numero-de-solicitudes]
# Sección 18 del enunciado: verificación experimental del tráfico.
set -euo pipefail
source "$(dirname "$0")/config.sh"

REQUESTS="${1:-20}"

echo "Enviando ${REQUESTS} solicitudes a http://${LB_HOST}/api/instance"
echo "---------------------------------------------------------"

declare -A COUNTS
for i in $(seq 1 "$REQUESTS"); do
    RESP=$(curl -fs -m 5 "http://${LB_HOST}/api/instance" 2>/dev/null) || {
        echo "req $i: ERROR"
        continue
    }
    INSTANCE=$(echo "$RESP" | grep -oP '"instance":\s*"\K[^"]+')
    VERSION=$(echo "$RESP" | grep -oP '"version":\s*"\K[^"]+')
    printf 'req %2d -> instancia: %-5s versión: %s\n' "$i" "$INSTANCE" "$VERSION"
    COUNTS["${INSTANCE} (v${VERSION})"]=$(( ${COUNTS["${INSTANCE} (v${VERSION})"]:-0} + 1 ))
done

echo "---------------------------------------------------------"
echo "Resumen:"
for key in "${!COUNTS[@]}"; do
    echo "  ${key}: ${COUNTS[$key]} solicitudes"
done
