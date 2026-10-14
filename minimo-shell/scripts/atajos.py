#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Diego Ledesma (TRN1) — Minimo OS
# Lista de atajos para Ajustes, generada desde la configuración real de Hyprland
# (hypr/minimo/atajos.lua). Ejecuta el archivo en Lua con un `hl` simulado que solo
# anota cada bind() (no ejecuta nada) y agrupa el resultado. Imprime JSON y termina.
#   atajos.py [ruta/atajos.lua]
import json, os, shutil, subprocess, sys

MOCK = r'''
local function proxy(path)
  return setmetatable({}, {
    __index = function(_, k) return proxy(path == "" and k or path .. "." .. k) end,
    __call = function(_, ...) return { __act = path, args = { ... } } end,
  })
end
local function ser(v)
  if type(v) ~= "table" then return tostring(v) end
  local ks = {}
  for k in pairs(v) do ks[#ks + 1] = tostring(k) end
  table.sort(ks)
  local out = {}
  for _, k in ipairs(ks) do out[#out + 1] = k .. "=" .. ser(v[k] == nil and v[tonumber(k)] or v[k]) end
  return table.concat(out, ",")
end
local function clean(s) return (tostring(s):gsub("[\t\n]", " ")) end
hl = setmetatable({
  dsp = proxy(""),
  bind = function(keys, act, opts)
    local a = type(act) == "table" and act or {}
    local arg = a.args and a.args[1]
    io.write(clean(keys), "\t", clean(a.__act or "?"), "\t",
      clean(type(arg) == "table" and ser(arg) or (arg or "")), "\t",
      clean(opts and opts.description or ""), "\n")
  end,
}, { __index = function(_, k) return proxy(k) end })
dofile(arg[1])
'''

SPECIAL = {
    "space": "Espacio", "comma": ",", "minus": "-", "equal": "=", "bracketleft": "[",
    "bracketright": "]", "Home": "Inicio", "End": "Fin", "Page_Up": "RePág", "Page_Down": "AvPág",
    "left": "←", "right": "→", "up": "↑", "down": "↓", "Print": "ImprPant", "Return": "Intro",
    "Tab": "Tab", "Escape": "Esc", "mouse:272": "Clic izq.", "mouse:273": "Clic der.",
    "XF86AudioRaiseVolume": "Vol +", "XF86AudioLowerVolume": "Vol −", "XF86AudioMute": "Silencio",
    "XF86AudioMicMute": "Mic", "XF86AudioPlay": "Play", "XF86AudioPause": "Pausa",
    "XF86AudioNext": "Siguiente", "XF86AudioPrev": "Anterior",
    "mouse_down": "Rueda ↓", "mouse_up": "Rueda ↑", "code:20": "-", "code:21": "=",
}
MODS = {"SUPER": "Super", "SHIFT": "Shift", "CTRL": "Ctrl", "CONTROL": "Ctrl", "ALT": "Alt"}
MEDIA = {
    "XF86AudioRaiseVolume": ("Subir volumen", "Multimedia"),
    "XF86AudioLowerVolume": ("Bajar volumen", "Multimedia"),
    "XF86AudioMute": ("Silenciar", "Multimedia"),
    "XF86AudioMicMute": ("Silenciar micrófono", "Multimedia"),
    "XF86AudioPlay": ("Reproducir / pausar", "Multimedia"),
    "XF86AudioPause": ("Reproducir / pausar", "Multimedia"),
    "XF86AudioNext": ("Siguiente pista", "Multimedia"),
    "XF86AudioPrev": ("Pista anterior", "Multimedia"),
}
DIR = {"l": "a la izquierda", "r": "a la derecha", "u": "arriba", "d": "abajo"}
ORDER = ["Aplicaciones", "Ventanas", "Foco", "Escritorios", "Capturas", "Multimedia", "Sesión", "Otros"]

def keys_of(spec):
    parts = [p.strip() for p in spec.split("+")]
    return [MODS.get(p.upper(), SPECIAL.get(p, p.upper() if len(p) == 1 else p)) for p in parts if p]

def opts(a):
    return dict(kv.split("=", 1) for kv in a.split(",") if "=" in kv)

def describe(key, act, arg, desc):
    o = opts(arg)
    if key in MEDIA:
        return MEDIA[key]
    if act == "exec_cmd":
        c = arg
        if "settings toggle" in c: return "Ajustes", "Aplicaciones"
        if "island open" in c: return "Abrir la isla", "Aplicaciones"
        if "recorder toggle" in c: return "Grabar pantalla", "Capturas"
        if "overview toggle" in c: return "Vista de ventanas", "Ventanas"
        if "clipboard" in c: return "Historial del portapapeles", "Aplicaciones"
        if "slurp" in c and "grim" in c: return "Captura de una zona", "Capturas"
        if "grim" in c: return "Captura de pantalla completa", "Capturas"
        prog = c.split()[0] if c.split() else c
        names = {"ghostty": "Terminal", "fuzzel": "Lanzador de apps"}
        return desc or names.get(prog, "Abrir " + prog), "Aplicaciones"
    if act == "window.drag": return "Mover con el mouse", "Ventanas"
    if act == "window.resize" and "mouse:" in key: return "Redimensionar con el mouse", "Ventanas"
    if desc:
        return desc, "Ventanas"
    if act == "exit": return "Cerrar sesión", "Sesión"
    if act == "dpms": return "Apagar / encender pantalla", "Sesión"
    if act == "window.close": return "Cerrar ventana", "Ventanas"
    if act == "window.fullscreen":
        if o.get("mode") == "fullscreen": return "Pantalla completa", "Ventanas"
        return ("Maximizar" if o.get("action") == "set" else "Maximizar / restaurar"), "Ventanas"
    if act == "window.float": return "Ventana flotante", "Ventanas"
    if act == "group.toggle": return "Agrupar ventanas (pestañas)", "Ventanas"
    if act == "layout":
        if "togglesplit" in arg: return "Cambiar división", "Ventanas"
        if "preselect" in arg: return "Próxima ventana " + DIR.get(arg.split()[-1], ""), "Ventanas"
    if act == "window.resize":
        if not o: return "Redimensionar ventana", "Ventanas"
        x, y = int(float(o.get("x", 0))), int(float(o.get("y", 0)))
        return ("Más ancha" if x > 0 else "Más angosta" if x < 0 else "Más alta" if y > 0 else "Más baja"), "Ventanas"
    if act == "focus":
        if "window" in o: return ("Primera ventana" if o["window"] == "first" else "Última ventana"), "Foco"
        if "direction" in o: return "Foco " + DIR.get(o["direction"], ""), "Foco"
        if "monitor" in o: return "Monitor " + DIR.get(o["monitor"], ""), "Foco"
        if "workspace" in o: return ws_label("Ir al escritorio", o["workspace"]), "Escritorios"
    if act == "window.move":
        if "direction" in o: return "Mover ventana " + DIR.get(o["direction"], ""), "Ventanas"
        if "monitor" in o: return "Mover al monitor " + DIR.get(o["monitor"], ""), "Ventanas"
        if "workspace" in o: return ws_label("Mover ventana al escritorio", o["workspace"]), "Escritorios"
    return (act + (" " + arg if arg else "")).strip(), "Otros"

def ws_label(base, ws):
    rel = {"e+1": "siguiente", "e-1": "anterior", "+1": "siguiente", "-1": "anterior"}.get(ws)
    if not rel: return base + " " + ws
    return "Escritorio " + rel if base.startswith("Ir") else base + " " + rel

def main():
    path = sys.argv[1] if len(sys.argv) > 1 else os.path.expanduser("~/.config/hypr/minimo/atajos.lua")
    if not os.path.exists(path):
        here = os.path.dirname(os.path.realpath(__file__))
        path = os.path.join(here, "..", "..", "hypr", "minimo", "atajos.lua")
    lua = next((shutil.which(x) for x in ("lua", "lua5.4", "lua5.3", "luajit") if shutil.which(x)), None)
    if not lua:
        print(json.dumps({"error": "nolua", "groups": []})); return
    try:
        out = subprocess.run([lua, "-", path], input=MOCK, capture_output=True, text=True, timeout=3).stdout
    except Exception:
        out = ""
    rows = {}
    for line in out.splitlines():
        f = (line.split("\t") + ["", "", "", ""])[:4]
        if not f[0]: continue
        k = f[0].split("+")[-1].strip()
        label, group = describe(k, f[1], f[2], f[3])
        ks = keys_of(f[0])
        # Agrupar variantes: mismo texto y mismos modificadores (flechas y h/j/k/l, 1–9, etc.).
        if label.endswith(tuple(" %d" % i for i in range(1, 10))) and ks[-1].isdigit():
            label = label[:-2] + " 1–9"; ks = ks[:-1] + ["1–9"]
        rk = (group, label)
        r = rows.setdefault(rk, {"label": label, "combos": []})
        if ks not in r["combos"]: r["combos"].append(ks)
    groups = {}
    arrows = ["←", "→", "↑", "↓"]
    dirorder = [" a la izquierda", " a la derecha", " arriba", " abajo"]
    def sortkey(label):
        # Mismo verbo junto y direcciones en orden fijo (izq., der., arriba, abajo).
        for i, d in enumerate(dirorder):
            if label.endswith(d): return (label[: -len(d)], i)
        return (label, -1)
    for (g, _), r in rows.items():
        # Las variantes con los mismos modificadores se muestran una vez: Super Shift ← o H.
        bymods = {}
        for c in r["combos"]:
            bymods.setdefault(tuple(c[:-1]), []).append(c[-1])
        combos = []
        for mods, ks in bymods.items():
            ks.sort(key=lambda k: (0, arrows.index(k)) if k in arrows else (2, k) if len(k) == 1 else (1, -len(k)))
            combos.append({"mods": list(mods), "keys": ks[:3]})
        combos.sort(key=lambda c: len(c["mods"]))
        groups.setdefault(g, []).append({"label": r["label"], "combos": combos[:2]})
    for g in groups:
        first = {}
        for n, it in enumerate(groups[g]):
            first.setdefault(sortkey(it["label"])[0], n)
        groups[g].sort(key=lambda it: (first[sortkey(it["label"])[0]], sortkey(it["label"])[1]))
    res = [{"name": g, "items": groups[g]} for g in ORDER if g in groups]
    print(json.dumps({"groups": res}, ensure_ascii=False))

if __name__ == "__main__":
    main()
