# easyway_for_odoo

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](LICENSE)
[![shellcheck](https://github.com/esfingex/easyway_for_odoo/actions/workflows/shellcheck.yml/badge.svg)](.github/workflows/shellcheck.yml)

Instaladores de Odoo para Ubuntu LTS (18.04 / 20.04 / 22.04 / 24.04), con una CLI unificada.

## Inicio rápido

```bash
git clone https://github.com/esfingex/easyway_for_odoo.git
cd easyway_for_odoo

./bin/easyway doctor              # diagnóstico del sistema (read-only)
./bin/easyway install dev --dry-run   # ensaya la instalación sin tocar nada
sudo ./bin/easyway install dev        # instala el entorno de desarrollo
```

## La CLI: `bin/easyway`

| Comando | Qué hace |
|---------|----------|
| `easyway install dev` | Entorno de desarrollo: PostgreSQL, wkhtmltopdf, código fuente de Odoo (nightly) en `/opt/odoo/odoo<VER>`, virtualenv y workspace para VSCode |
| `easyway install server` | Servidor: Odoo desde el repo apt nightly + PostgreSQL + wkhtmltopdf |
| `easyway doctor` | Chequeo pre-instalación: SO soportado, root/sudo, comandos necesarios |
| `easyway test` | Suite de pruebas del repo |

Flags de instalación (pasan directo):

- `--odoo N` — versión de Odoo (dev: `18`, server: `18.0`)
- `--pg N` — versión de PostgreSQL (default `16`)
- `--user USR` — dueño de los archivos (default: quien invoca sudo)
- `--python 3.X` — sobrescribe el mapeo automático Odoo→Python
- `--firewall` — reglas básicas de ufw/iptables
- `--dry-run` — **imprime los comandos sin ejecutarlos**
- `--pgadmin` (dev) / `--extras` y `--certbot` (server) — opcionales

Mapeo automático Odoo → Python: 15→3.10, 16/17→3.10, 18→3.12.

## Seguridad del flujo de publicación

- Los instaladores corren con `set -euo pipefail`: se detienen al primer error.
- Repos APT idempotentes con keyrings firmados (`signed-by`, no `trusted.gpg.d`).
- Nunca `chmod 777`: los archivos quedan con dueño dedicado (`chown`).
- `--dry-run` en todo: ensaya sin tocar el sistema.
- **Portero de publicación** (`.githooks/pre-push`): todo push a GitHub pasa por un chequeo que bloquea secretos, contraseñas reales y archivos privados. Se instala con `git config core.hooksPath .githooks`.

## Workflow de publicación (privado → público)

Este proyecto se desarrolla contra un servidor Forgejo privado y se publica en GitHub:

```bash
git publish        # push a Forgejo + GitHub; el portero revisa lo que sale
```

El historial de waves y decisiones de diseño vive en un repositorio privado aparte (`easyway_for_odoo_planning`) y nunca entra al repo público.

## Estructura

```
bin/easyway           CLI unificada
lib/common.sh         utilidades compartidas (log, dry-run, repos apt)
install_develop.sh    instalador de desarrollo
install_odoo.sh       instalador de servidor
odoo.conf             config de desarrollo
odoo.prod.conf        config de producción (plantilla)
odoovs/               plantilla VSCode
tests/                suite de pruebas reproducible
.githooks/            portero de publicación
```

## Pruebas

```bash
./bin/easyway test             # suite principal
bash tests/test_pre_push.sh    # pruebas del portero
```

## Notas

- wkhtmltopdf: builds oficiales 0.12.6-1 (bionic/focal) y 0.12.6.1-3 (jammy). **No existe build oficial para 24.04 (noble)**; ahí se usa el paquete de jammy.
- Opciones obsoletas eliminadas de las configs: `osv_memory_*`, `longpolling_port`, `port`, `demo`.
- `odoo.conf` es para desarrollo (`workers = 0`); para producción usa `odoo.prod.conf` detrás de nginx y **genera un `admin_passwd` fuerte**.

## Licencia

GPL-3.0 — ver [LICENSE](LICENSE).
