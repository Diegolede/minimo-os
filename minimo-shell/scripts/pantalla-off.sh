#!/bin/sh
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Diego Ledesma (TRN1) — Minimo OS
# Apagar pantalla sin desconectarla: DPMS por software. El monitor queda "conectado" para
# Hyprland, así las ventanas, escritorios y juegos siguen exactamente donde están.
# Se vuelve a encender moviendo el mouse o tocando una tecla (misc.*_enables_dpms).
# Espera ~1 s para que el clic o soltar el atajo no la despierte al instante.
# Nunca suspende ni bloquea la PC.
LOCK="${XDG_RUNTIME_DIR:-/tmp}/minimo-pantalla-off.lock"
# Un solo apagado a la vez (doble clic o atajo repetido).
exec 9>"$LOCK"
flock -n 9 || exit 0
sleep "${MINIMO_DPMS_DELAY:-1}"
exec hyprctl dispatch 'hl.dsp.dpms({ action = "disable" })'
