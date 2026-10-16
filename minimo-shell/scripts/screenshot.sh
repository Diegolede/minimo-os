#!/bin/sh
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Diego Ledesma (TRN1) — Minimo OS
# Captura de pantalla:  screenshot.sh area | full
# Guarda en ~/Imágenes/Capturas (nombre con milisegundos: dos capturas seguidas nunca se pisan)
# y la deja en el portapapeles como image/png (wl-copy queda sirviéndola en segundo plano).
d="$HOME/Imágenes/Capturas"
mkdir -p "$d" || exit 1
f="$d/captura-$(date +%Y%m%d-%H%M%S-%3N).png"
case "$1" in
    area) g=$(slurp) || exit 0; grim -g "$g" "$f" || exit 1 ;;
    *) grim "$f" || exit 1 ;;
esac
[ -s "$f" ] || exit 1
wl-copy --type image/png < "$f"

# Aviso con miniatura (solo si la captura salió bien). gdbus viene con glib2: sin dependencias
# nuevas. image-path = la captura; x-minimo-open = archivo que abre un clic en el aviso.
q=$(printf '%s' "$f" | sed "s/'/\\\\'/g")
gdbus call --session --dest org.freedesktop.Notifications --object-path /org/freedesktop/Notifications \
    --method org.freedesktop.Notifications.Notify "Capturas" 0 "" "Captura guardada" "Copiada al portapapeles" "[]" \
    "{'image-path': <'file://$q'>, 'x-minimo-open': <'$q'>}" 4000 >/dev/null 2>&1 || true
