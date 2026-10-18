#!/bin/sh
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Diego Ledesma (TRN1) — Minimo OS
# Uso: dialog-theme.sh claro|oscuro
# Cambia el tema del diálogo de contraseña (hyprpolkitagent → paleta de hyprtoolkit) junto con
# el de la shell. Solo toca ~/.config/hypr/hyprtoolkit.conf si es el enlace que puso install.sh
# (apunta a .../hypr/hyprtoolkit/*.conf); un archivo propio del usuario no se toca nunca.
set -eu
case "${1:-}" in claro|oscuro) ;; *) exit 2 ;; esac
cfg="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/hyprtoolkit.conf"
[ -L "$cfg" ] || exit 0
dest=$(readlink "$cfg")
case "$dest" in */hypr/hyprtoolkit/claro.conf|*/hypr/hyprtoolkit/oscuro.conf) ;; *) exit 0 ;; esac
want="$(dirname "$dest")/$1.conf"
[ "$dest" = "$want" ] && exit 0
[ -f "$want" ] || exit 0
ln -sfn "$want" "$cfg"
