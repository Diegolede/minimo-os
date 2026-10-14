#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Diego Ledesma (TRN1) — Minimo OS
# Instalador de Minimo OS (Hyprland + minimo-shell) para Arch Linux.
# Uso:  ./install.sh [--dry-run] [--yes] [--preview] [--no-greeter]
#   o:  curl -fsSL https://raw.githubusercontent.com/Diegolede/minimo-os/main/install.sh | bash
#       (con opciones: ... | bash -s -- --dry-run)
# Si no se ejecuta desde una copia del repo, lo clona en ~/Proyectos/minimo-os y se
# vuelve a ejecutar desde ahí. Las preguntas se leen de /dev/tty (funciona con tubería).
# Es idempotente: se puede volver a correr sin romper nada.
set -euo pipefail

REPO_SLUG="Diegolede/minimo-os"
REPO_URL="https://github.com/$REPO_SLUG.git"
DEST="$HOME/Proyectos/minimo-os"
TS=$(date +%Y%m%d-%H%M%S)

DRY=0; YES=0; PREVIEW=0; GREETER=1
for a in "$@"; do
    case "$a" in
        --dry-run|-n) DRY=1 ;;
        --yes|-y) YES=1 ;;
        --greeter) GREETER=1 ;;          # pantalla de inicio de Minimo (greetd, por defecto)
        --no-greeter) GREETER=0 ;;       # conservar el gestor de sesión actual (GDM, SDDM...)
        --preview) PREVIEW=1; DRY=1 ;;   # muestra la interfaz sin comprobar ni cambiar nada
        -h|--help) sed -n '2,5p' "$0" 2>/dev/null || true; exit 0 ;;
        *) echo "Opción desconocida: $a" >&2; exit 2 ;;
    esac
done

# --- salida ---
if [ -t 1 ] || [ "$PREVIEW" = 1 ]; then
    B=$'\e[1m'; G=$'\e[32m'; Y=$'\e[33m'; R=$'\e[31m'; C=$'\e[36m'; D=$'\e[2m'; N=$'\e[0m'
else B=; G=; Y=; R=; C=; D=; N=; fi
TOTAL=9; STEP=0; WARNS=0; T0=$SECONDS
# Minimo y título con caracteres de densidad (el mismo algoritmo que terminal/minimo-hello)
HDR_MINIMO=( "         ......"
             "     .:++%%%%%%++:."
             "   .++\$\$\$\$\$\$\$\$\$\$\$\$++."
             "  :+%\$\$%+%\$\$\$\$%+%\$\$%+:"
             " :+%\$\$+   +\$\$+   +\$\$%+:"
             " :+\$\$\$+   +\$\$+   +\$\$\$+:"
             " :+\$\$\$+   +\$\$+   +\$\$\$+:"
             " :+%\$\$\$%+%\$\$\$\$%+%\$\$\$%+:"
             "  :+%\$\$\$\$\$\$\$\$\$\$\$\$\$\$%+:"
             "   .++\$\$\$\$\$\$\$\$\$\$\$\$++."
             "     .:++%%%%%%++:."
             "         ......" )
HDR_TITLE=( " .\$\$\$.   \$\$\$+ \$\$ +\$\$:   \$\$ +\$+ \$\$\$.   %\$\$%  +\$\$\$\$\$+      +\$\$\$\$\$%.  %\$\$%\$\$:"
            " .\$\$\$\$  +\$\$\$+ \$\$ +\$\$\$+  \$\$ +\$+ \$\$\$\$  :\$\$\$% \$\$:   :\$\$    %\$+   .\$\$.+\$%   ++"
            " .\$%+\$+.\$%+\$+ \$\$ +\$+:\$%.\$\$ +\$+ \$\$:\$% \$\$:\$%.\$\$     \$\$.   \$\$     %\$: +%\$\$\$%:"
            " .\$% %\$\$\$ +\$+ \$\$ +\$+ .\$\$\$\$ +\$+ \$\$ +\$\$\$.:\$% \$\$:   :\$\$    %\$+   .\$\$.:%.  .\$\$."
            " .\$% .\$\$: +\$+ \$\$ +\$+   %\$\$ +\$+ \$\$  \$\$+ :\$%  +\$\$\$\$\$+      +\$\$\$\$\$%. .%\$\$%\$\$+" )
header() {
    local cols=${COLUMNS:-$(tput cols 2>/dev/null || echo 80)} l
    printf '\n'
    for l in "${HDR_MINIMO[@]}"; do printf '   %s%s%s\n' "$B" "$l" "$N"; done
    printf '\n'
    if [ "$cols" -ge 82 ]; then for l in "${HDR_TITLE[@]}"; do printf '   %s%s%s\n' "$B" "$l" "$N"; done
    else printf '   %sM I N I M O   O S%s\n' "$B" "$N"; fi
    printf '\n   %sInstalador · Hyprland + minimo-shell · Arch Linux%s\n' "$D" "$N"
    printf '   %s──────────────────────────────────────────────────────────%s\n' "$D" "$N"
}
step() {
    STEP=$((STEP+1))
    local bar="" i
    for ((i=1; i<=TOTAL; i++)); do if [ $i -le $STEP ]; then bar+="━"; else bar+="─"; fi; done
    printf '\n   %s%d/%d%s  %s%s%s  %s%s%s\n' "$D" "$STEP" "$TOTAL" "$N" "$B" "$*" "$N" "$D" "$bar" "$N"
}
substep() { printf '\n   %s···%s  %s%s%s\n' "$D" "$N" "$B" "$*" "$N"; }
ok()   { printf '        %s✓%s %s\n' "$G" "$N" "$*"; }
warn() { WARNS=$((WARNS+1)); printf '        %s!%s %s\n' "$Y" "$N" "$*"; }
die()  { printf '\n        %s✗ %s%s\n\n' "$R" "$*" "$N" >&2; exit 1; }
# spin MSG CMD...: comando silencioso con indicador (sólo en terminal; nunca para sudo interactivo)
spin() {
    local msg=$1; shift
    if [ "$DRY" = 1 ]; then printf '        %s○ %s%s\n' "$D" "$msg" "$N"; return 0; fi
    if [ ! -t 1 ]; then "$@" >/dev/null 2>&1 && ok "$msg" || { printf '        %s✗%s %s\n' "$R" "$N" "$msg"; return 1; }; return 0; fi
    "$@" >/dev/null 2>&1 & local pid=$! f='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏' i=0
    while kill -0 $pid 2>/dev/null; do printf '\r        %s%s%s %s' "$C" "${f:i++%10:1}" "$N" "$msg"; sleep 0.08; done
    if wait $pid; then printf '\r        %s✓%s %s\e[K\n' "$G" "$N" "$msg"
    else printf '\r        %s✗%s %s\e[K\n' "$R" "$N" "$msg"; return 1; fi
}
# run: ejecuta (o solo muestra en --dry-run)
run() {
    if [ "$DRY" = 1 ]; then printf '        %s○ %s%s\n' "$D" "$*" "$N"
    else printf '        %s› %s%s\n' "$D" "$*" "$N"; "$@"; fi
}
# confirm_no: pregunta con "no" por defecto (para cambios de sistema opcionales)
confirm_no() {
    [ "$DRY" = 1 ] && return 1
    [ "$YES" = 1 ] && return 1
    local r; read -r -p "        $1 [s/N] " r </dev/tty || r=n
    case "${r,,}" in s|si|sí|y|yes) return 0 ;; *) return 1 ;; esac
}
confirm() {
    [ "$YES" = 1 ] && return 0
    [ "$DRY" = 1 ] && return 0
    local r; read -r -p "        $1 [S/n] " r </dev/tty || r=s
    case "${r,,}" in n|no) return 1 ;; *) return 0 ;; esac
}
header

# --- comprobaciones ---
step "Comprobaciones"
if [ "$PREVIEW" = 1 ]; then ok "Arch Linux, usuario ${USER:-$(id -un)} (vista previa)"
else
    command -v pacman >/dev/null || die "Esto no parece Arch Linux (falta pacman)."
    [ "$(id -u)" -ne 0 ] || die "No lo ejecutes como root; usa tu usuario (se pedirá sudo)."
    command -v sudo >/dev/null || die "Falta sudo."
    ok "Arch Linux, usuario $USER"
fi
[ "$DRY" = 1 ] && warn "Modo prueba: no se cambia nada."

# --- repo: si no se ejecuta desde dentro del repo, clonarlo ---
SELF_DIR=""
if [ -f "${BASH_SOURCE[0]:-}" ]; then SELF_DIR=$(cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")" && pwd); fi
if [ -n "$SELF_DIR" ] && [ -d "$SELF_DIR/minimo-shell" ] && [ -d "$SELF_DIR/hypr" ]; then
    REPO="$SELF_DIR"
else
    REPO="$DEST"
    substep "Repositorio"
    if [ -d "$REPO/.git" ]; then
        ok "Ya existe $REPO (git pull)"
        run git -C "$REPO" pull --ff-only || warn "No se pudo actualizar; sigo con lo que hay."
    else
        command -v git >/dev/null || run sudo pacman -S --needed --noconfirm git
        run mkdir -p "$(dirname "$REPO")"
        if command -v gh >/dev/null && gh auth status >/dev/null 2>&1; then
            run gh repo clone "$REPO_SLUG" "$REPO"
        else
            run git clone "$REPO_URL" "$REPO"
        fi
    fi
    # Continuar con el instalador del repo clonado (la copia por tubería puede ser vieja).
    if [ -f "$REPO/install.sh" ] && [ -z "${MINIMO_REEXEC:-}" ]; then
        ok "Continuando desde $REPO/install.sh"
        MINIMO_REEXEC=1 exec bash "$REPO/install.sh" "$@"
    fi
    if [ ! -d "$REPO/minimo-shell" ]; then
        [ "$DRY" = 1 ] && { warn "En --dry-run no se clona: el resto se mostraría después de clonar."; exit 0; }
        die "No se pudo obtener el repositorio en $REPO (si es privado: gh auth login)."
    fi
fi
ok "Repo: $REPO"

# --- paquetes (todos en los repos oficiales: extra) ---
PKGS=(
    hyprland xdg-desktop-portal-hyprland hyprpolkitagent       # compositor, portal, polkit
    quickshell qt6-declarative qt6-svg qt6-wayland             # shell (QtQuick, Effects, iconos SVG)
    pipewire pipewire-pulse wireplumber                        # audio (Pipewire en la shell)
    cava playerctl                                             # niveles de audio (baile), teclas multimedia
    ghostty grim slurp wf-recorder zenity                      # terminal, capturas, grabación, selector de fondo
    adwaita-fonts                                              # tipografía Adwaita Sans
    networkmanager                                             # Wi-Fi en la isla (nmcli)
    gnome-keyring                                              # llavero (se desbloquea al iniciar sesión)
    python lua                                                 # scripts de la shell (cursor, estado, escritorios, atajos)
    git
)
OPTIONAL=(fuzzel wl-clipboard github-cli)
step "Paquetes"
missing=()
for p in "${PKGS[@]}"; do { [ "$PREVIEW" = 0 ] && pacman -Q "$p" >/dev/null 2>&1; } || missing+=("$p"); done
if [ ${#missing[@]} -eq 0 ]; then ok "Todo instalado"
else
    warn "Faltan: ${missing[*]}"
    if confirm "¿Instalar con pacman?"; then run sudo pacman -S --needed --noconfirm "${PKGS[@]}"; else die "Cancelado."; fi
fi
# Marcar como instalados explícitamente: así `pacman -Rns` de otro paquete (p. ej. otra shell)
# nunca los borra como dependencias huérfanas.
deps=()
for p in "${PKGS[@]}"; do [ "$PREVIEW" = 0 ] && pacman -Qqd "$p" >/dev/null 2>&1 && deps+=("$p"); done
if [ ${#deps[@]} -gt 0 ]; then run sudo pacman -D --asexplicit "${deps[@]}"; fi
optmissing=()
for p in "${OPTIONAL[@]}"; do { [ "$PREVIEW" = 0 ] && pacman -Q "$p" >/dev/null 2>&1; } || optmissing+=("$p"); done
if [ ${#optmissing[@]} -gt 0 ]; then
    if confirm "¿Instalar opcionales (${optmissing[*]})?"; then run sudo pacman -S --needed --noconfirm "${optmissing[@]}"; fi
else ok "Opcionales instalados"; fi

# --- enlaces ---
# link SRC DST: symlink idempotente; respalda un archivo real existente.
link() {
    local src=$1 dst=$2
    if [ -L "$dst" ] && [ "$(readlink -f "$dst")" = "$(readlink -f "$src")" ]; then ok "$dst"; return; fi
    run mkdir -p "$(dirname "$dst")"
    run ln -sfn "$src" "$dst"
}

step "Configuración de Hyprland"
HYPR="$HOME/.config/hypr"
needs_backup=0
if [ -e "$HYPR" ]; then
    # solo respaldar si hay algo que no sea ya un enlace a este repo
    while IFS= read -r -d '' f; do
        case "$f" in */monitores.lua) continue ;; esac
        [ -L "$f" ] && [[ "$(readlink -f "$f")" == "$REPO"/* ]] && continue
        needs_backup=1; break
    done < <(find "$HYPR" \( -type f -o -type l \) -name '*.lua' -print0)
fi
if [ "$needs_backup" = 1 ]; then
    run cp -a "$HYPR" "$HYPR.bak-$TS"
    ok "Respaldo: $HYPR.bak-$TS"
fi
link "$REPO/hypr/hyprland.lua" "$HYPR/hyprland.lua"
link "$REPO/hypr/minimo.lua"   "$HYPR/minimo.lua"
for f in "$REPO"/hypr/minimo/*.lua; do
    n=$(basename "$f")
    [ "$n" = monitores.lua ] && continue
    link "$f" "$HYPR/minimo/$n"
done
# Monitores: específico de cada PC → copia (auto) solo si no existe.
MON="$HYPR/minimo/monitores.lua"
if [ -f "$MON" ] && [ ! -L "$MON" ]; then ok "$MON (se conserva el de esta PC)"
else
    [ -L "$MON" ] && run rm -f "$MON"
    run install -Dm644 "$REPO/hypr/minimo/monitores.lua" "$MON"
fi

step "Fondos de pantalla"
WALL="$HOME/Imágenes/Fondos"
run mkdir -p "$WALL"
for f in "$REPO"/assets/wallpapers/*; do
    [ -e "$WALL/$(basename "$f")" ] && { ok "$WALL/$(basename "$f")"; continue; }
    run cp "$f" "$WALL/"
done

step "Notificaciones y bandeja"
# La isla es el servidor de notificaciones: otro daemon activo se quedaría con el nombre en D-Bus.
for d in mako dunst swaync; do
    if pgrep -x "$d" >/dev/null 2>&1; then warn "$d está corriendo: cerralo y quitalo del autoarranque (la isla muestra las notificaciones)."; fi
done
ok "Las notificaciones las muestra la isla"
# La isla también es la bandeja del sistema (StatusNotifierWatcher): otra barra con bandeja
# se quedaría con el nombre y las apps en segundo plano no aparecerían en la isla.
for d in waybar snixembed; do
    if pgrep -x "$d" >/dev/null 2>&1; then warn "$d está corriendo: puede quedarse con la bandeja del sistema (apps en segundo plano)."; fi
done

step "Terminal: Ghostty + Minimo"
# Saludo de Minimo al abrir la terminal
link "$REPO/terminal/minimo-hello" "$HOME/.local/bin/minimo-hello"
# Configuración de Ghostty: enlace al repo; se respalda una config propia existente
GCONF="$HOME/.config/ghostty/config"
if [ -e "$GCONF" ] && ! { [ -L "$GCONF" ] && [ "$(readlink -f "$GCONF")" = "$(readlink -f "$REPO/terminal/ghostty/config")" ]; }; then
    run mv "$GCONF" "$GCONF.bak-$TS"
    ok "Respaldo: $GCONF.bak-$TS"
fi
link "$REPO/terminal/ghostty/config" "$GCONF"
# Fragmento idempotente para bash y zsh (sólo en shells interactivas de primer nivel)
add_hello() {
    local rc=$1 parent=$2
    [ -f "$rc" ] || { [ "$rc" = "$HOME/.bashrc" ] || return 0; }
    if grep -qs 'minimo-hello' "$rc"; then ok "$rc ya saluda"; return; fi
    local line="[[ \$- == *i* && \$(ps -o comm= -p \$PPID) != $parent ]] && [ -x ~/.local/bin/minimo-hello ] && ~/.local/bin/minimo-hello"
    if [ "$DRY" = 1 ]; then printf '        %s○ añadir saludo a %s%s\n' "$D" "$rc" "$N"; return; fi
    printf '\n# Minimo saluda al abrir la terminal\n%s\n' "$line" >> "$rc"
    ok "Saludo añadido a $rc"
}
add_hello "$HOME/.bashrc" bash
add_hello "$HOME/.zshrc" zsh

step "Navegador Helium"
# helium-browser-bin (AUR). Usa yay/paru si hay; si no, makepkg directo (sin instalar otro ayudante).
HELIUM=helium-browser-bin
if [ "$PREVIEW" = 0 ] && pacman -Q "$HELIUM" >/dev/null 2>&1; then ok "$HELIUM instalado"
elif confirm "¿Instalar Helium ($HELIUM, AUR)?"; then
    if command -v yay >/dev/null; then run yay -S --needed --noconfirm "$HELIUM"
    elif command -v paru >/dev/null; then run paru -S --needed --noconfirm "$HELIUM"
    else
        { [ "$PREVIEW" = 0 ] && pacman -Q base-devel >/dev/null 2>&1; } || run sudo pacman -S --needed --noconfirm base-devel
        if [ "$DRY" = 1 ]; then AURD=/tmp/minimo-aur; else AURD=$(mktemp -d); fi
        run git clone --depth 1 "https://aur.archlinux.org/$HELIUM.git" "$AURD/$HELIUM"
        if [ "$DRY" = 1 ]; then run makepkg -si --noconfirm   # en $AURD/$HELIUM
        else (cd "$AURD/$HELIUM" && makepkg -si --noconfirm) || warn "No se pudo instalar Helium; seguí sin él."; fi
        [ "$DRY" = 1 ] || rm -rf "$AURD"
    fi
else warn "Helium omitido"; fi

step "Pantalla de inicio"
# Por defecto: respalda la config de greetd, desactiva el gestor actual SIN detenerlo (tu
# sesión sigue) y activa greetd; se ve al reiniciar. Omitir: --no-greeter.
if [ "$GREETER" != 1 ]; then ok "Se mantiene el inicio de sesión actual (--no-greeter)"
else
    if [ "$DRY" = 1 ]; then bash "$REPO/greeter/install-greeter.sh" --dry-run | sed "s/^/   /"
    else bash "$REPO/greeter/install-greeter.sh" || warn "La pantalla de inicio no se instaló; tu inicio actual sigue igual."; fi
fi

step "Servicio de la shell (systemd --user)"
UNITS="$HOME/.config/systemd/user"
link "$REPO/systemd/minimo-shell.service" "$UNITS/minimo-shell.service"
link "$REPO/systemd/hyprland-session.target" "$UNITS/hyprland-session.target"
if [ "$REPO" != "$DEST" ]; then
    warn "El repo no está en $DEST: la unidad y el atajo Super+B asumen esa ruta."
fi
run systemctl --user daemon-reload
run systemctl --user enable minimo-shell.service
if [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
    run systemctl --user restart minimo-shell.service
    run hyprctl reload
else
    ok "Se iniciará al entrar en Hyprland"
fi

el=$((SECONDS-T0))
printf '\n   %s──────────────────────────────────────────────────────────%s\n' "$D" "$N"
if [ "$DRY" = 1 ]; then printf '\n   %s✓ Prueba completa.%s No se cambió nada.\n' "$B" "$N"
else printf '\n   %s%s✓ Minimo OS instalado%s %sen %dm %02ds%s\n' "$G" "$B" "$N" "$D" $((el/60)) $((el%60)) "$N"; fi
[ "$WARNS" -gt 0 ] && printf '   %s! %d aviso(s) arriba%s\n' "$Y" "$WARNS" "$N"
printf '\n   %sSiguiente%s   Cerrá sesión y entrá en Hyprland\n' "$D" "$N"
printf   '   %sTerminal%s    Abrí Ghostty: Minimo te saluda\n' "$D" "$N"
printf   '   %sRepo%s        %s\n' "$D" "$N" "$REPO"
printf   '   %sDesinstalar%s %s/uninstall.sh\n\n' "$D" "$N" "$REPO"
