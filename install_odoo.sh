#!/usr/bin/env bash
set -euo pipefail

########################################
# easyway_for_odoo — instalador de Odoo para SERVIDOR (apt nightly)
# Iván Masías — https://github.com/esfingex
#
# Soporta Ubuntu 18.04, 20.04, 22.04, 24.04 (LTS)
#
# Uso:
#   sudo ./install_odoo.sh [--odoo 18.0] [--pg 16] [--user juan]
#                          [--extras] [--certbot] [--firewall] [--dry-run]
########################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

# Defaults
ODOO_VER="18.0"
PG_VER=16
DUSER="${SUDO_USER:-$USER}"
EXTRAS=0        # librerías python adicionales (pdf417gen, paramiko, cryptography)
INSTALL_CERTBOT=0
FIREWALL=0
CRYPTOGRAPHY_VER="${CRYPTOGRAPHY_VER:-3.4.8}"

usage() {
    cat <<EOF
Uso: sudo ./install_odoo.sh [opciones]
EOF
    usage_common
    cat <<EOF
  --extras      instalar librerías python extra (pdf417gen, paramiko, cryptography)
  --certbot     instalar certbot + plugin nginx
Variable opcional: CRYPTOGRAPHY_VER=3.4.8 (versión pinneada de cryptography)
EOF
}

while [ $# -gt 0 ]; do
    case "$1" in
        --odoo)     ODOO_VER="$2"; shift 2 ;;
        --pg)       PG_VER="$2"; shift 2 ;;
        --user)     DUSER="$2"; shift 2 ;;
        --extras)   EXTRAS=1; shift ;;
        --certbot)  INSTALL_CERTBOT=1; shift ;;
        --firewall) FIREWALL=1; shift ;;
        --dry-run)  DRY_RUN=1; shift ;;
        -h|--help)  usage; exit 0 ;;
        *) die "Opción desconocida: $1 (ver --help)" ;;
    esac
done

case "$ODOO_VER" in
    ''|*[!0-9.]*) die "--odoo debe ser una versión (ej: 18.0)" ;;
esac
case "$PG_VER" in
    ''|*[!0-9]*) die "--pg debe ser un número (ej: 16)" ;;
esac

log "Config: odoo=$ODOO_VER pg=$PG_VER user=$DUSER"

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

# wkhtmltopdf
log "---> Instalando wkhtmltopdf ..."
install_wkhtmltopdf

add_deadsnakes
update_full

# Odoo desde nightly (repo apt con keyring firmado)
add_apt_repo "odoo" "https://nightly.odoo.com/odoo.key" \
    "http://nightly.odoo.com/${ODOO_VER}/nightly/deb/ ./"
log "---> Instalando Odoo $ODOO_VER ..."
run apt-fast install -y odoo
run systemctl restart odoo || run service odoo restart

if [ "$EXTRAS" = "1" ]; then
    log "---> Instalando librerías Python extra ..."
    run apt-get install -y python3-pip
    run su "$DUSER" -c "pip3 install --upgrade pip"
    run su "$DUSER" -c "pip3 install pdf417gen paramiko cryptography==${CRYPTOGRAPHY_VER}"
fi

if [ "$INSTALL_CERTBOT" = "1" ]; then
    log "---> Instalando Certbot ..."
    run apt-get install -y certbot python3-certbot-nginx
fi

if [ "$FIREWALL" = "1" ]; then
    gufw_basic
fi

log "Instalación Finalizada Enjoy 3:)"
