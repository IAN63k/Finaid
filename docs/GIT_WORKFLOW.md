# Flujo de trabajo con Git

Guía de ramas, commits, versionamiento y releases de Finaid.

## Ramas

- `main` es la rama principal y **siempre debe ser desplegable**: todo lo que llega a `main`
  pasó por CI en verde.
- El trabajo se hace en ramas cortas creadas desde `main`:
  - `feat/<tema>` para nuevas funciones (`feat/parser-bbva`, `feat/insights-semanales`).
  - `fix/<tema>` para correcciones (`fix/nequi-monto-decimales`).
  - `chore/<tema>` para mantenimiento, dependencias, tooling (`chore/actualizar-riverpod`).
- Cada rama se integra con un Pull Request hacia `main`. Requisitos:
  - CI en verde (`flutter analyze` + `flutter test`).
  - Descripción siguiendo la plantilla de PR (`.github/PULL_REQUEST_TEMPLATE.md`).
  - Integración con **squash** (preferido para ramas con muchos commits pequeños) o
    **merge limpio** cuando los commits ya son atómicos y significativos. Evitar merges
    con commits de tipo "wip" o "fix typo".
- Borrar la rama después de integrarla.

## Conventional Commits

Los mensajes de commit siguen [Conventional Commits](https://www.conventionalcommits.org/es/):

```
<tipo>(<scope opcional>): <descripción en imperativo, minúscula, sin punto final>

<cuerpo opcional: qué y por qué, no cómo>

<pie opcional: BREAKING CHANGE:, Closes #123>
```

Tipos permitidos:

| Tipo       | Uso                                                        |
|------------|------------------------------------------------------------|
| `feat`     | Nueva funcionalidad visible para el usuario                |
| `fix`      | Corrección de un error                                     |
| `docs`     | Solo documentación                                         |
| `refactor` | Cambio de código que no corrige ni añade funcionalidad     |
| `test`     | Añadir o corregir tests                                    |
| `chore`    | Mantenimiento, dependencias, scripts, tareas sin impacto   |
| `ci`       | Workflows de GitHub Actions y configuración de CI          |
| `build`    | Sistema de build (Gradle, pubspec, firma, flavors)         |
| `perf`     | Mejora de rendimiento                                      |

Scopes sugeridos: `domain`, `infra`, `android`, `ios`, `ui`, `insights`, `parsers`, `ci`.

Ejemplos:

```
feat(parsers): soportar notificaciones de retiro en cajero de Bancolombia
fix(android): no duplicar notificaciones al reconectar el listener
docs(ios): documentar flujo de Atajos para el deep link finaid://ingest
refactor(domain): extraer Money como value object
test(insights): cubrir regla de gasto recurrente con meses incompletos
chore(release): v0.2.0
ci: cachear dependencias de pub en el workflow
```

Un cambio incompatible se marca con `!` después del tipo/scope y un pie `BREAKING CHANGE:`:

```
feat(infra)!: migrar esquema SQLite a v2

BREAKING CHANGE: las bases de datos creadas antes de 0.2.0 se migran automáticamente;
no hay vuelta atrás a versiones anteriores.
```

## Versionamiento (SemVer + build number)

La versión vive en `pubspec.yaml`:

```yaml
version: MAJOR.MINOR.PATCH+BUILD
```

- `MAJOR.MINOR.PATCH` es la versión semántica visible (`versionName` en Android,
  `CFBundleShortVersionString` en iOS).
- `+BUILD` es el `versionCode` de Android (y `CFBundleVersion` en iOS). **Debe subir siempre**
  en cada release, aunque la versión semántica no cambie; Google Play rechaza un APK/AAB con
  un `versionCode` igual o menor al ya publicado.

Reglas para elegir qué número incrementar:

- **MAJOR**: cambios incompatibles o migraciones de datos que impiden volver a una versión
  anterior (cambio de esquema SQLite sin compatibilidad, cambio del formato del deep link).
- **MINOR**: nuevas funciones compatibles (nuevo banco soportado, nueva regla de
  categorización o de insights, nueva pantalla).
- **PATCH**: correcciones de errores sin funcionalidad nueva (un parser que leía mal un monto,
  un crash, textos).

Mientras el proyecto esté en `0.x`, la API interna puede cambiar en MINOR; el primer `1.0.0`
marca la primera versión estable para usuarios.

Para actualizar la versión usa el script correspondiente (actualiza `pubspec.yaml` y sube el
build number en 1):

```powershell
# Windows
tool\bump_version.ps1 0.2.0
```

```bash
# macOS / Linux / Git Bash
tool/bump_version.sh 0.2.0
```

## Proceso de release

1. Asegúrate de estar en `main` actualizado y con CI en verde:
   `git switch main && git pull --ff-only`.
2. Actualiza `CHANGELOG.md`: mueve el contenido de `## [Unreleased]` a una nueva sección
   `## [X.Y.Z] - AAAA-MM-DD`, deja `Unreleased` vacío y actualiza los enlaces de comparación
   al final del archivo.
3. Sube la versión: `tool/bump_version.ps1 X.Y.Z` (o `tool/bump_version.sh X.Y.Z`).
4. Verifica en local: `flutter analyze && flutter test`.
5. Commit de release:
   `git add pubspec.yaml CHANGELOG.md && git commit -m "chore(release): vX.Y.Z"`.
6. Tag anotado: `git tag -a vX.Y.Z -m "Finaid vX.Y.Z"`.
7. Publica: `git push --follow-tags`.
8. El workflow `release.yml` se dispara con el tag `v*`, ejecuta los tests, compila el APK en
   modo release y crea un GitHub Release con el archivo `finaid-vX.Y.Z.apk` y notas generadas
   automáticamente a partir de los PRs. Revisa el release y edita las notas si hace falta.

> Nota: por ahora el build de release firma con la configuración de debug
> (`android/app/build.gradle.kts`). Antes de publicar en Google Play hay que configurar una
> keystore propia y pasarla al workflow mediante secrets.

## Hotfixes

Para corregir un error en producción sin arrastrar trabajo en curso de `main`:

1. Crea la rama desde el tag afectado: `git switch -c fix/<tema> vX.Y.Z`.
2. Aplica la corrección con commits `fix(...)`.
3. Sube la versión PATCH (`tool/bump_version.sh X.Y.(Z+1)`), actualiza `CHANGELOG.md`.
4. Abre PR hacia `main`; una vez integrado, etiqueta el commit de release en `main` como
   `vX.Y.(Z+1)` y haz `git push --follow-tags`.
5. Si `main` ya contiene cambios que no deben salir, publica el tag desde la rama de hotfix y
   luego integra la rama en `main` (merge, no squash, para conservar el commit etiquetado).

## Qué hace el CI

- **`ci.yml`** (en cada push a `main` y en cada PR): instala Flutter estable con caché, ejecuta
  `flutter pub get`, `flutter analyze --no-fatal-infos` y `flutter test --coverage`, y sube
  `coverage/lcov.info` como artefacto. Las ejecuciones anteriores de la misma rama se cancelan
  al llegar un nuevo push.
- **`release.yml`** (en cada tag `v*`): instala Java 17 y Flutter estable, ejecuta los tests,
  compila `flutter build apk --release`, renombra el APK a `finaid-vX.Y.Z.apk` y publica un
  GitHub Release con el APK adjunto y notas generadas automáticamente.

Ningún workflow ejecuta `flutter build` para iOS: esa plataforma se construye en local (ver
`docs/IOS.md`).
