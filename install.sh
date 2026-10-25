#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Diego Ledesma (TRN1) — Minimo OS
# Instalador de Minimo OS (Hyprland + minimo-shell) para Arch Linux.
# Uso:  ./install.sh [--dry-run] [--yes] [--preview] [--no-greeter] [--update]
#   --update: actualización desde Ajustes › Actualizaciones (sin preguntas; no toca la
#   pantalla de inicio, opcionales ni Helium; no reinicia la shell ni la PC)
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

DRY=0; YES=0; PREVIEW=0; GREETER=1; GREETER_SET=0; UPDATE=0
for a in "$@"; do
    case "$a" in
        --dry-run|-n) DRY=1 ;;
        --yes|-y) YES=1 ;;
        --greeter) GREETER=1; GREETER_SET=1 ;;          # pantalla de inicio de Minimo (greetd, por defecto)
        --no-greeter) GREETER=0; GREETER_SET=1 ;;       # conservar el gestor de sesión actual (GDM, SDDM...)
        --preview) PREVIEW=1; DRY=1 ;;   # muestra la interfaz sin comprobar ni cambiar nada
        --update|-u) UPDATE=1; YES=1 ;;  # actualización: solo lo que cambió, sin preguntas
        -h|--help) cat <<'AYUDA'
Instalador de Minimo OS (Hyprland + minimo-shell) para Arch Linux.

Uso: ./install.sh [opciones]

  -n, --dry-run     Muestra lo que haría, sin cambiar nada
  -y, --yes         Responde que sí a todas las preguntas
      --preview     Vista previa de la interfaz del instalador (no comprueba nada)
      --greeter     Instala la pantalla de inicio de Minimo (por defecto)
      --no-greeter  Conserva tu pantalla de inicio actual (GDM, SDDM...)
  -u, --update      Actualiza sin preguntas (lo usa Ajustes › Actualizaciones)
  -h, --help        Esta ayuda

Variables: NO_COLOR=1 (sin colores)
Registro:  ~/.cache/minimo-install.log
AYUDA
            exit 0 ;;
        *) echo "Opción desconocida: $a" >&2; exit 2 ;;
    esac
done

# --- registro: todo lo que hacen pacman/yay/makepkg queda en este archivo ---
LOG="${XDG_CACHE_HOME:-$HOME/.cache}/minimo-install.log"
mkdir -p "$(dirname "$LOG")" 2>/dev/null && printf '\n===== %s  install.sh %s =====\n' "$(date '+%F %T')" "$*" >> "$LOG" 2>/dev/null || LOG=/dev/null
log() { printf '[%s] %s\n' "$(date +%T)" "$*" >> "$LOG" 2>/dev/null || true; }
# logrun CMD...: como run, pero la salida va también al registro (y se conserva el código de salida)
logrun() {
    if [ "$DRY" = 1 ]; then printf '        %s○ %s%s\n' "$D" "$*" "$N"; return 0; fi
    printf '        %s› %s%s\n' "$D" "$*" "$N"; log "\$ $*"
    "$@" 2>&1 | tee -a "$LOG"; return "${PIPESTATUS[0]}"
}
# Ctrl+C: mensaje claro (en qué paso quedó) y cursor visible otra vez.
trap '{ printf "\e[?25h" >/dev/tty; } 2>/dev/null; printf "\n\n        Instalación cancelada en el paso %s/%s (%s).\n        Volvé a ejecutar el instalador cuando quieras: retoma donde quedó.\n\n" "${STEP:-0}" "${TOTAL:-9}" "${STEP_NAME:-inicio}" >&2; exit 130' INT
trap 'rc=$?; { printf "\e[?25h" >/dev/tty; } 2>/dev/null || true; [ $rc -ne 0 ] && [ "$DRY" = 0 ] && printf "\n        Registro completo: %s\n        Podés volver a ejecutar el instalador: retoma donde quedó.\n\n" "$LOG" >&2' EXIT

# --- salida ---
if { [ -t 1 ] || [ "$PREVIEW" = 1 ]; } && [ -z "${NO_COLOR:-}" ]; then
    B=$'\e[1m'; G=$'\e[32m'; Y=$'\e[33m'; R=$'\e[31m'; C=$'\e[36m'; D=$'\e[2m'; N=$'\e[0m'
else B=; G=; Y=; R=; C=; D=; N=; fi
TOTAL=9; STEP=0; WARNS=0; T0=$SECONDS; TS_STEP=$SECONDS; STEP_NAME=""; WARN_LIST=()
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
# Con MINIMO_PROGRESS=1 (Ajustes › Actualizaciones) cada paso emite una línea legible por la shell.
progress() { [ "${MINIMO_PROGRESS:-0}" = 1 ] && printf '@@%s\n' "$*"; return 0; }
step() {
    # Duración del paso anterior (solo si tardó algo), en gris al pie del paso.
    if [ "$STEP" -gt 0 ] && [ $((SECONDS-TS_STEP)) -ge 2 ]; then printf '        %s· %ds%s\n' "$D" $((SECONDS-TS_STEP)) "$N"; fi
    TS_STEP=$SECONDS; STEP_NAME="$*"
    STEP=$((STEP+1)); progress "STEP $STEP $TOTAL $*"
    # Título de la ventana de la terminal: progreso visible aunque esté en otra pestaña.
    [ -t 1 ] && printf '\e]0;Minimo OS · %d/%d %s\a' "$STEP" "$TOTAL" "$*"
    local bar="" i
    for ((i=1; i<=TOTAL; i++)); do if [ $i -le $STEP ]; then bar+="━"; else bar+="─"; fi; done
    printf '\n   %s%d/%d%s  %s%s%s  %s%s %d%%%s\n' "$D" "$STEP" "$TOTAL" "$N" "$B" "$*" "$N" "$D" "$bar" $((STEP*100/TOTAL)) "$N"
}
substep() { printf '\n   %s···%s  %s%s%s\n' "$D" "$N" "$B" "$*" "$N"; }
ok()   { printf '        %s✓%s %s\n' "$G" "$N" "$*"; }
warn() { WARNS=$((WARNS+1)); WARN_LIST+=("$*"); printf '        %s!%s %s\n' "$Y" "$N" "$*"; }
die()  { printf '\n        %s✗ %s%s\n\n' "$R" "$*" "$N" >&2; exit 1; }
# spin MSG CMD...: comando silencioso con indicador (sólo en terminal; nunca para sudo interactivo)
spin() {
    local msg=$1; shift
    if [ "$DRY" = 1 ]; then printf '        %s○ %s%s\n' "$D" "$msg" "$N"; return 0; fi
    if [ ! -t 1 ]; then "$@" >/dev/null 2>&1 && ok "$msg" || { printf '        %s✗%s %s\n' "$R" "$N" "$msg"; return 1; }; return 0; fi
    printf '\e[?25l'                     # sin cursor parpadeando sobre el indicador
    "$@" >/dev/null 2>&1 & local pid=$! f='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏' i=0
    while kill -0 $pid 2>/dev/null; do printf '\r        %s%s%s %s' "$C" "${f:i++%10:1}" "$N" "$msg"; sleep 0.08; done
    printf '\e[?25h'
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
    local r; read -r -p "        $1 ${D}[s/N · Enter = no]${N} " r </dev/tty || r=n
    case "${r,,}" in s|si|sí|y|yes) return 0 ;; *) return 1 ;; esac
}
confirm() {
    [ "$YES" = 1 ] && return 0
    [ "$DRY" = 1 ] && return 0
    local r; read -r -p "        $1 ${D}[S/n · Enter = sí]${N} " r </dev/tty || r=s
    case "${r,,}" in n|no) return 1 ;; *) return 0 ;; esac
}
header

# Plan: qué va a pasar antes de tocar nada (no en actualizaciones ni con --yes).
if [ "$UPDATE" = 0 ]; then
    printf '\n   %sQué va a pasar%s  %s(unos 5–15 min según tu conexión)%s\n' "$B" "$N" "$D" "$N"
    for l in "Comprobar el sistema e internet" "Instalar Hyprland, la shell y lo necesario (pacman)" \
             "Enlazar la configuración (se respalda lo tuyo)" "Pantalla de inicio de Minimo y servicios"; do
        printf '        %s·%s %s\n' "$D" "$N" "$l"
    done
    printf '        %sNada se borra: lo que se reemplaza queda con .bak-%s%s\n' "$D" "$TS" "$N"
    if [ "$YES" = 0 ] && [ "$DRY" = 0 ]; then confirm "¿Empezar?" || { printf '\n        Nada cambió. Hasta la próxima.\n\n'; exit 0; }; fi
fi

# --- comprobaciones ---
step "Comprobaciones"
if [ "$PREVIEW" = 1 ]; then ok "Arch Linux, usuario ${USER:-$(id -un)} (vista previa)"
else
    command -v pacman >/dev/null || die "Esto no parece Arch Linux (falta pacman)."
    [ "$(id -u)" -ne 0 ] || die "No lo ejecutes como root; usa tu usuario (se pedirá sudo)."
    command -v sudo >/dev/null || die "Falta sudo."
    DISTRO=$( . /etc/os-release 2>/dev/null; echo "${NAME:-Arch Linux}" )
    case "$( . /etc/os-release 2>/dev/null; echo "${ID:-} ${ID_LIKE:-}" )" in
        *arch*) ok "$DISTRO, usuario $USER" ;;
        *) warn "$DISTRO no es Arch: puede funcionar, pero no está probado." ;;
    esac
    [ "$DRY" = 1 ] || [ "$UPDATE" = 1 ] || sudo -v || die "No se pudo usar sudo (¿tu usuario está en el grupo wheel?)."
    # Internet: sin conexión no hay paquetes
    if curl -fsI --max-time 10 https://archlinux.org >/dev/null 2>&1 || curl -fsI --max-time 10 https://github.com >/dev/null 2>&1
    then ok "Conexión a internet"
    else die "Sin conexión a internet (o no resuelve DNS). Conectate y volvé a intentar."; fi
    # Espacio: ~3 GB libres en / para paquetes, 1 GB en tu carpeta
    freeroot=$(df -Pk / | awk 'NR==2{print int($4/1048576)}'); freehome=$(df -Pk "$HOME" | awk 'NR==2{print int($4/1048576)}')
    [ "$freeroot" -ge 3 ] || die "Poco espacio en / (${freeroot} GB libres, hacen falta 3). Probá: sudo pacman -Sc"
    [ "$freehome" -ge 1 ] || die "Poco espacio en tu carpeta (${freehome} GB libres)."
    ok "Espacio libre: ${freeroot} GB"
    # Otro escritorio (KDE Plasma, GNOME): conviven; se conserva su pantalla de inicio
    OTHER_DE=""
    pacman -Q plasma-workspace >/dev/null 2>&1 && OTHER_DE="KDE Plasma"
    [ -z "$OTHER_DE" ] && pacman -Q gnome-shell >/dev/null 2>&1 && OTHER_DE="GNOME"
    if [ -n "$OTHER_DE" ]; then
        ok "$OTHER_DE detectado: se conserva; vas a elegir Hyprland o $OTHER_DE al iniciar sesión"
        [ "$GREETER_SET" = 1 ] || GREETER=0
    fi
fi
ok "Registro: $LOG"
[ "$DRY" = 1 ] && printf '        %s○ Modo prueba: no se cambia nada.%s\n' "$D" "$N"   # informativo, no cuenta como aviso

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
        command -v git >/dev/null || run sudo pacman -Sy --needed --noconfirm git
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
    adwaita-fonts noto-fonts-emoji                             # tipografía Adwaita Sans, emojis (selector de la isla)
    networkmanager                                             # Wi-Fi en la isla (nmcli)
    wl-clipboard cliphist                                      # historial del portapapeles
    gnome-keyring                                              # llavero (se desbloquea al iniciar sesión)
    python lua                                                 # scripts de la shell (cursor, estado, escritorios, atajos)
    git
)
OPTIONAL=(fuzzel github-cli pacman-contrib)   # pacman-contrib: checkupdates (Ajustes › Actualizaciones)
# --- paquetes: base robusta (reintentos, llavero, bloqueo, conflictos, uno por uno, AUR) ---
FAILED=(); FAILED_OPT=(); NEED_REBOOT=0; PACCONF=/etc/pacman.conf
# retry N CMD...: reintenta con espera creciente (3 s, 6 s...); antes de cada reintento libera el bloqueo
retry() {
    local n=$1 i; shift
    for ((i=1; i<=n; i++)); do
        "$@" && return 0
        [ "$DRY" = 1 ] && return 0
        [ $i -lt $n ] && { log "fallo (intento $i/$n): $*"; printf '        %s· reintento %d/%d en %ds%s\n' "$D" $((i+1)) "$n" $((i*3)) "$N"; sleep $((i*3)); pac_unlock; }
    done
    return 1
}
# pac: pacman con la configuración activa (puede ser la de emergencia con espejo oficial)
pac() { logrun sudo pacman --config "$PACCONF" "$@"; }
pac_unlock() {
    local lck=/var/lib/pacman/db.lck w=0
    [ -e "$lck" ] || return 0
    while pgrep -x 'pacman|yay|paru|pamac|pamac-daemon|packagekitd|discover' >/dev/null 2>&1 && [ $w -lt 60 ]; do
        [ $w = 0 ] && warn "Hay otro gestor de paquetes trabajando (¿Discover?); espero a que termine..."
        sleep 2; w=$((w+1))
    done
    if [ -e "$lck" ] && ! pgrep -x 'pacman|yay|paru|pamac|pamac-daemon' >/dev/null 2>&1; then
        warn "pacman quedó bloqueado por una instalación anterior interrumpida; quito el bloqueo."
        run sudo rm -f "$lck"
    fi
}
# Espejo de emergencia: si los espejos de la PC fallan, se usa el oficial (solo para esta instalación).
pac_fallback_mirror() {
    [ "$PACCONF" != /etc/pacman.conf ] && return 1
    local tmp; tmp=$(mktemp /tmp/minimo-pacman.XXXX.conf)
    sed -E 's#^Include *= */etc/pacman\.d/mirrorlist#Server = https://geo.mirror.pkgbuild.com/$repo/os/$arch\nInclude = /etc/pacman.d/mirrorlist#' /etc/pacman.conf > "$tmp"
    PACCONF=$tmp; warn "Tus espejos de descarga fallan; uso el espejo oficial de Arch para esta instalación."
}
pac_prepare() {
    [ "$DRY" = 1 ] && { printf '        %s○ preparar pacman: bloqueo, llavero, bases de datos, actualización%s\n' "$D" "$N"; return 0; }
    pac_unlock
    if ! retry 3 pac -Sy --noconfirm; then
        pac_fallback_mirror && retry 2 pac -Syy --noconfirm || { FAILED+=("(bases de datos)"); return 1; }
    fi
    ok "Bases de datos sincronizadas"
    # Llavero viejo = "firma inválida / clave desconocida" al instalar: se actualiza primero.
    if retry 3 pac -S --needed --noconfirm archlinux-keyring; then ok "Llavero de Arch al día"
    else warn "No se pudo actualizar el llavero (si ves 'firma inválida': sudo pacman-key --populate archlinux)."; fi
    # Instalar sobre bases nuevas sin actualizar el sistema deja versiones mezcladas (bibliotecas
    # que no encajan, paquetes que no se instalan). Si hay actualizaciones, se actualiza primero.
    local n; n=$(pacman --config "$PACCONF" -Qu 2>/dev/null | wc -l)
    if [ "$n" -gt 0 ]; then
        warn "Hay $n actualización(es) pendientes del sistema."
        if confirm "¿Actualizar el sistema primero? (recomendado: evita errores de paquetes)"; then
            local kbefore; kbefore=$(pacman -Q linux linux-lts linux-zen 2>/dev/null)
            if retry 3 pac -Syu --noconfirm; then ok "Sistema actualizado"
                [ "$kbefore" != "$(pacman -Q linux linux-lts linux-zen 2>/dev/null)" ] && NEED_REBOOT=1
            else warn "La actualización falló; sigo igual (detalles en $LOG)."; fi
        else warn "Sin actualizar: algunos paquetes podrían fallar."; fi
    fi
}
# Conflictos (p. ej. pulseaudio frente a pipewire-pulse): se pregunta antes de reemplazar.
pac_conflicts() {
    local p c
    for p in "$@"; do
        while read -r c; do
            [ -n "$c" ] && [ "$c" != None ] || continue
            c=${c%%[<>=]*}
            pacman -Q "$c" >/dev/null 2>&1 || continue
            pacman -Q "$p" >/dev/null 2>&1 && continue
            warn "$p reemplaza a $c (instalado)."
            if confirm "¿Reemplazar $c por $p? (KDE Plasma sigue funcionando igual)"; then
                retry 2 logrun sudo pacman --config "$PACCONF" -S --noconfirm --ask=4 "$p" || true
            fi
        done < <(LC_ALL=C pacman --config "$PACCONF" -Si "$p" 2>/dev/null | sed -n 's/^Conflicts With *: //p' | tr ' ' '\n')
    done
}
# AUR: usa yay/paru; si no hay, ofrece instalar yay-bin (una sola vez).
aur_helper() {
    command -v yay >/dev/null && { echo yay; return; }
    command -v paru >/dev/null && { echo paru; return; }
    [ "$DRY" = 1 ] && { echo yay; return; }
    confirm "No hay ayudante de AUR. ¿Instalar yay (necesario para paquetes del AUR)?" >&2 || return 1
    pac -S --needed --noconfirm base-devel git >&2 || return 1
    local d; d=$(mktemp -d)
    if logrun git clone --depth 1 https://aur.archlinux.org/yay-bin.git "$d/yay-bin" >&2 && (cd "$d/yay-bin" && logrun makepkg -si --noconfirm) >&2
    then rm -rf "$d"; echo yay; else rm -rf "$d"; return 1; fi
}
aur_install() { local h; h=$(aur_helper) || return 1; retry 2 logrun "$h" -S --needed --noconfirm "$@"; }
# pkg_install LISTA VAR_FALLOS: todo junto; si falla, uno por uno (y AUR si no está en los repos)
pkg_install() {
    local -n _fail=$1; shift
    local todo=() p
    for p in "$@"; do pacman -Q "$p" >/dev/null 2>&1 || todo+=("$p"); done
    [ ${#todo[@]} -eq 0 ] && return 0
    [ "$DRY" = 1 ] && { run sudo pacman -S --needed --noconfirm "${todo[@]}"; return 0; }
    # Lo que no está en los repos oficiales no frena al resto: va directo al paso uno por uno / AUR
    local repo=() other=()
    for p in "${todo[@]}"; do if pacman --config "$PACCONF" -Si "$p" >/dev/null 2>&1; then repo+=("$p"); else other+=("$p"); fi; done
    pac_conflicts "${repo[@]}"
    if [ ${#repo[@]} -gt 0 ] && retry 3 pac -S --needed --noconfirm "${repo[@]}"; then ok "Instalados: ${repo[*]}"; todo=("${other[@]}")
    elif [ ${#repo[@]} -gt 0 ]; then warn "La instalación en bloque falló; pruebo paquete por paquete."; fi
    [ ${#todo[@]} -eq 0 ] && return 0
    for p in "${todo[@]}"; do
        pacman -Q "$p" >/dev/null 2>&1 && continue
        if pacman --config "$PACCONF" -Si "$p" >/dev/null 2>&1; then
            if retry 2 pac -S --needed --noconfirm "$p"; then ok "$p"; continue; fi
        elif aur_install "$p"; then ok "$p (AUR)"; continue; fi
        printf '        %s✗%s %s\n' "$R" "$N" "$p"; _fail+=("$p")
    done
}
step "Paquetes"
if [ "$PREVIEW" = 1 ]; then ok "Todo instalado (vista previa)"
else
    missing=()
    for p in "${PKGS[@]}"; do pacman -Q "$p" >/dev/null 2>&1 || missing+=("$p"); done
    if [ ${#missing[@]} -eq 0 ]; then ok "Todo instalado"
    elif [ "$UPDATE" = 1 ] && [ ! -t 0 ] && ! sudo -n true 2>/dev/null; then
        # Sin terminal no se puede pedir la contraseña: la shell ofrece instalarlos con pkexec
        # (diálogo del sistema) o abrir el instalador en una terminal. Nunca se guarda la contraseña.
        progress "NEEDS_SUDO ${missing[*]}"
        die "Faltan paquetes nuevos (${missing[*]}): hace falta tu contraseña para instalarlos."
    else
        warn "Faltan: ${missing[*]}"
        confirm "¿Instalar con pacman?" || die "Cancelado."
    fi
    if [ ${#missing[@]} -gt 0 ] || [ "$DRY" = 1 ]; then pac_prepare || true; pkg_install FAILED "${missing[@]}"; fi
    # Marcar como instalados explícitamente: así `pacman -Rns` de otro paquete (p. ej. otra shell)
    # nunca los borra como dependencias huérfanas.
    deps=()
    for p in "${PKGS[@]}"; do pacman -Qqd "$p" >/dev/null 2>&1 && deps+=("$p"); done
    if [ ${#deps[@]} -gt 0 ]; then run sudo pacman -D --asexplicit "${deps[@]}" >/dev/null || true; fi
    optmissing=()
    for p in "${OPTIONAL[@]}"; do pacman -Q "$p" >/dev/null 2>&1 || optmissing+=("$p"); done
    if [ "$UPDATE" = 1 ]; then ok "Opcionales: sin cambios (actualización)"
    elif [ ${#optmissing[@]} -gt 0 ]; then
        if confirm "¿Instalar opcionales (${optmissing[*]})?"; then pkg_install FAILED_OPT "${optmissing[@]}"; fi
    else ok "Opcionales instalados"; fi
    if [ ${#FAILED[@]} -gt 0 ]; then
        warn "No se instalaron: ${FAILED[*]}"
        confirm "¿Seguir igual con la configuración? (al volver a ejecutar se reintentan)" || die "Detenido. Registro: $LOG"
    fi
fi

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
# Diálogo de contraseña: hyprpolkitagent ≥ 0.2 dibuja con hyprtoolkit, que toma colores,
# fuente y redondeo de ~/.config/hypr/hyprtoolkit.conf. Se enlaza la paleta de Minimo solo si
# no hay uno propio (la shell alterna claro/oscuro con scripts/dialog-theme.sh).
HTK="$HYPR/hyprtoolkit.conf"
if [ -L "$HTK" ] && [[ "$(readlink -f "$HTK")" == "$REPO"/hypr/hyprtoolkit/* ]]; then ok "$HTK"
elif [ -e "$HTK" ]; then ok "$HTK (se conserva el propio; el diálogo de contraseña no toma el estilo de Minimo)"
else link "$REPO/hypr/hyprtoolkit/claro.conf" "$HTK"; fi

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
elif [ "$UPDATE" = 1 ]; then ok "Helium: sin cambios (actualización)"
elif confirm "¿Instalar Helium ($HELIUM, AUR)?"; then
    aur_install "$HELIUM" || { warn "No se pudo instalar Helium; seguí sin él."; FAILED_OPT+=("$HELIUM"); }
else warn "Helium omitido"; fi

step "Pantalla de inicio"
# Por defecto: respalda la config de greetd, desactiva el gestor actual SIN detenerlo (tu
# sesión sigue) y activa greetd; se ve al reiniciar. Omitir: --no-greeter.
if [ "$UPDATE" = 1 ]; then
    ok "Sin cambios: la pantalla de inicio se conserva como está (actualización)"
elif [ "$GREETER" != 1 ]; then
    ok "Se mantiene el inicio de sesión actual${OTHER_DE:+ ($OTHER_DE)}"
    # Entrada "Minimo OS" en SDDM/GDM, junto a Plasma: Hyprland ya trae la suya (hyprland.desktop)
    WS=/usr/share/wayland-sessions/minimo.desktop
    if [ "$PREVIEW" = 0 ] && [ -f "$WS" ]; then ok "$WS"
    else
        run sudo install -Dm755 "$REPO/greeter/minimo-session" /usr/local/bin/minimo-session
        if [ "$DRY" = 1 ]; then printf '        %s○ crear %s%s\n' "$D" "$WS" "$N"
        else printf '[Desktop Entry]\nName=Minimo OS\nComment=Hyprland + minimo-shell\nExec=/usr/local/bin/minimo-session\nType=Application\nDesktopNames=Hyprland\n' | sudo tee "$WS" >/dev/null && ok "Sesión Minimo OS en la pantalla de inicio"; fi
    fi
else
    if [ "$DRY" = 1 ]; then bash "$REPO/greeter/install-greeter.sh" --dry-run | sed "s/^/   /"
    else NEED_REBOOT=1; bash "$REPO/greeter/install-greeter.sh" || warn "La pantalla de inicio no se instaló; tu inicio actual sigue igual."; fi
fi

step "Servicio de la shell (systemd --user)"
UNITS="$HOME/.config/systemd/user"
link "$REPO/systemd/minimo-shell.service" "$UNITS/minimo-shell.service"
link "$REPO/systemd/hyprland-session.target" "$UNITS/hyprland-session.target"
link "$REPO/systemd/minimo-clipboard.service" "$UNITS/minimo-clipboard.service"
if [ "$REPO" != "$DEST" ]; then
    warn "El repo no está en $DEST: la unidad y el atajo Super+B asumen esa ruta."
fi
if [ "$DRY" = 0 ] && ! systemctl --user show-environment >/dev/null 2>&1; then
    warn "No hay sesión de systemd de tu usuario ahora; los servicios se activan al volver a ejecutar desde tu sesión."
else
run systemctl --user daemon-reload
run systemctl --user enable minimo-shell.service minimo-clipboard.service
# Agente de autenticación polkit (diálogos de contraseña de pkexec, particiones, etc.):
# lo trae hyprpolkitagent con su propia unidad; systemd garantiza una sola instancia.
run systemctl --user enable hyprpolkitagent.service
if [ "$UPDATE" = 1 ]; then
    ok "La interfaz se reinicia desde Ajustes (Reiniciar interfaz)"
elif [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
    run systemctl --user restart minimo-shell.service minimo-clipboard.service
    run systemctl --user start hyprpolkitagent.service
    run hyprctl reload
else
    ok "Se iniciará al entrar en Hyprland"
fi
fi

el=$((SECONDS-T0))
printf '\n   %s──────────────────────────────────────────────────────────%s\n' "$D" "$N"
if [ "$DRY" = 1 ]; then printf '\n   %s✓ Prueba completa.%s No se cambió nada.\n' "$B" "$N"
elif [ ${#FAILED[@]} -gt 0 ]; then printf '\n   %s%s! Minimo OS instalado a medias%s %sen %dm %02ds%s\n' "$Y" "$B" "$N" "$D" $((el/60)) $((el%60)) "$N"
else printf '\n   %s%s✓ Minimo OS instalado%s %sen %dm %02ds%s\n' "$G" "$B" "$N" "$D" $((el/60)) $((el%60)) "$N"; fi
if [ ${#FAILED[@]} -gt 0 ] || [ ${#FAILED_OPT[@]} -gt 0 ]; then
    [ ${#FAILED[@]} -gt 0 ] && printf '\n   %s✗ Faltan paquetes necesarios:%s %s\n' "$R" "$N" "${FAILED[*]}"
    [ ${#FAILED_OPT[@]} -gt 0 ] && printf '   %s! Opcionales sin instalar:%s %s\n' "$Y" "$N" "${FAILED_OPT[*]}"
    printf '   %sCómo seguir%s  sudo pacman -Syu  y volvé a ejecutar el instalador (retoma lo que falta)\n' "$D" "$N"
    printf '   %sRegistro%s     %s\n' "$D" "$N" "$LOG"
fi
if [ "$WARNS" -gt 0 ]; then
    printf '\n   %s%d aviso(s)%s\n' "$B" "$WARNS" "$N"
    for w in "${WARN_LIST[@]:0:6}"; do printf '        %s!%s %s\n' "$Y" "$N" "$w"; done
    [ "$WARNS" -gt 6 ] && printf '        %s… y %d más en el registro%s\n' "$D" $((WARNS-6)) "$N"
fi
progress "DONE $([ ${#FAILED[@]} -eq 0 ] && echo ok || echo partial)"
if [ "$UPDATE" = 1 ]; then printf '\n   %sSiguiente%s   Reiniciá la interfaz desde Ajustes › Actualizaciones\n\n' "$D" "$N"; [ ${#FAILED[@]} -eq 0 ]; exit; fi
printf '\n   %sSiguiente%s   Cerrá sesión y entrá en Hyprland\n' "$D" "$N"
printf   '   %sTerminal%s    Abrí Ghostty: Minimo te saluda\n' "$D" "$N"
printf   '   %sRepo%s        %s\n' "$D" "$N" "$REPO"
printf   '   %sDesinstalar%s %s/uninstall.sh\n' "$D" "$N" "$REPO"
printf   '   %sRegistro%s    %s\n' "$D" "$N" "$LOG"
# Primeros pasos: los cuatro atajos que conviene saber el primer día.
printf '\n   %sPrimeros pasos%s\n' "$B" "$N"
printf '        %sSuper + Espacio%s   abrir apps\n' "$B" "$N"
printf '        %sSuper + X%s         menú de la isla\n' "$B" "$N"
printf '        %sSuper + /%s         todos los atajos\n' "$B" "$N"
printf '        %s3 dedos ← →%s       cambiar de escritorio\n\n' "$B" "$N"
# Reiniciar solo si hace falta (núcleo actualizado o pantalla de inicio nueva); se pregunta.
if [ "$DRY" = 0 ] && [ "$NEED_REBOOT" = 1 ] && [ -z "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
    if confirm_no "Hace falta reiniciar para terminar. ¿Reiniciar ahora?"; then systemctl reboot; fi
fi
[ ${#FAILED[@]} -eq 0 ]
