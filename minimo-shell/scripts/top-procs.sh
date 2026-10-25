#!/bin/sh
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Diego Ledesma (TRN1) — Minimo OS
# Qué apps usan más CPU y memoria ahora (agrupado por programa). Solo lo pide el panel de
# estado mientras el mouse está sobre un anillo. Salida: "C nombre %" y "M nombre MiB", 3 de cada.
export LC_ALL=C
top -b -n 2 -d 0.5 -w 512 -o %CPU 2>/dev/null | awk '/^top -/{n++} n==2 && $1 ~ /^[0-9]+$/ && $12 != "top" {c[$12]+=$9}
  END{for(k in c) if (c[k] >= 1) printf "C %s %.0f\n", k, c[k]}' | sort -k3,3nr | head -3
ps -eo comm=,rss= 2>/dev/null | awk '{m[$1]+=$2} END{for(k in m) printf "M %s %d\n", k, m[k]/1024}' | sort -k3,3nr | head -3
