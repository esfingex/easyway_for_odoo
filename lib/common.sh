#!/usr/bin/env bash
########################################
# common.sh — utilidades compartidas para los instaladores easyway_for_odoo
# https://github.com/esfingex/easyway_for_odoo
#
# Variables de entorno soportadas:
#   DRY_RUN=1      solo imprime los comandos, no ejecuta nada
#   EASYWAY_LOG    si está definido, toda entrada de log se agrega a ese archivo
########################################

log() {
    local msg
    msg="$(date '+%F %T') $*"
    echo "$msg"
    if [ -n "${EASYWAY_LOG:-}" ]; then
        echo "$msg" >> "$EASYWAY_LOG"
    fi
}

die() {
    log "ERROR: $*" >&2
    exit 1
}

# run <cmd...> — ejecuta el comando, o solo lo imprime si DRY_RUN=1
run() {
    if [ "${DRY_RUN:-0}" = "1" ]; then
        log "[dry-run] $*"
    else
        "$@"
    fi
}

# run_sh <string> — igual que run(), para pipelines/redirecciones (bash -c)
run_sh() {
    if [ "${DRY_RUN:-0}" = "1" ]; then
        log "[dry-run] bash -c \"$1\""
    else
        bash -c "$1"
    fi
}

require_root() {
    if [ "$(id -u)" -ne 0 ]; then
        if [ "${DRY_RUN:-0}" = "1" ]; then
            log "AVISO dry-run: se omite la verificación de root"
        else
            die "Este script requiere ejecutarse como root (sudo)."
        fi
    fi
}

check_arch() {
    local m
    m="$(uname -m)"
    case "$m" in
        x86_64)         ARCHTYPE="arch=amd64" ;;
        aarch64|arm64)  ARCHTYPE="arch=arm64" ;;
        *) die "Arquitectura no soportada: $m (soportadas: amd64, arm64)" ;;
    esac
}

check_ubuntu() {
    # Hook de testing: EASYWAY_RELEASE fuerza el codename (ej: jammy) sin lsb_release
    if [ -n "${EASYWAY_RELEASE:-}" ]; then
        RELEASE="$EASYWAY_RELEASE"
    else
        command -v lsb_release >/dev/null 2>&1 \
            || die "lsb_release no disponible: este script es solo para Ubuntu."
        RELEASE="$(lsb_release -cs)"
    fi
    case "$RELEASE" in
        bionic|focal|jammy|noble) log "Ubuntu $RELEASE detectado" ;;
        *) die "Versión de Ubuntu no soportada: $RELEASE (soportadas: 18.04, 20.04, 22.04, 24.04)" ;;
    esac
}

install_apt_fast() {
    if command -v apt-fast >/dev/null 2>&1; then
        log "---> apt-fast ya instalado, se omite"
        return 0
    fi
    log "---> Instalando APT-FAST ..."
    run add-apt-repository ppa:apt-fast/stable -y
    run apt-get update -y
    run env DEBIAN_FRONTEND=noninteractive apt-get install -qq -y apt-fast
}

update_full() {
    log "---> Actualizando sistema ..."
    run apt-fast update -y
    run apt-fast upgrade -y
    run apt-fast autoremove -y
}

add_deadsnakes() {
    # PPA deadsnakes: pythons adicionales. Necesario en focal/jammy/noble.
    case "$RELEASE" in
        focal|jammy|noble)
            log "---> Agregando PPA deadsnakes ..."
            run add-apt-repository ppa:deadsnakes/ppa -y
            ;;
    esac
}

# add_apt_repo <nombre> <url_llave> <url_repo>
# Idempotente: si el repo ya está en su .list, no lo duplica.
# Usa /usr/share/keyrings + signed-by (trusted.gpg.d está deprecado).
add_apt_repo() {
    local name="$1" keyurl="$2" repourl="$3"
    local keyring="/usr/share/keyrings/${name}.gpg"
    local list="/etc/apt/sources.list.d/${name}.list"

    if grep -qF "$repourl" "$list" 2>/dev/null; then
        log "---> Repo $name ya configurado, se omite"
        return 0
    fi
    log "---> Agregando repo $name ..."
    run_sh "wget -qO- '$keyurl' | gpg --dearmour -o '$keyring'"
    run_sh "echo 'deb [signed-by=$keyring $ARCHTYPE] $repourl' > '$list'"
}

# wkhtmltopdf_url — imprime la URL del .deb según el release detectado.
# Builds oficiales verificados (2026-10): 0.12.6-1 tiene bionic/focal;
# 0.12.6.1-3 solo tiene jammy (no hay build noble).
wkhtmltopdf_url() {
    case "$RELEASE" in
        bionic|focal)
            echo "https://github.com/wkhtmltopdf/packaging/releases/download/0.12.6-1/wkhtmltox_0.12.6-1.${RELEASE}_amd64.deb"
            ;;
        jammy|noble)
            if [ "$RELEASE" = "noble" ]; then
                log "AVISO: no existe build oficial de wkhtmltopdf para noble; se usa el paquete de jammy."
            fi
            echo "https://github.com/wkhtmltopdf/packaging/releases/download/0.12.6.1-3/wkhtmltox_0.12.6.1-3.jammy_amd64.deb"
            ;;
        *) die "Sin build de wkhtmltopdf para $RELEASE" ;;
    esac
}

install_wkhtmltopdf() {
    local wkurl
    wkurl="$(wkhtmltopdf_url)"
    log "---> Instalando wkhtmltopdf ..."
    run apt-get install -y xfonts-75dpi xfonts-base
    run wget -q -O /tmp/wkhtmltox.deb "$wkurl"
    run dpkg -i /tmp/wkhtmltox.deb || run apt-get install -f -y
    run rm -f /tmp/wkhtmltox.deb
}

# gufw_basic — reglas básicas de firewall para Odoo
gufw_basic() {
    log "---> Reglas del firewall (básicas) ..."
    run ufw default deny incoming
    run ufw default allow outgoing
    run iptables -A INPUT -p tcp --dport 8069 -j ACCEPT
    run ufw allow 8069/tcp
    run ufw allow 80/tcp
    run ufw allow 443/tcp
}

usage_common() {
    cat <<'EOF'
Opciones comunes:
  --odoo N      versión de Odoo (default: ver cada script)
  --pg N        versión de PostgreSQL (default: ver cada script)
  --user USR    usuario dueño de los archivos (default: el que invoca sudo)
  --firewall    aplicar reglas básicas de ufw/iptables
  --dry-run     mostrar comandos sin ejecutarlos
  -h, --help    esta ayuda
EOF
}
