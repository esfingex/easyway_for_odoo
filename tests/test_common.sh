#!/usr/bin/env bash
# Pruebas unitarias de lib/common.sh + smoke dry-run de los instaladores.
# Reproducible: bash scratch/test_common.sh
# t <nombre> <cmd...>        espera exit 0
# tf <nombre> <cmd...>       espera exit != 0 (rechazo esperado)
set -u
cd "$(dirname "${BASH_SOURCE[0]}")/.."
FAILED=0
t() {
    local name="$1"; shift
    if "$@" >/dev/null 2>&1; then echo "PASS: $name"; else echo "FAIL: $name"; FAILED=1; fi
}
tf() {
    local name="$1"; shift
    if "$@" >/dev/null 2>&1; then echo "FAIL: $name (debía rechazar)"; FAILED=1; else echo "PASS: $name"; fi
}

t "wkhtmltopdf_url jammy -> 0.12.6.1-3" env RELEASE=jammy ARCHTYPE=arch=amd64 bash -c \
    'source lib/common.sh; [ "$(wkhtmltopdf_url)" = "https://github.com/wkhtmltopdf/packaging/releases/download/0.12.6.1-3/wkhtmltox_0.12.6.1-3.jammy_amd64.deb" ]'

t "wkhtmltopdf_url focal -> 0.12.6-1" env RELEASE=focal ARCHTYPE=arch=amd64 bash -c \
    'source lib/common.sh; [ "$(wkhtmltopdf_url)" = "https://github.com/wkhtmltopdf/packaging/releases/download/0.12.6-1/wkhtmltox_0.12.6-1.focal_amd64.deb" ]'

t "check_ubuntu acepta jammy (hook)" env EASYWAY_RELEASE=jammy bash -c \
    'source lib/common.sh; check_ubuntu'

tf "check_ubuntu rechaza codename invalido" env EASYWAY_RELEASE=arch bash -c \
    'source lib/common.sh; check_ubuntu'

t "require_root se omite en dry-run" env DRY_RUN=1 bash -c \
    'source lib/common.sh; require_root'

t "install_develop.sh dry-run completo" env EASYWAY_RELEASE=jammy bash \
    install_develop.sh --dry-run --odoo 18

t "install_odoo.sh dry-run completo" env EASYWAY_RELEASE=jammy bash \
    install_odoo.sh --dry-run --odoo 18.0

tf "--odoo abc rechazado" bash install_develop.sh --odoo abc
tf "flag desconocido rechazado" bash install_develop.sh --noexiste
t "--help funciona" bash install_develop.sh --help

t "dry-run no deja artifacts en /tmp" bash -c 'test ! -e /tmp/odoo_18.0.latest.tar.gz'

if [ "$FAILED" = "0" ]; then echo "== TODAS LAS PRUEBAS PASARON =="; else echo "== HAY FALLOS =="; exit 1; fi
