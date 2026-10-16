#!/bin/sh
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Diego Ledesma (TRN1) — Minimo OS
# Abre el navegador o el gestor de archivos predeterminados.
#   open-default.sh browser | files
# Sale con 0 si se lanzó; si no, con 1 y un mensaje corto en stderr (lo muestra la isla).
set -u
launch_desktop() {   # $1 = archivo .desktop, resto = argumentos
    id=${1%.desktop}; shift
    [ -n "$id" ] && command -v gtk-launch >/dev/null 2>&1 && gtk-launch "$id" "$@" >/dev/null 2>&1
}
case "${1:-}" in
    browser)
        b=$(xdg-settings get default-web-browser 2>/dev/null || true)
        launch_desktop "$b" && exit 0
        command -v xdg-open >/dev/null 2>&1 && xdg-open "https://duckduckgo.com" >/dev/null 2>&1 && exit 0
        echo "No se pudo abrir el navegador." >&2; exit 1 ;;
    files)
        f=$(xdg-mime query default inode/directory 2>/dev/null || true)
        launch_desktop "$f" "$HOME" && exit 0
        command -v xdg-open >/dev/null 2>&1 && xdg-open "$HOME" >/dev/null 2>&1 && exit 0
        echo "No se pudo abrir el gestor de archivos." >&2; exit 1 ;;
    *) echo "uso: open-default.sh browser|files" >&2; exit 2 ;;
esac
