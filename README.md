# Proyecto Final — CI/CD con GitHub Actions

Implementación completa de un proceso de **Continuous Integration / Continuous Delivery** para una webapi Java (Spring Boot), desde el push de una feature hasta su ejecución en infraestructura local, con despliegue **Blue-Green** y rollback instantáneo.

Todo el proceso es **automatizado, repetible, verificable, trazable y documentado**: la versión que se construye en CI es exactamente la que se publica en la Release y la que corre en producción.

## Camino rápido (reproducir el flujo completo)

```bash
# 1. Toolchain: construir y testear sin instalar nada (Docker)
docker run --rm -v "$PWD":/app -v maven_repo:/root/.m2 -w /app \
  maven:3.9-eclipse-temurin-21 mvn -B clean verify

# 2. Feature: rama + PR (CI valida) + merge
git checkout -b feature/mi-cambio
# ... cambios + tests ...
git push -u origin feature/mi-cambio
gh pr create --fill && gh pr merge --merge --delete-branch

# 3. Release: tag SemVer -> el workflow publica la Release con el JAR
#    -> y deploy.yml despliega SOLO a la infra, sin intervención humana
git checkout main && git pull
git tag -a v1.2.0 -m "Release v1.2.0"
git push origin v1.2.0

# 4. Deployment Blue-Green (instancia inactiva + switch de tráfico)
scripts/deploy.sh 1.2.0

# 5. Verificación del tráfico a través del balanceador
scripts/traffic-test.sh
```

## Arquitectura

```
                          DEVELOPER
                              │
                              ▼
                           GitHub
                              │
                        feature/* branch
                              │
                              ▼
                         Pull Request
                              │  (protección de main: check "Build and Test" obligatorio)
                              ▼
                     GitHub Actions — CI (maven.yml)
                              │
               ┌──────────────┼──────────────┐
               ▼              ▼              ▼
             Build       Unit Tests     JaCoCo Coverage
               │              │              │
               └──────────────┼──────────────┘
                              ▼
                    webapi-${VERSION}.jar
                              │
                               ▼  (tag v* → release.yml)
                        GitHub Release
                               │
                               ▼  (evento: release published → deploy.yml)
                GitHub Actions — CD (deploy.yml)
                               │  ejecuta los MISMOS scripts/ por SSH
                               ▼
                   scripts/deploy.sh (Blue-Green)
                               │
                               ▼
                     AWS EC2 (t3.micro, Ubuntu)
              ┌────────────────────────────────┐
              │  Nginx :80 (switch de tráfico) │
              │   upstream configurable        │
              │  BLUE  :8080 (inactiva)        │
              │  GREEN :8081 (activa)          │
              └────────────────────────────────┘
              │
              ▼
        Health Check + validación de versión
              │
        ┌─────┴─────┐
        ▼           ▼
      PASS        FAIL
        │           │
        ▼           ▼
   Switch de     Rollback:
   tráfico       el tráfico nunca dejó la instancia sana
```

## Tecnologías

| Tecnología | Rol |
|---|---|
| Java 21 + Spring Boot 3.2.5 | Aplicación web (`/`, `/health`, `/date`, `/goodbye`, `/api/instance`) |
| Maven | Build, tests, empaquetado (`target/webapi-${version}.jar`) |
| JUnit 5 + MockMvc | Tests unitarios y de endpoints (7 tests) |
| JaCoCo | Cobertura de código (100% de líneas en los controllers) |
| Git + GitHub | Gestión del código, PRs, protección de rama |
| GitHub Actions | CI (`maven.yml`) y Release (`release.yml`) |
| GitHub Releases | Publicación del artifact por versión |
| Bash + SSH | Automatización del deployment |
| Nginx | Switch de tráfico Blue-Green |
| Docker | Toolchain de build local (sin instalar Java/Maven en la máquina) |
| AWS EC2 (t3.micro, Ubuntu 24.04) | Infraestructura cloud: Nginx + instancias Blue-Green en una instancia |

## Estrategia de branching

| Rama | Propósito | Reglas |
|---|---|---|
| `main` | Código estable, base de releases | Solo se integra por **PR**; protegida con check requerido `Build and Test` |
| `feature/*` | Cada funcionalidad nueva | Nacen de `main` actualizada; se eliminan tras el merge |

**Relación con el pipeline:** todo push a `main` y toda PR ejecutan el workflow de CI. El CI es la puerta de entrada: sin checks verdes, no hay merge.

## Estrategia de tagging y versionamiento

**SemVer** (`MAJOR.MINOR.PATCH`): breaking → MAJOR, funcionalidad → MINOR, fix → PATCH.

- El tag se crea **sobre `main`** cuando el código está listo para liberarse.
- El tag dispara `release.yml`, que alinea el `pom.xml` con la versión del tag (`mvn versions:set`), construye y publica la Release.
- **Relación tag → artifact → deployment:** tag `v1.1.0` → JAR `webapi-1.1.0.jar` en la Release → ese mismo JAR (byte a byte) es el que `deploy.sh` descarga y ejecuta. La versión además viaja embebida en la app: `/api/instance` la reporta.
- Cada versión queda registrada en `CHANGELOG.md`.

## Pipeline CI (`maven.yml`)

| Paso | Comando | Qué valida |
|---|---|---|
| Checkout + JDK 21 (Temurin, cache Maven) | `setup-java@v4` | Entorno reproducible |
| Build | `mvn -B compile --file pom.xml` | Compila |
| Unit Tests | `mvn -B test --file pom.xml` | 7 tests JUnit |
| Package + Coverage | `mvn -B clean verify --file pom.xml` | JAR final + reporte JaCoCo, publicado como **artifact descargable** del run (`jacoco-report`) |

Dispara en: push a `main` y PRs hacia `main`. Si un test falla, el check de la PR queda en rojo y el merge está bloqueado — ese comportamiento se demostró durante el desarrollo.

## Release (`release.yml`)

Dispara al pushear un tag `v*`:

```
versions:set (versión del tag) → clean verify (tests + JaCoCo) → gh release create con el JAR
```

Resultado: Release `v1.1.0` → asset `webapi-1.1.0.jar`, publicada por `github-actions[bot]` (nunca a mano).

## Deploy continuo (`deploy.yml`)

**La cadena completa es automática**: al publicarse una Release (o manualmente vía `workflow_dispatch`), el workflow se conecta por SSH a la EC2 y ejecuta **los mismos `scripts/` que se usan localmente** — no hay lógica duplicada:

```
git push origin v1.2.0
   → release.yml publica la Release
   → deploy.yml: scripts/deploy.sh 1.2.0 → Blue-Green + switch + verificación
```

| Secreto de repositorio | Contenido |
|---|---|
| `EC2_SSH_KEY` | Llave privada DEDICADA de deploy (`id_ed25519_gh_deploy`) — no la llave principal |
| `EC2_HOST` | IP pública de la EC2 |

La llave de deploy vive solo en los secrets y en la EC2 (`authorized_keys`); el security group solo expone `22` (autenticación exclusivamente por llave) y `80` — los puertos de las instancias (`8080`/`8081`) están cerrados al exterior porque los health checks viajan por SSH.

## Infraestructura (AWS — una EC2)

| Recurso | Detalle |
|---|---|
| Instancia | EC2 `t3.micro`, Ubuntu 24.04, `us-east-1` (nombre: `ci-cd-lab`) |
| Roles en la misma máquina | Nginx `:80` (switch Blue-Green) + BLUE `:8080` + GREEN `:8081` (Java 21) |
| Security group `ci-cd-lab-sg` | `22` abierto (autenticación exclusivamente por llave) y `80` público; `8080`/`8081` **cerrados** (los health checks viajan por SSH) |
| Acceso | SSH por llave importada (`ci-cd-labs` → `id_ed25519_servers`): `ssh aws-lab` (usuario `ubuntu`) |
| Provisioning | User-data al boot (Java 21 + Nginx) + `switch-backend.sh` + sudoers |
| Costo | Dentro del free tier (750h/mes ≈ una instancia 24/7); `aws ec2 stop-instances` cuando no se usa |

- El switch de backend es `/usr/local/bin/switch-backend.sh` (en la EC2): edita el `upstream` (`127.0.0.1`), valida con `nginx -t`, recarga y actualiza `~/ACTIVE`. Autorizado vía sudoers restringido (`NOPASSWD` solo para ese script).
- La app corre como `INSTANCE_NAME=<COLOR> java -jar ~/releases/webapi-<version>.jar --server.port=<puerto>`.

### Creación de la infra (reproducible)

```bash
# Key pair desde la llave pública existente
aws ec2 import-key-pair --key-name ci-cd-labs \
  --public-key-material fileb://~/.ssh/id_ed25519_servers.pub

# Security group: 22 (mundo, solo llave) + 80 (mundo). 8080/8081 permanecen cerrados.
aws ec2 create-security-group --group-name ci-cd-lab-sg --description "Proyecto final CI/CD"
aws ec2 authorize-security-group-ingress --group-id <sg-id> --protocol tcp --port 80 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-id <sg-id> --protocol tcp --port 22 --cidr 0.0.0.0/0

# Instancia con auto-provisioning (user-data instala Java 21 + Nginx)
aws ec2 run-instances --image-id <ami-ubuntu-24.04> --instance-type t3.micro \
  --key-name ci-cd-labs --security-group-ids <sg-id> \
  --user-data file://user-data.sh \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=ci-cd-lab}]'
```

> Historial: el proyecto se desarrolló y demostró primero sobre infra local (dos Ubuntu en LAN — server41/server45) y luego se migró a AWS conservando scripts y estrategia intactos; solo cambió `scripts/config.sh`.

## Estrategia de deployment: Blue-Green

**Justificación técnica:** con un solo balanceador y dos puertos se logra **downtime cero y rollback instantáneo** (el rollback es un cambio de tráfico, no un redeploy). Es la estrategia de menor riesgo verificable con la infraestructura disponible; su costo (duplicar instancias) es irrelevante en un solo host.

**Flujo** (sección 16 del enunciado):

```
BLUE activo → deploy GREEN (nueva versión) → health check → validación de
versión → switch de tráfico → GREEN activo
                     │
             si algo falla ANTES del switch: el tráfico nunca se movió
             (rollback implícito: no hay nada que revertir)
```

## Scripts (`scripts/`)

| Script | Uso | Qué hace |
|---|---|---|
| `deploy.sh` | `deploy.sh 1.2.0` | Deploy Blue-Green completo (8 pasos, ver abajo) |
| `health-check.sh` | `health-check.sh <host> <puerto>` | Verifica `/health` con reintentos |
| `traffic-test.sh` | `traffic-test.sh [N]` | N solicitudes al LB: qué instancia+versión atiende cada una |
| `switch-traffic.sh` | `switch-traffic.sh BLUE\|GREEN` | Conmuta el backend activo (también es el rollback) |
| `config.sh` | — | Constantes compartidas (hosts, puertos, repo) |

Pasos de `deploy.sh`: verificar Release → elegir instancia inactiva → descargar el JAR **directo desde la GitHub Release en server45** → liberar puerto → levantar con `INSTANCE_NAME` → health check → validar identidad y versión vía `/api/instance` → switch de tráfico → verificación final por el LB.

## Health checks y pruebas E2E

- **Health check** (`health-check.sh`): consulta `/health` en la instancia nueva **por SSH** (localhost en la EC2, sin exponer puertos ni pasar por el LB) antes de conmutar el tráfico. Solo una instancia sana puede recibir tráfico.
- **E2E** (dentro de `deploy.sh`, paso 7): la instancia nueva debe reportar exactamente `{instance: <color esperado>, version: <versión desplegada>}` en `/api/instance`. Esta condición decide si el deploy continúa hacia el switch.
- **Verificación de tráfico** (`traffic-test.sh`): tras el switch, todas las solicitudes al LB deben ser atendidas por la instancia nueva con la versión nueva.

## Procedimiento de rollback

**Detección:** el propio `deploy.sh` detecta fallos (health check sin respuesta, versión/instancia incorrectas) y aborta **antes** de tocar el tráfico. Fallos post-switch se detectan con `traffic-test.sh` o monitoreo de `/api/instance`.

**Recuperación** (demostrada en la demo de v1.1.0):

```bash
scripts/switch-traffic.sh BLUE   # el tráfico vuelve a la instancia anterior, aún corriendo
scripts/traffic-test.sh          # verificar: todas las solicitudes en BLUE con la versión previa
```

- **Cómo se aísla lo defectuoso:** la instancia verde defectuosa queda fuera del tráfico (el upstream apunta a la otra).
- **Cómo se verifica:** `traffic-test.sh` + los endpoints de la app (en la demo, `/goodbye` pasó de responder a dar 404 al volver a v1.0.0 — evidencia visible del rollback).
- **Duración:** un `nginx reload` (~1 segundo), sin reinstalar nada.

## Reproducir la demo completa (v1.0.0 → v1.1.0 → rollback)

```bash
# Primer deploy (no hay activo -> BLUE)
scripts/deploy.sh 1.0.0 && scripts/traffic-test.sh     # BLUE v1.0.0

# Nueva versión (activo BLUE -> deploy en GREEN + switch)
scripts/deploy.sh 1.1.0 && scripts/traffic-test.sh     # GREEN v1.1.0
curl http://$(grep -oP 'LB_HOST="\K[^"]+' scripts/config.sh)/goodbye   # "Goodbye CI/CD World!"

# Rollback (volver a BLUE v1.0.0, aún corriendo)
scripts/switch-traffic.sh BLUE
curl -i http://$(grep -oP 'LB_HOST="\K[^"]+' scripts/config.sh)/goodbye   # 404: no existe en v1.0.0
scripts/traffic-test.sh                                # BLUE v1.0.0

# Volver al estado final (v1.1.0 activa)
scripts/switch-traffic.sh GREEN
```
