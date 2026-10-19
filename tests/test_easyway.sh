#!/usr/bin/env bash
# Pruebas de la CLI bin/easyway. Reproducible: bash tests/test_easyway.sh
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

t "version imprime" bash bin/easyway version
t "sin args muestra ayuda" bash bin/easyway
t "help funciona" bash bin/easyway --help
tf "comando desconocido rechazado" bash bin/easyway volar
tf "install sin subcomando rechazado" bash bin/easyway install
tf "install subcomando raro rechazado" bash bin/easyway install volar

# Dispatch al instalador de desarrollo (dry-run completo, no toca nada)
t "install dev --dry-run pasa el portero de flags y corre" \
    env EASYWAY_RELEASE=jammy bash bin/easyway install dev --dry-run --odoo 18

t "install server --dry-run corre" \
    env EASYWAY_RELEASE=jammy bash bin/easyway install server --dry-run --odoo 18.0

# doctor: read-only; en cualquier SO debe terminar 0 o 1 sin colgarse
bash bin/easyway doctor >/dev/null 2>&1
rc=$?
if [ "$rc" -le 1 ]; then echo "PASS: doctor termina limpio (rc=$rc)"; else echo "FAIL: doctor rc=$rc"; FAILED=1; fi

# doctor honra EASYWAY_RELEASE: con jammy debe mencionar Ubuntu y salir <= 1
# (puede salir 1 si faltan comandos en el host actual, eso es válido)
out=$(EASYWAY_RELEASE=jammy bash bin/easyway doctor 2>&1); rc=$?
if [ "$rc" -le 1 ] && echo "$out" | grep -q "Ubuntu jammy"; then
    echo "PASS: doctor honra EASYWAY_RELEASE (jammy, rc=$rc)"
else
    echo "FAIL: doctor no honra EASYWAY_RELEASE (rc=$rc)"; FAILED=1
fi

if [ "$FAILED" = "0" ]; then echo "== CLI OK =="; else echo "== HAY FALLOS =="; exit 1; fi
