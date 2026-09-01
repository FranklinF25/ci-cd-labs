#!/usr/bin/env bash
# Configuración compartida de los scripts de deployment.
# Infra: Nginx (LB/switch) en server41, aplicación Blue-Green en server45.

# Hosts (aliases de ~/.ssh/config)
LB_HOST_ALIAS="server41"
APP_HOST_ALIAS="server45"

# IPs directas (para health checks y curls)
LB_HOST="192.168.100.41"
APP_HOST="192.168.100.45"

# Puertos de las instancias Blue-Green (sección 16 del enunciado)
BLUE_PORT=8080
GREEN_PORT=8081

# Repositorio y artifact
GITHUB_REPO="FranklinF25/ci-cd-labs"
ARTIFACT_PREFIX="webapi"

# Comando remoto para cambiar el backend activo en Nginx
# (script root instalado en server41, ejecutable sin password vía sudoers)
SWITCH_CMD="sudo /usr/local/bin/switch-backend.sh"
