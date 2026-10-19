# easyway_for_odoo

Instaladores de Odoo para Ubuntu LTS (18.04 / 20.04 / 22.04 / 24.04), en dos sabores:

- **`install_develop.sh`** — entorno de desarrollo: PostgreSQL, wkhtmltopdf, código fuente de Odoo (nightly tarball) en `/opt/odoo/odoo<VER>`, virtualenv dedicado y workspace para VSCode con symlink.
- **`install_odoo.sh`** — servidor: Odoo desde el repositorio apt nightly, PostgreSQL, wkhtmltopdf, extras opcionales (certbot, firewall, librerías Python).

## Uso

```bash
# Desarrollo (odoo 18, python 3.12 automático)
sudo ./install_develop.sh

# Desarrollo con otras versiones
sudo ./install_develop.sh --odoo 17 --pg 16 --user juan --pgadmin

# Servidor
sudo ./install_odoo.sh --odoo 18.0 --pg 16 --extras --certbot --firewall
```

### Opciones comunes

- `--odoo N` — versión de Odoo (dev: `18` default; server: `18.0` default)
- `--pg N` — versión de PostgreSQL (default `16`)
- `--user USR` — dueño de los archivos (default: quien invoca sudo)
- `--firewall` — reglas básicas de ufw/iptables
- `--dry-run` — **imprime los comandos sin ejecutarlos** (verificación segura)
- `--help` — ayuda

Adicionales: `install_develop.sh --pgadmin` instala pgAdmin4 desktop; `install_odoo.sh --extras` instala `pdf417gen`, `paramiko` y `cryptography` (versión configurable con `CRYPTOGRAPHY_VER=`).

## Mapeo Odoo → Python

| Odoo | Python |
|------|--------|
| 15   | 3.10   |
| 16/17| 3.10   |
| 18   | 3.12   |

Sobrescribir con `--python 3.X`.

## Configuraciones

- `odoo.conf` — desarrollo (workers=0, list_db on, proxy off). **Cambiar `CHANGE_ME` antes de usar.**
- `odoo.prod.conf` — plantilla de producción (workers>0, list_db off, proxy_mode on, log a archivo). Requiere nginx/apache como proxy.
- `odoovs/odoo.conf` — plantilla para el workspace de VSCode.

> Opciones obsoletas eliminadas respecto a versiones pasadas: `osv_memory_age_limit`, `osv_memory_count_limit` (≤14), `longpolling_port` (≤15), `port` (usar `http_port`).

## Verificación sin instalar nada

```bash
./install_develop.sh --dry-run
./install_odoo.sh --dry-run
```

## Estructura

```
lib/common.sh        utilidades compartidas (log, dry-run, repos apt idempotentes)
install_develop.sh   instalador de desarrollo
install_odoo.sh      instalador de servidor
odoo.conf            config dev
odoo.prod.conf       config producción (plantilla)
odoovs/              plantilla VSCode
tests/               suite de pruebas reproducible
```

El historial de waves y decisiones de diseño **no vive en este repo**: está
en un repositorio privado aparte (`easyway_for_odoo_planning`).

## Notas

- Los repos APT se agregan de forma **idempotente** y con keyrings firmados en `/usr/share/keyrings` (no `trusted.gpg.d`, deprecado).
- wkhtmltopdf: builds oficiales 0.12.6-1 (bionic/focal) y 0.12.6.1-3 (jammy). **No existe build oficial para 24.04 (noble)**; ahí se usa el paquete de jammy.
- Nunca rular con `chmod 777`; los archivos quedan con dueño dedicado (`chown`).
- CI: shellcheck en cada push (`.github/workflows/shellcheck.yml`).

## Licencia

GPL-3.0 — ver [LICENSE](LICENSE).
