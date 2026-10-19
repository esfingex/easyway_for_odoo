#!/usr/bin/env bash
set -euo pipefail

########################################
# easyway_for_odoo — instalador de entorno de DESARROLLO Odoo
# Iván Masías — https://github.com/esfingex
#
# Soporta Ubuntu 18.04, 20.04, 22.04, 24.04 (LTS)
#
# Uso:
#   sudo ./install_develop.sh [--odoo 18] [--pg 16] [--python 3.12]
#                             [--user juan] [--pgadmin] [--firewall]
#                             [--dry-run]
########################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

# Defaults
ODOO_VER=18
PG_VER=16
PYTHON_VER=""
DUSER="${SUDO_USER:-$USER}"
INSTALL_PGADMIN=0
FIREWALL=0

usage() {
    cat <<EOF
Uso: sudo ./install_develop.sh [opciones]
EOF
    usage_common
    cat <<EOF
  --pgadmin     instalar también pgAdmin4 (desktop)

Mapeo automático Odoo -> Python:
  15 -> 3.10 | 16/17 -> 3.10 | 18 -> 3.12   (sobrescribir con --python)
EOF
}

while [ $# -gt 0 ]; do
    case "$1" in
        --odoo)     ODOO_VER="$2"; shift 2 ;;
        --pg)       PG_VER="$2"; shift 2 ;;
        --python)   PYTHON_VER="$2"; shift 2 ;;
        --user)     DUSER="$2"; shift 2 ;;
        --pgadmin)  INSTALL_PGADMIN=1; shift ;;
        --firewall) FIREWALL=1; shift ;;
        --dry-run)  DRY_RUN=1; shift ;;
        -h|--help)  usage; exit 0 ;;
        *) die "Opción desconocida: $1 (ver --help)" ;;
    esac
done

case "$ODOO_VER" in
    ''|*[!0-9]*) die "--odoo debe ser un número (ej: 18)" ;;
esac
case "$PG_VER" in
    ''|*[!0-9]*) die "--pg debe ser un número (ej: 16)" ;;
esac

# Mapeo Odoo -> Python (deadsnakes provee las versiones)
if [ -z "$PYTHON_VER" ]; then
    case "$ODOO_VER" in
        15)         PYTHON_VER="3.10" ;;
        16|17)      PYTHON_VER="3.10" ;;
        18)         PYTHON_VER="3.12" ;;
        *) die "Versión de Odoo sin mapeo de Python: $ODOO_VER (usa --python)" ;;
    esac
fi

log "Config: odoo=$ODOO_VER pg=$PG_VER python=$PYTHON_VER user=$DUSER"

require_root
check_arch
check_ubuntu
install_apt_fast
update_full

# PostgreSQL
add_apt_repo "pgdg" "https://www.postgresql.org/media/keys/ACCC4CF8.asc" \
    "http://apt.postgresql.org/pub/repos/apt ${RELEASE}-pgdg main"
log "---> Instalando PostgreSQL $PG_VER ..."
run apt-fast install -y libpq-dev "postgresql-${PG_VER}"

if [ "$INSTALL_PGADMIN" = "1" ]; then
    add_apt_repo "pgadmin4" "https://www.pgadmin.org/static/packages_pgadmin_org.pub" \
        "https://ftp.postgresql.org/pub/pgadmin/pgadmin4/apt/${RELEASE} pgadmin4 main"
    log "---> Instalando pgAdmin4 ..."
    run apt-fast install -y pgadmin4-desktop
fi

add_deadsnakes
update_full

log "---> Instalando wkhtmltopdf ..."
install_wkhtmltopdf

# Dependencias de compilación y Python
log "---> Instalando dependencias de Odoo ..."
run apt-fast install -y git libxml2-dev libjpeg-dev libsasl2-dev libldap2-dev \
    libssl-dev zlib1g-dev libxslt1-dev "python${PYTHON_VER}" "python${PYTHON_VER}-dev" \
    "python${PYTHON_VER}-venv" python3-pip gpg lsb-release aria2 virtualenv

download_odoo_ver() {
    log "---> Descargando Odoo SRC ${ODOO_VER}.0 ..."
    run aria2c -x2 --quiet=true -d /tmp -o "odoo_${ODOO_VER}.0.latest.tar.gz" \
        "https://nightly.odoo.com/${ODOO_VER}.0/nightly/src/odoo_${ODOO_VER}.0.latest.tar.gz"
    log "---> Descomprimiendo ..."
    run tar -xf "/tmp/odoo_${ODOO_VER}.0.latest.tar.gz" -C /tmp
    if [ "${DRY_RUN:-0}" = "1" ]; then
        log "[dry-run] (se omite la lógica dependiente de los archivos descargados)"
        return 0
    fi
    local src_dir
    src_dir="$(find /tmp -maxdepth 1 -type d -name "odoo-${ODOO_VER}.*" | head -1)"
    [ -n "$src_dir" ] || die "No se encontró el directorio extraído de Odoo"
    log "---> Estructura de directorios ..."
    run mkdir -p "/opt/odoo/odoo${ODOO_VER}"
    run cp -R "$src_dir/." "/opt/odoo/odoo${ODOO_VER}/"
    run rm -rf "$src_dir" "/tmp/odoo_${ODOO_VER}.0.latest.tar.gz"
    # Permisos: dueño dedicado, no 777
    run chown -R "${DUSER}:${DUSER}" /opt/odoo
}

config_odoo_src() {
    log "---> Configurando SRC ..."
    # Layouts antiguos traen setup/odoo; en los modernos odoo-bin ya está en la raíz
    if [ -f "/opt/odoo/odoo${ODOO_VER}/odoo/setup/odoo" ]; then
        run mv "/opt/odoo/odoo${ODOO_VER}/odoo/setup/odoo" \
            "/opt/odoo/odoo${ODOO_VER}/odoo/odoo-bin"
        run rm -rf "/opt/odoo/odoo${ODOO_VER}/odoo/setup" \
            "/opt/odoo/odoo${ODOO_VER}/odoo/odoo.egg-info"
        run rm -f "/opt/odoo/odoo${ODOO_VER}/odoo/setup.cfg" \
            "/opt/odoo/odoo${ODOO_VER}/odoo/setup.py" \
            "/opt/odoo/odoo${ODOO_VER}/odoo/PKG-INFO"
    else
        log "    layout moderno detectado: odoo-bin ya está en la raíz"
    fi
}

config_odoo_env() {
    log "---> Creando virtualenv ..."
    run mkdir -p /opt/odoo/venv
    run virtualenv -p "/usr/bin/python${PYTHON_VER}" "/opt/odoo/venv/odoo${ODOO_VER}"
    run chown -R "${DUSER}:${DUSER}" /opt/odoo/venv
    if [ "${DRY_RUN:-0}" = "1" ]; then
        log "[dry-run] (se omite la búsqueda de requirements.txt y el workspace)"
        return 0
    fi
    local req=""
    for cand in \
        "/opt/odoo/odoo${ODOO_VER}/requirements.txt" \
        "/opt/odoo/odoo${ODOO_VER}/odoo/requirements.txt"; do
        if [ -f "$cand" ]; then req="$cand"; break; fi
    done
    [ -n "$req" ] || die "No se encontró requirements.txt de Odoo"
    log "---> Instalando dependencias Python ..."
    run su "$DUSER" -c "/opt/odoo/venv/odoo${ODOO_VER}/bin/pip install --upgrade pip"
    run su "$DUSER" -c "/opt/odoo/venv/odoo${ODOO_VER}/bin/pip install -r '$req'"
    log "---> Creando workspace para VSCode ..."
    run su "$DUSER" -c "mkdir -p /home/${DUSER}/workspace/odoo${ODOO_VER}"
    run su "$DUSER" -c "ln -sfn /opt/odoo/odoo${ODOO_VER} /home/${DUSER}/workspace/odoo${ODOO_VER}/odoo-src"
    log "    Ajusta .vscode/settings.json para apuntar a /opt/odoo/venv/odoo${ODOO_VER}/bin/python${PYTHON_VER}"
}

log "################################################"
log "Install OdooScript Development (Experimental)  #"
log "for Easyway (https://github.com/esfingex)      #"
log "################################################"

download_odoo_ver
config_odoo_src
config_odoo_env

if [ "$FIREWALL" = "1" ]; then
    gufw_basic
fi

log "Instalación Finalizada Enjoy 3:)"
