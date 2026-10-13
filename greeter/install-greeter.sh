#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Diego Ledesma (TRN1) — Minimo OS
# Instala la pantalla de inicio de Minimo (greetd + cage + Quickshell). Idempotente.
# No detiene el gestor actual (GDM, SDDM...): sólo lo desactiva; el cambio se ve al reiniciar.
# Uso: greeter/install-greeter.sh [--dry-run] [--user NOMBRE]
set -euo pipefail
DRY=0; GUSER=${SUDO_USER:-${USER:-$(id -un)}}
while [ $# -gt 0 ]; do case "$1" in
    --dry-run|-n) DRY=1 ;;
    --user) GUSER=$2; shift ;;
    *) echo "Opción desconocida: $1" >&2; exit 2 ;;
esac; shift; done
SRC=$(cd "$(dirname "$(realpath "$0")")" && pwd)
DEST=/usr/share/minimo-os/greeter
TS=$(date +%Y%m%d-%H%M%S)
if [ -t 1 ]; then B=$'\e[1m'; G=$'\e[32m'; Y=$'\e[33m'; R=$'\e[31m'; D=$'\e[2m'; N=$'\e[0m'; else B=; G=; Y=; R=; D=; N=; fi
ok()   { printf '   %s✓%s %s\n' "$G" "$N" "$*"; }
warn() { printf '   %s!%s %s\n' "$Y" "$N" "$*"; }
die()  { printf '   %s✗ %s%s\n' "$R" "$*" "$N" >&2; exit 1; }
run()  { if [ "$DRY" = 1 ]; then printf '   %s○ %s%s\n' "$D" "$*" "$N"; else printf '   %s› %s%s\n' "$D" "$*" "$N"; "$@"; fi; }

printf '\n   %sPantalla de inicio de Minimo OS%s\n\n' "$B" "$N"
[ "$(id -u)" -ne 0 ] || die "Ejecutalo con tu usuario (se pedirá sudo)."
[ -f "$SRC/shell.qml" ] && [ -f "$SRC/Character/Character.qml" ] || die "No encuentro los archivos en $SRC"
getent passwd "$GUSER" >/dev/null || die "No existe el usuario $GUSER"
command -v qs >/dev/null || [ "$DRY" = 1 ] || die "Falta quickshell (lo instala install.sh)"
SESSION=minimo-session

# 1. Paquetes
missing=(); for p in greetd cage greetd-tuigreet; do pacman -Q "$p" >/dev/null 2>&1 || missing+=("$p"); done
if [ ${#missing[@]} -gt 0 ]; then run sudo pacman -S --needed --noconfirm "${missing[@]}"; else ok "greetd, cage y tuigreet instalados"; fi

# 2. Archivos (copia real: -L resuelve el enlace al personaje; nada apunta a tu ~)
run sudo rm -rf "$DEST.new"
run sudo install -d -m755 /usr/share/minimo-os /etc/minimo-os
run sudo cp -rL "$SRC" "$DEST.new"
run sudo rm -rf "$DEST.new/.git" "$DEST.new/preview.qml"
run sudo chmod -R a+rX,go-w "$DEST.new"
run sudo rm -rf "$DEST"
run sudo mv "$DEST.new" "$DEST"
run sudo install -Dm755 "$SRC/minimo-greeter" /usr/local/bin/minimo-greeter
run sudo install -Dm755 "$SRC/minimo-session" /usr/local/bin/minimo-session
if [ -f /etc/minimo-os/greeter.env ] && grep -Eq '^MINIMO_SESSION=(start-hyprland|Hyprland)$' /etc/minimo-os/greeter.env; then
    run sudo sed -i -E 's/^MINIMO_SESSION=(start-hyprland|Hyprland)$/MINIMO_SESSION=minimo-session/' /etc/minimo-os/greeter.env
    ok "/etc/minimo-os/greeter.env: sesión → minimo-session (sin texto de arranque)"
elif [ -f /etc/minimo-os/greeter.env ]; then ok "/etc/minimo-os/greeter.env (se conserva)"
elif [ "$DRY" = 1 ]; then printf '   %s○ crear /etc/minimo-os/greeter.env (MINIMO_USER=%s, MINIMO_SESSION=%s)%s\n' "$D" "$GUSER" "$SESSION" "$N"
else printf 'MINIMO_USER=%s\nMINIMO_SESSION=%s\nMINIMO_DARK=0\n' "$GUSER" "$SESSION" | sudo tee /etc/minimo-os/greeter.env >/dev/null; ok "/etc/minimo-os/greeter.env"; fi

# 3. Configuración de greetd (respaldo si había otra)
if [ -f /etc/greetd/config.toml ] && ! cmp -s /etc/greetd/config.toml "$SRC/config.toml"; then
    run sudo cp -a /etc/greetd/config.toml "/etc/greetd/config.toml.bak-$TS"; ok "Respaldo: /etc/greetd/config.toml.bak-$TS"
fi
run sudo install -Dm644 "$SRC/config.toml" /etc/greetd/config.toml
getent passwd greeter >/dev/null || [ "$DRY" = 1 ] || die "El paquete greetd no creó el usuario greeter"
# el greeter necesita la GPU y el teclado/mouse (seat): grupos video e input
[ "$DRY" = 1 ] || id -nG greeter | grep -qw video || run sudo usermod -aG video,input greeter

# 3b. Llavero de GNOME: se desbloquea con la clave del inicio (sólo si está instalado)
PAMF=/etc/pam.d/greetd
if pacman -Q gnome-keyring >/dev/null 2>&1 && [ -f "$PAMF" ]; then
    grep -Eq '^\s*auth\s+optional\s+pam_gnome_keyring\.so' "$PAMF" || { [ "$DRY" = 1 ] && run "añadir 'auth optional pam_gnome_keyring.so' a $PAMF" || { echo 'auth       optional     pam_gnome_keyring.so' | sudo tee -a "$PAMF" >/dev/null; ok "PAM: auth pam_gnome_keyring"; }; }
    grep -Eq '^\s*session\s+optional\s+pam_gnome_keyring\.so' "$PAMF" || { [ "$DRY" = 1 ] && run "añadir 'session optional pam_gnome_keyring.so auto_start' a $PAMF" || { echo 'session    optional     pam_gnome_keyring.so auto_start' | sudo tee -a "$PAMF" >/dev/null; ok "PAM: session pam_gnome_keyring"; }; }
    ok "Llavero de GNOME: se desbloquea al iniciar sesión"
else ok "Llavero de GNOME no instalado (se omite PAM)"; fi

# 4. Gestor de sesión: desactivar el actual SIN detenerlo; activar greetd
DM=$(basename "$(readlink -f /etc/systemd/system/display-manager.service 2>/dev/null)" .service 2>/dev/null || true)
if [ -n "$DM" ] && [ "$DM" != display-manager.service ] && [ "$DM" != display-manager ] && [ "$DM" != greetd ]; then
    run sudo systemctl disable "$DM.service"; ok "$DM desactivado (sigue corriendo hasta reiniciar)"
else DM=gdm; fi
run sudo systemctl enable greetd.service
ok "greetd activado"

printf '\n   %sListo.%s Reiniciá para ver la pantalla de Minimo.\n' "$B" "$N"
printf '   Probar antes sin reiniciar:  MINIMO_GREETER_TEST=1 qs -p %s  (clave: minimo)\n' "$DEST"
printf '\n   %sSi no arranca:%s Ctrl+Alt+F3, entrá con tu usuario y:\n' "$B" "$N"
printf '     sudo systemctl disable greetd && sudo systemctl enable %s && sudo reboot\n' "$DM"
printf '   Registro del greeter: /run/user/$(id -u greeter)/minimo-greeter/greeter.log\n\n'
