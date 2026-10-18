#!/usr/bin/env python3
# SPDX-License-Identifier: MIT · Copyright (c) 2026 Diego Ledesma (TRN1) — Minimo OS
"""Iconos de Minimo OS (Fluent UI System Icons, Filled, MIT — ver fluent/LICENSE).

  python3 build.py fetch   descarga SOLO los SVG del mapa (map.json) desde el commit fijado
                           de github.com/microsoft/fluentui-system-icons a fluent/ (solo desarrollo)
  python3 build.py         genera dark/ gray/ graydark/ white/ (<nombre>.svg) cambiando el color
                           de relleno; borra los que ya no están en el mapa.
En tiempo de ejecución no se descarga nada: la shell lee los SVG ya generados.
"""
import json, os, re, sys, urllib.parse, urllib.request
HERE = os.path.dirname(os.path.abspath(__file__))
COMMIT = "a347af95478f989038cccbf085978865264c048a"
TONES = {"dark": "#0A0A0B", "gray": "#6E6E73", "graydark": "#AEAEB2", "white": "#FFFFFF"}
MAP = {k: v for k, v in json.load(open(os.path.join(HERE, "map.json"))).items() if not k.startswith("_")}

def snake(folder): return re.sub(r"[^a-z0-9]+", "_", folder.lower()).strip("_")

def fetch():
    os.makedirs(os.path.join(HERE, "fluent"), exist_ok=True)
    for name, folder in sorted(MAP.items()):
        for size in (24, 20):
            fn = f"ic_fluent_{snake(folder)}_{size}_filled.svg"
            url = f"https://raw.githubusercontent.com/microsoft/fluentui-system-icons/{COMMIT}/assets/{urllib.parse.quote(folder)}/SVG/{fn}"
            try:
                data = urllib.request.urlopen(url, timeout=20).read()
            except Exception:
                continue
            open(os.path.join(HERE, "fluent", fn), "wb").write(data)
            print(f"{name:12s} <- {folder}/{fn}")
            break
        else:
            sys.exit(f"falta {folder} ({name})")

def source(folder):
    for size in (24, 20):
        p = os.path.join(HERE, "fluent", f"ic_fluent_{snake(folder)}_{size}_filled.svg")
        if os.path.exists(p): return p
    sys.exit(f"no está vendorizado: {folder} (python3 build.py fetch)")

def build():
    for tone, color in TONES.items():
        d = os.path.join(HERE, tone); os.makedirs(d, exist_ok=True)
        for f in os.listdir(d):
            if f.endswith(".svg") and f[:-4] not in MAP: os.remove(os.path.join(d, f))
        for name, folder in MAP.items():
            svg = open(source(folder)).read()
            svg = re.sub(r'fill="#[0-9A-Fa-f]{3,6}"', f'fill="{color}"', svg)
            if 'fill="' not in svg.split(">", 1)[0]:          # sin color explícito: lo fija en <svg>
                svg = svg.replace("<svg ", f'<svg fill="{color}" ', 1)
            open(os.path.join(d, name + ".svg"), "w").write(svg)
    print(f"{len(MAP)} iconos × {len(TONES)} tonos")

if __name__ == "__main__":
    fetch() if sys.argv[1:] == ["fetch"] else build()
