#!/usr/bin/env bash
# Deployment Blue-Green de la webapi (secciones 14 y 16 del enunciado).
#
# Uso: deploy.sh <version>       ej: deploy.sh 1.0.0  |  deploy.sh v1.0.0
#
# Flujo:
#   1. Valida que exista la GitHub Release de esa versión
#   2. Determina la instancia INACTIVA (target del deploy)
#   3. Descarga el JAR desde la Release directamente en server45
#   4. Detiene lo que hubiera en el puerto target
#   5. Levanta la nueva versión con INSTANCE_NAME=<color>
#   6. Health check contra la instancia directa (sin pasar por el LB)
#   7. Valida versión e identidad via /api/instance
#   8. Si todo pasa: switch de tráfico del Nginx hacia la instancia nueva
#   9. Verifica por el balanceador e informa el resultado
#
# Si algo falla antes del switch, el tráfico NUNCA dejó la versión activa
# (esa es la garantía de seguridad del patrón Blue-Green).
set -euo pipefail
source "$(dirname "$0")/config.sh"

VERSION="${1:?uso: deploy.sh <version> ej: 1.0.0}"
VERSION="${VERSION#v}"
JAR="${ARTIFACT_PREFIX}-${VERSION}.jar"
URL="https://github.com/${GITHUB_REPO}/releases/download/v${VERSION}/${JAR}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "=== DEPLOY webapi v${VERSION} ==="

# 1. La Release debe existir (el artifact no se reconstruye: se reutiliza)
if ! curl -fsIL "$URL" > /dev/null 2>&1; then
    echo "ERROR: no existe el artifact ${URL}"
    echo "Publicá primero la Release (git tag v${VERSION} && git push origin v${VERSION})"
    exit 1
fi
echo "[1/8] Release verificada: ${URL}"

# 2. Instancia target = la inactiva
ACTIVE=$(ssh "$LB_HOST_ALIAS" 'cat ~/ACTIVE 2>/dev/null || echo none')
case "$ACTIVE" in
    BLUE)  TARGET=GREEN; TARGET_PORT=$GREEN_PORT ;;
    GREEN) TARGET=BLUE;  TARGET_PORT=$BLUE_PORT ;;
    none)  TARGET=BLUE;  TARGET_PORT=$BLUE_PORT ;;   # primer deploy
esac
echo "[2/8] Activa: ${ACTIVE} -> desplegando en ${TARGET} (puerto ${TARGET_PORT})"

# 3. Descargar el artifact en el servidor
ssh "$APP_HOST_ALIAS" "mkdir -p ~/releases ~/logs && curl -fL -o ~/releases/${JAR} ${URL}"
echo "[3/8] Artifact descargado en ${APP_HOST_ALIAS}:~/releases/${JAR}"

# 4. Detener versión previa del puerto target (si existe)
ssh "$APP_HOST_ALIAS" "ss -tlnp 2>/dev/null | grep ':${TARGET_PORT}' | grep -oP 'pid=\K[0-9]+' | xargs -r kill && sleep 1 || true"
echo "[4/8] Puerto ${TARGET_PORT} liberado"

# 5. Levantar la nueva versión
ssh "$APP_HOST_ALIAS" "INSTANCE_NAME=${TARGET} nohup java -jar ~/releases/${JAR} --server.port=${TARGET_PORT} > ~/logs/${TARGET}.log 2>&1 < /dev/null &"
echo "[5/8] ${TARGET} levantando en :${TARGET_PORT} (INSTANCE_NAME=${TARGET})"

# 6. Health check directo a la instancia
"$SCRIPT_DIR/health-check.sh" "$APP_HOST" "$TARGET_PORT"
echo "[6/8] Health check OK en ${TARGET}"

# 7. Validar identidad y versión de la instancia nueva
RESP=$(curl -fs -m 5 "http://${APP_HOST}:${TARGET_PORT}/api/instance")
echo "    /api/instance -> ${RESP}"
echo "$RESP" | grep -q "\"instance\":\"${TARGET}\"" || {
    echo "ERROR: la instancia no reporta ser ${TARGET}"; exit 1; }
echo "$RESP" | grep -q "\"version\":\"${VERSION}\"" || {
    echo "ERROR: la instancia reporta una versión distinta de ${VERSION}"; exit 1; }
echo "[7/8] Identidad validada: ${TARGET} v${VERSION}"

# 8. Switch de tráfico (solo si todo lo anterior pasó)
"$SCRIPT_DIR/switch-traffic.sh" "$TARGET"
echo "[8/8] Tráfico conmutado a ${TARGET}"

echo ""
echo "=== DEPLOY EXITOSO: v${VERSION} en ${TARGET} (:${TARGET_PORT}) ==="
echo "Instancia anterior (${ACTIVE}) sigue corriendo como rollback inmediato."
echo "Verificá con: scripts/traffic-test.sh"
