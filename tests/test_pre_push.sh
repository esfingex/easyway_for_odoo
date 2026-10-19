#!/usr/bin/env bash
# Pruebas del portero de publicación (.githooks/pre-push).
# Reproducible: bash tests/test_pre_push.sh   (crea/elimina ramas temporales)
set -u
cd "$(dirname "${BASH_SOURCE[0]}")/.."
FAILED=0
Z="0000000000000000000000000000000000000000"
GITHUB_URL="git@github.com:esfingex/easyway_for_odoo.git"

run_hook() { # run_hook <sha> <url> — exit 0 = pasa, != 0 = bloqueado
    .githooks/pre-push origin "$2" <<< "refs/heads/main $1 refs/heads/main $Z"
}

# 1) Push legítimo del estado actual a GitHub: pasa
SHA=$(git rev-parse HEAD)
if run_hook "$SHA" "$GITHUB_URL" >/dev/null 2>&1; then
    echo "PASS: push legítimo pasa"
else
    echo "FAIL: push legítimo fue bloqueado"; FAILED=1
fi

# 2) Push al server privado: el portero no actúa
if run_hook "$SHA" "git@lukegit-git:esfingex/easyway_for_odoo.git" >/dev/null 2>&1; then
    echo "PASS: push a forgejo no es vigilado (sale directo)"
else
    echo "FAIL: push a forgejo fue bloqueado indebidamente"; FAILED=1
fi

# 3) Secreto plantado en el diff: bloqueado
git checkout -q -b test-secreto
echo "mipassword = ghp_ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghij" > secreto_test.txt
git add secreto_test.txt
git -c core.hooksPath=/dev/null commit -q -m "test secreto"
S2=$(git rev-parse HEAD)
if run_hook "$S2" "$GITHUB_URL" >/dev/null 2>&1; then
    echo "FAIL: secreto pasó el portero"; FAILED=1
else
    echo "PASS: secreto bloqueado"
fi
git checkout -q main && git branch -qD test-secreto && rm -f secreto_test.txt

if [ "$FAILED" = "0" ]; then echo "== PORTERO OK =="; else echo "== HAY FALLOS =="; exit 1; fi
