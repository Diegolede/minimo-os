#!/bin/sh
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Diego Ledesma (TRN1) — Minimo OS
# Abre un monitor del sistema: primero apps gráficas; si no hay, btop/htop en una terminal.
# Sale con 1 si no encuentra ninguno (la isla lo avisa).
for a in missioncenter gnome-system-monitor plasma-systemmonitor; do
    command -v "$a" >/dev/null 2>&1 && { setsid -f "$a" >/dev/null 2>&1; exit 0; }
done
m=$(command -v btop || command -v htop) || exit 1
for t in kitty alacritty foot; do
    command -v "$t" >/dev/null 2>&1 || continue
    [ "$t" = foot ] && { setsid -f foot "$m" >/dev/null 2>&1; exit 0; }
    setsid -f "$t" -e "$m" >/dev/null 2>&1; exit 0
done
exit 1
