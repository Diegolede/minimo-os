#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Diego Ledesma (TRN1) — Minimo OS
# Desinstala Minimo OS: desactiva la shell y restaura el último respaldo de ~/.config/hypr.
# Uso: ./uninstall.sh [--dry-run] [--yes]   (no desinstala paquetes)
set -euo pipefail
DRY=0; YES=0
for a in "$@"; do case "$a" in --dry-run|-n) DRY=1 ;; --yes|-y) YES=1 ;; *) echo "Opción desconocida: $a" >&2; exit 2 ;; esac; done
if [ -t 1 ]; then G=$'\e[32m'; Y=$'\e[33m'; C=$'\e[36m'; D=$'\e[2m'; N=$'\e[0m'; else G=; Y=; C=; D=; N=; fi
run() { if [ "$DRY" = 1 ]; then printf '  %s[dry-run]%s %s\n' "$D" "$N" "$*"; else printf '  %s$ %s%s\n' "$D" "$*" "$N"; "$@"; fi; }
[ "$(id -u)" -ne 0 ] || { echo "No lo ejecutes como root." >&2; exit 1; }

printf '%s==>%s Servicio\n' "$C" "$N"
run systemctl --user disable --now minimo-shell.service || true
for u in minimo-shell.service hyprland-session.target; do
    [ -L "$HOME/.config/systemd/user/$u" ] && run rm -f "$HOME/.config/systemd/user/$u"
done
run systemctl --user daemon-reload

printf '%s==>%s Terminal\n' "$C" "$N"
[ -L "$HOME/.local/bin/minimo-hello" ] && run rm -f "$HOME/.local/bin/minimo-hello"
[ -L "$HOME/.config/ghostty/config" ] && run rm -f "$HOME/.config/ghostty/config"
printf '  %s!%s La línea de minimo-hello en ~/.bashrc queda inofensiva (comprueba que exista).\n' "$Y" "$N"

printf '%s==>%s Pantalla de inicio\n' "$C" "$N"
if [ -f /etc/greetd/config.toml ] && grep -q minimo-greeter /etc/greetd/config.toml 2>/dev/null; then
    printf '  %s!%s Para volver a GDM: sudo systemctl disable greetd && sudo systemctl enable gdm (y reiniciar).\n' "$Y" "$N"
    printf '  %s!%s Archivos: /usr/share/minimo-os/greeter, /usr/local/bin/minimo-greeter, /usr/local/bin/minimo-session (no se borran mientras greetd los use).\n' "$Y" "$N"
fi

printf '%s==>%s Hyprland\n' "$C" "$N"
HYPR="$HOME/.config/hypr"
last=$(ls -d "$HYPR".bak-* 2>/dev/null | sort | tail -1 || true)
if [ -z "$last" ]; then
    printf '  %s!%s No hay respaldo de %s; se deja como está.\n' "$Y" "$N" "$HYPR"
else
    if [ "$YES" = 0 ] && [ "$DRY" = 0 ]; then
        read -r -p "  ¿Restaurar $last? [S/n] " r </dev/tty || r=s
        case "${r,,}" in n|no) exit 0 ;; esac
    fi
    run rm -rf "$HYPR"
    run cp -a "$last" "$HYPR"
    printf '  %s✓%s Restaurado %s\n' "$G" "$N" "$last"
fi
printf '%sListo.%s Reiniciá la sesión. (Paquetes y fondos no se tocan.)\n' "$G" "$N"
