#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Diego Ledesma (TRN1) — Minimo OS
# Actualización desde Ajustes › Actualizaciones: git pull --ff-only + install.sh --update.
# Imprime líneas "@@..." para la shell (pasos, error, fin); todo el detalle va al registro
# ~/.cache/minimo-update.log. Nunca pide ni guarda contraseñas: si hacen falta paquetes
# nuevos, avisa (@@NEEDS_SUDO) y la shell ofrece pkexec o una terminal.
# Uso: update-run.sh [REPO]
set -uo pipefail
REPO=${1:-$(cd "$(dirname "$(realpath "$0")")/../.." && pwd)}
LOG="${XDG_CACHE_HOME:-$HOME/.cache}/minimo-update.log"
mkdir -p "$(dirname "$LOG")"
printf '\n===== %s  actualización =====\n' "$(date '+%F %T')" >> "$LOG"
say() { printf '@@%s\n' "$*"; }
fail() { say "ERROR $1"; printf '[error] %s\n' "$1" >> "$LOG"; exit 1; }
export GIT_TERMINAL_PROMPT=0 LC_ALL=C

say "STEP 0 9 Descargando la versión nueva"
before=$(git -C "$REPO" rev-parse HEAD 2>>"$LOG") || fail "repo"
if ! git -C "$REPO" pull --ff-only >>"$LOG" 2>&1; then
    if [ -n "$(git -C "$REPO" status --porcelain --untracked-files=no 2>/dev/null)" ]; then fail "dirty"
    elif ! git -C "$REPO" ls-remote --exit-code origin >/dev/null 2>&1; then fail "offline"
    else fail "pull"; fi
fi
after=$(git -C "$REPO" rev-parse HEAD)
say "PULLED $before $after"

MINIMO_PROGRESS=1 bash "$REPO/install.sh" --update 2>&1 | while IFS= read -r l; do
    printf '%s\n' "$l" | sed 's/\x1b\[[0-9;]*[a-zA-Z]//g' >> "$LOG"
    case "$l" in @@*) printf '%s\n' "$l" ;; esac
done
rc=${PIPESTATUS[0]}
[ "$rc" = 0 ] || fail "install"
say "VERSION $(tr -d '\n' < "$REPO/minimo-shell/VERSION" 2>/dev/null)"
say "FINISHED"
