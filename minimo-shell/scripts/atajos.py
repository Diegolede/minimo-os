#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Diego Ledesma (TRN1) — Minimo OS
# Lista de atajos para Ajustes, generada desde la configuración real de Hyprland
# (hypr/minimo/atajos.lua y hypr/minimo.lua). Ejecuta el archivo en Lua con un `hl` simulado que solo
# anota cada bind() (no ejecuta nada) y agrupa el resultado. Imprime JSON y termina.
#   atajos.py [archivo.lua …]   (por defecto: minimo/atajos.lua y minimo.lua)
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
for i = 1, #arg do dofile(arg[i]) end
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

# Idioma: `--lang en` traduce SOLO los textos generados aquí (acciones, grupos, teclas);
# las descripciones escritas en la configuración (description = ...) quedan como están.
LANG = "es"
EN = {
    # grupos
    "Aplicaciones": "Apps", "Ventanas": "Windows", "Foco": "Focus", "Escritorios": "Desktops",
    "Capturas": "Screenshots", "Multimedia": "Media", "Sesión": "Session", "Otros": "Other",
    # teclas
    "Espacio": "Space", "Inicio": "Home", "Fin": "End", "RePág": "PgUp", "AvPág": "PgDn",
    "ImprPant": "Print", "Intro": "Enter", "Clic izq.": "Left click", "Clic der.": "Right click",
    "Silencio": "Mute", "Pausa": "Pause", "Siguiente": "Next", "Anterior": "Previous",
    "Rueda ↓": "Wheel ↓", "Rueda ↑": "Wheel ↑",
    # direcciones
    "a la izquierda": "left", "a la derecha": "right", "arriba": "up", "abajo": "down",
    "siguiente": "next", "anterior": "previous",
    # acciones
    "Subir volumen": "Volume up", "Bajar volumen": "Volume down", "Silenciar": "Mute",
    "Silenciar micrófono": "Mute microphone", "Reproducir / pausar": "Play / pause",
    "Siguiente pista": "Next track", "Pista anterior": "Previous track",
    "Ajustes": "Settings", "Abrir la isla": "Open the island", "Portapapeles": "Clipboard",
    "Lanzador de Minimo": "Minimo launcher", "Grabar pantalla": "Record screen",
    "Vista de ventanas": "Window overview", "Captura de una zona": "Screenshot of an area",
    "Captura de pantalla completa": "Full-screen screenshot", "Terminal": "Terminal",
    "Fuzzel (lanzador)": "Fuzzel (launcher)", "Abrir": "Open",
    "Mover con el mouse": "Move with the mouse", "Redimensionar con el mouse": "Resize with the mouse",
    "Cerrar sesión": "Log out", "Apagar / encender pantalla": "Turn display off / on",
    "Cerrar ventana": "Close window", "Pantalla completa": "Fullscreen", "Maximizar": "Maximize",
    "Maximizar / restaurar": "Maximize / restore", "Ventana flotante": "Floating window",
    "Agrupar ventanas (pestañas)": "Group windows (tabs)", "Cambiar división": "Toggle split",
    "Próxima ventana": "Next window", "Redimensionar ventana": "Resize window",
    "Más ancha": "Wider", "Más angosta": "Narrower", "Más alta": "Taller", "Más baja": "Shorter",
    "Primera ventana": "First window", "Última ventana": "Last window", "Monitor": "Monitor",
    "Mover ventana": "Move window", "Mover al monitor": "Move to monitor",
    "Ir al escritorio": "Go to desktop", "Mover ventana al escritorio": "Move window to desktop",
    "Escritorio siguiente": "Next desktop", "Escritorio anterior": "Previous desktop",
    "Mover ventana al escritorio siguiente": "Move window to next desktop",
    "Mover ventana al escritorio anterior": "Move window to previous desktop",
}
def T(s): return EN.get(s, s) if LANG == "en" else s
def D(k): return T(DIR.get(k, ""))

def keys_of(spec):
    parts = [p.strip() for p in spec.split("+")]
    return [MODS.get(p.upper(), SPECIAL.get(p, p.upper() if len(p) == 1 else p)) for p in parts if p]

def opts(a):
    return dict(kv.split("=", 1) for kv in a.split(",") if "=" in kv)

def describe(key, act, arg, desc):
    o = opts(arg)
    if key in MEDIA:
        return T(MEDIA[key][0]), MEDIA[key][1]
    if act == "exec_cmd":
        c = arg
        if "settings toggle" in c: return T("Ajustes"), "Aplicaciones"
        if "island open" in c: return T("Abrir la isla"), "Aplicaciones"
        if "island clipboard" in c: return T("Portapapeles"), "Aplicaciones"
        if "launcher toggle" in c: return T("Lanzador de Minimo"), "Aplicaciones"
        if "recorder toggle" in c: return T("Grabar pantalla"), "Capturas"
        if "overview toggle" in c: return T("Vista de ventanas"), "Ventanas"
        if "screenshot.sh area" in c or ("slurp" in c and "grim" in c): return T("Captura de una zona"), "Capturas"
        if "screenshot.sh" in c or "grim" in c: return T("Captura de pantalla completa"), "Capturas"
        prog = c.split()[0] if c.split() else c
        names = {"ghostty": "Terminal", "fuzzel": "Fuzzel (lanzador)"}
        return desc or T(names.get(prog, "")) or T("Abrir") + " " + prog, "Aplicaciones"
    if act == "window.drag": return T("Mover con el mouse"), "Ventanas"
    if act == "window.resize" and "mouse:" in key: return T("Redimensionar con el mouse"), "Ventanas"
    if desc:
        return desc, "Ventanas"
    if act == "exit": return T("Cerrar sesión"), "Sesión"
    if act == "dpms": return T("Apagar / encender pantalla"), "Sesión"
    if act == "window.close": return T("Cerrar ventana"), "Ventanas"
    if act == "window.fullscreen":
        if o.get("mode") == "fullscreen": return T("Pantalla completa"), "Ventanas"
        return T("Maximizar" if o.get("action") == "set" else "Maximizar / restaurar"), "Ventanas"
    if act == "window.float": return T("Ventana flotante"), "Ventanas"
    if act == "group.toggle": return T("Agrupar ventanas (pestañas)"), "Ventanas"
    if act == "layout":
        if "togglesplit" in arg: return T("Cambiar división"), "Ventanas"
        if "preselect" in arg: return T("Próxima ventana") + " " + D(arg.split()[-1]), "Ventanas"
    if act == "window.resize":
        if not o: return T("Redimensionar ventana"), "Ventanas"
        x, y = int(float(o.get("x", 0))), int(float(o.get("y", 0)))
        return T("Más ancha" if x > 0 else "Más angosta" if x < 0 else "Más alta" if y > 0 else "Más baja"), "Ventanas"
    if act == "focus":
        if "window" in o: return T("Primera ventana" if o["window"] == "first" else "Última ventana"), "Foco"
        if "direction" in o: return T("Foco") + " " + D(o["direction"]), "Foco"
        if "monitor" in o: return T("Monitor") + " " + D(o["monitor"]), "Foco"
        if "workspace" in o: return ws_label("Ir al escritorio", o["workspace"]), "Escritorios"
    if act == "window.move":
        if "direction" in o: return T("Mover ventana") + " " + D(o["direction"]), "Ventanas"
        if "monitor" in o: return T("Mover al monitor") + " " + D(o["monitor"]), "Ventanas"
        if "workspace" in o: return ws_label("Mover ventana al escritorio", o["workspace"]), "Escritorios"
    return (act + (" " + arg if arg else "")).strip(), "Otros"

def ws_label(base, ws):
    rel = {"e+1": "siguiente", "e-1": "anterior", "+1": "siguiente", "-1": "anterior"}.get(ws)
    if not rel: return T(base) + " " + ws
    return T("Escritorio " + rel) if base == "Ir al escritorio" else T(base + " " + rel)

def main():
    here = os.path.dirname(os.path.realpath(__file__))
    repo = os.path.join(here, "..", "..", "hypr")
    global LANG
    args = sys.argv[1:]
    if "--lang" in args:
        i = args.index("--lang"); LANG = (args[i + 1:i + 2] or ["es"])[0]; del args[i:i + 2]
    paths = args
    if not paths:
        # Los de la config activa (enlazados al repo por el instalador) y, si no están, los del repo.
        for rel in ("minimo/atajos.lua", "minimo.lua"):
            p = os.path.expanduser("~/.config/hypr/" + rel)
            paths.append(p if os.path.exists(p) else os.path.join(repo, rel))
    paths = [p for p in paths if os.path.exists(p)]
    lua = next((shutil.which(x) for x in ("lua", "lua5.4", "lua5.3", "luajit") if shutil.which(x)), None)
    if not lua:
        print(json.dumps({"error": "nolua", "groups": []})); return
    try:
        out = subprocess.run([lua, "-"] + paths, input=MOCK, capture_output=True, text=True, timeout=3).stdout
    except Exception:
        out = ""
    rows = {}
    for line in out.splitlines():
        f = (line.split("\t") + ["", "", "", ""])[:4]
        if not f[0]: continue
        k = f[0].split("+")[-1].strip()
        label, group = describe(k, f[1], f[2], f[3])
        ks = [T(k) for k in keys_of(f[0])]
        # Agrupar variantes: mismo texto y mismos modificadores (flechas y h/j/k/l, 1–9, etc.).
        if label.endswith(tuple(" %d" % i for i in range(1, 10))) and ks[-1].isdigit():
            label = label[:-2] + " 1–9"; ks = ks[:-1] + ["1–9"]
        rk = (group, label)
        r = rows.setdefault(rk, {"label": label, "combos": []})
        if ks not in r["combos"]: r["combos"].append(ks)
    groups = {}
    arrows = ["←", "→", "↑", "↓"]
    dirorder = [" " + D(k) for k in ("l", "r", "u", "d")]
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
    res = [{"name": T(g), "items": groups[g]} for g in ORDER if g in groups]
    print(json.dumps({"groups": res}, ensure_ascii=False))

if __name__ == "__main__":
    main()
