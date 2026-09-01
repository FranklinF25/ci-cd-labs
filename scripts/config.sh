#!/usr/bin/env bash
# Configuración compartida de los scripts de deployment.
# Infra cloud (AWS): una EC2 con Nginx + instancias Blue-Green juntas.

# Hosts (aliases de ~/.ssh/config). Sobreescribibles por variables de
# entorno — así el workflow de GitHub Actions reutiliza estos scripts.
LB_HOST_ALIAS="${LB_HOST_ALIAS:-aws-lab}"
APP_HOST_ALIAS="${APP_HOST_ALIAS:-aws-lab}"   # misma EC2: nginx y la app conviven

# IPs públicas (para traffic-test y curl al balanceador)
LB_HOST="${LB_HOST:-54.196.223.67}"
APP_HOST="${APP_HOST:-54.196.223.67}"

# Puertos de las instancias Blue-Green (sección 16 del enunciado)
BLUE_PORT=8080
GREEN_PORT=8081

# Repositorio y artifact
GITHUB_REPO="FranklinF25/ci-cd-labs"
ARTIFACT_PREFIX="webapi"

# Comando remoto para cambiar el backend activo en Nginx
# (script root instalado en la EC2, ejecutable sin password vía sudoers)
SWITCH_CMD="sudo /usr/local/bin/switch-backend.sh"

# --- Infra local alternativa (lab LAN, referencia histórica) ---
# LB_HOST_ALIAS="server41"; APP_HOST_ALIAS="server45"
# LB_HOST="192.168.100.41";  APP_HOST="192.168.100.45"
