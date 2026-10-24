#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Diego Ledesma (TRN1) — Minimo OS
# Simulador de laptop para probar Minimo OS en una PC de escritorio. No toca el sistema:
# escribe ~/.cache/minimo/fake-battery.json (solo existe mientras simulás) y avisa a la shell.
#   fake-laptop.sh bat 20 Discharging [mins]   batería falsa (Charging|Discharging|Full|"Not charging")
#   fake-laptop.sh plug | unplug               enchufar / desenchufar el cargador
#   fake-laptop.sh lid close | open            tapa (en simulación solo muestra el aviso)
#   fake-laptop.sh brightness up | down        teclas de brillo
#   fake-laptop.sh off                         apaga el simulador (vuelve a lo real)
set -eu
F="$HOME/.cache/minimo/fake-battery.json"
QS=(qs -p "$(dirname "$(realpath "$0")")/.." ipc call laptop)
cur() { python3 -c "import json;j=json.load(open('$F'));print(j.get('$1',''))" 2>/dev/null || true; }
write() { mkdir -p "$(dirname "$F")"; printf '{"pct": %s, "status": "%s", "mins": %s}\n' "$1" "$2" "${3:-null}" > "$F"; "${QS[@]}" rescan >/dev/null; }
case "${1:-}" in
  bat) write "${2:?porcentaje}" "${3:-Discharging}" "${4:-null}" ;;
  plug) write "$(cur pct || echo 50)" Charging ;;
  unplug) write "$(cur pct || echo 50)" Discharging ;;
  lid) "${QS[@]}" lid "${2:?close|open}" ;;
  brightness) "${QS[@]}" brightness "${2:?up|down}" ;;
  off) rm -f "$F"; "${QS[@]}" rescan >/dev/null ;;
  *) sed -n 4,10p "$0"; exit 1 ;;
esac
