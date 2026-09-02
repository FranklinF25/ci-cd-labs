# Changelog

Registro de versiones del proyecto final de CI/CD.
Formato: [SemVer](https://semver.org/) — `MAJOR.MINOR.PATCH`.

## [1.2.0] - 2026-09-02

### Added
- Clase `Calculator` (lógica de negocio del módulo: add/subtract/multiply/divide/factorial con ramas de error) — alineado con el repo del curso
- `CalculatorTest` con tests de los 5 métodos (incluye `testFactorial`, agregado nuestro: cubre caso normal y negativo)

## [1.1.0] - 2026-09-01

### Added
- Endpoint `GET /goodbye` → `Goodbye CI/CD World!`
- Test unitario del nuevo endpoint (`checkGoodbyeResponse`)

### Changed
- Versión de desarrollo actualizada a `1.1.0-SNAPSHOT`

## [1.0.0] - 2026-09-01

### Added
- Endpoints de la app del módulo: `/`, `/health`, `/date`
- Endpoint `/api/instance` → `{instance, port, version}` para la estrategia Blue-Green
- CI con GitHub Actions: Maven + JUnit + JaCoCo (`.github/workflows/maven.yml`)
- Pipeline de Release: tag `v*` → GitHub Release con el JAR (`.github/workflows/release.yml`)
- Scripts de deployment Blue-Green: `deploy.sh`, `health-check.sh`, `traffic-test.sh`, `switch-traffic.sh`
- Infraestructura local: Nginx como switch de tráfico (server41) + instancias BLUE/GREEN (server45)
