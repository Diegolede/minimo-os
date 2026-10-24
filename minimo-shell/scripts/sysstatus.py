#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Diego Ledesma (TRN1) — Minimo OS
# Estado del sistema para el panel de la isla. Imprime un JSON y termina.
#   sysstatus.py res   → recursos (CPU %, RAM, disco, temperatura)  [cada 2 s con el panel abierto]
#   sysstatus.py full  → recursos + red + dispositivos + GPU         [al abrir y cada ~8 s]
import json, os, shutil, subprocess, sys, time

def run(cmd, t=1.5):
    try:
        return subprocess.run(cmd, capture_output=True, text=True, timeout=t).stdout
    except Exception:
        return ""

def cpu_times():
    with open("/proc/stat") as f:
        v = list(map(int, f.readline().split()[1:]))
    idle = v[3] + v[4]
    return sum(v), idle

def resources():
    t0, i0 = cpu_times(); time.sleep(0.25); t1, i1 = cpu_times()
    cpu = 0 if t1 == t0 else round(100 * (1 - (i1 - i0) / (t1 - t0)))
    mem = {}
    with open("/proc/meminfo") as f:
        for l in f:
            k, v = l.split(":"); mem[k] = int(v.split()[0])
    total, avail = mem["MemTotal"], mem["MemAvailable"]
    du = shutil.disk_usage("/")
    temp = None
    base = "/sys/class/hwmon"
    for h in (sorted(os.listdir(base)) if os.path.isdir(base) else []):
        try:
            with open(f"{base}/{h}/name") as fh: name = fh.read().strip()
        except OSError:
            continue
        if name in ("coretemp", "k10temp", "zenpower"):
            for fn in sorted(os.listdir(f"{base}/{h}")):
                if fn.endswith("_label"):
                    try:
                        with open(f"{base}/{h}/{fn}") as fh: lab = fh.read().strip()
                        if lab.startswith(("Package", "Tctl", "Tdie")):
                            with open(f"{base}/{h}/{fn[:-6]}_input") as fh: temp = round(int(fh.read()) / 1000)
                            break
                    except (OSError, ValueError):
                        continue
            if temp is None and os.path.exists(f"{base}/{h}/temp1_input"):
                try:
                    with open(f"{base}/{h}/temp1_input") as fh: temp = round(int(fh.read()) / 1000)
                except (OSError, ValueError):
                    pass
            break
    return {"cpu": cpu, "memUsed": (total - avail) * 1024, "memTotal": total * 1024,
            "diskUsed": du.used, "diskTotal": du.total, "temp": temp}

def nm_fields(line):
    out, cur, i = [], "", 0
    while i < len(line):
        c = line[i]
        if c == "\\" and i + 1 < len(line): cur += line[i + 1]; i += 2; continue
        if c == ":": out.append(cur); cur = ""
        else: cur += c
        i += 1
    out.append(cur); return out

def network():
    net = {"type": "", "name": "", "device": "", "signal": 0, "connectivity": "unknown"}
    for l in run(["nmcli", "-t", "-f", "DEVICE,TYPE,STATE,CONNECTION", "dev"]).splitlines():
        d, ty, st, con = (nm_fields(l) + ["", "", "", ""])[:4]
        if st == "connected" and ty in ("ethernet", "wifi"):
            if not net["type"] or ty == "ethernet":
                net.update(type=ty, name=con, device=d)
    if net["type"] == "wifi":
        for l in run(["nmcli", "-t", "-f", "IN-USE,SSID,SIGNAL", "dev", "wifi", "list", "--rescan", "no"]).splitlines():
            f = nm_fields(l)
            if f[0] == "*": net["name"], net["signal"] = f[1], int(f[2] or 0)
    net["connectivity"] = run(["nmcli", "networking", "connectivity", "check"], 4).strip() or "unknown"
    return net

SKIP = ("virtual", "power-button", "sleep-button", "video-bus", "ydotool", "hotkeys", "wmi", "consumer-control",
        "system-control", "avrcp", "pc-speaker", "lid-switch")

def devices():
    out = {"keyboards": [], "mice": [], "audio": "", "bluetooth": [], "usb": []}
    try:
        d = json.loads(run(["hyprctl", "devices", "-j"]) or "{}")
    except ValueError:
        d = {}
    def clean(lst, drop):
        # Un mismo aparato expone varias interfaces ("… keyboard 1", "… keyboard mouse"):
        # se quitan sufijos numéricos y las interfaces del otro tipo.
        seen = []
        for x in lst:
            n = x.get("name", "").lower()
            if any(s in n for s in SKIP) or drop in n: continue
            pretty = " ".join(w for w in n.replace("-", " ").split() if not w.isdigit()).capitalize()
            if pretty and pretty not in seen: seen.append(pretty)
        return seen
    out["keyboards"] = clean(d.get("keyboards", []), "mouse")
    out["mice"] = clean(d.get("mice", []), "keyboard")
    sink = run(["pactl", "get-default-sink"]).strip()
    if sink:
        cur, desc, nick = None, "", ""
        for l in run(["pactl", "list", "sinks"]).splitlines():
            l = l.strip()
            if l.startswith("Name:"): cur = l[5:].strip()
            elif cur == sink and l.startswith("Description:"): desc = l[12:].strip()
            elif cur == sink and l.startswith("node.nick = "): nick = l[12:].strip().strip('"')
        out["audio"] = nick or desc or sink
    if shutil.which("bluetoothctl"):
        for l in run(["bluetoothctl", "devices", "Connected"], 2).splitlines():
            p = l.split(" ", 2)
            if len(p) == 3: out["bluetooth"].append(p[2])
    try:
        for b in json.loads(run(["lsblk", "-J", "-d", "-o", "NAME,TRAN,MODEL,SIZE"]) or "{}").get("blockdevices", []):
            if b.get("tran") == "usb": out["usb"].append(((b.get("model") or b["name"]).strip() + " · " + (b.get("size") or "")).strip(" ·"))
    except ValueError:
        pass
    return out

def gpu():
    if not shutil.which("nvidia-smi"): return None
    l = run(["nvidia-smi", "--query-gpu=name,utilization.gpu,temperature.gpu", "--format=csv,noheader,nounits"]).strip()
    p = [x.strip() for x in l.split(",")]
    if len(p) < 3: return None
    return {"name": p[0].replace("NVIDIA ", "").replace("GeForce ", ""), "util": num(p[1]), "temp": num(p[2])}

def battery():
    # Simulador (scripts/fake-laptop.sh): si existe el archivo falso, manda ese.
    fk = os.path.expanduser("~/.cache/minimo/fake-battery.json")
    if os.path.exists(fk):
        try:
            with open(fk) as fh: j = json.load(fh)
            return {"pct": num(j.get("pct", 100)), "status": j.get("status", "Discharging"), "mins": j.get("mins")}
        except (OSError, ValueError): return None
    # Primera batería real (no la de un mouse/teclado: scope "Device"). None si no hay.
    base = "/sys/class/power_supply"
    for d in (sorted(os.listdir(base)) if os.path.isdir(base) else []):
        p = f"{base}/{d}"
        def rd(n):
            try:
                with open(f"{p}/{n}") as fh: return fh.read().strip()
            except OSError: return ""
        if rd("type") != "Battery" or rd("scope") == "Device": continue
        pct = num(rd("capacity")); st = rd("status")       # Charging | Discharging | Full | Not charging
        mins = None
        now = num(rd("energy_now") or rd("charge_now")); rate = num(rd("power_now") or rd("current_now"))
        full = num(rd("energy_full") or rd("charge_full"))
        if rate > 0:
            if st == "Discharging": mins = round(60 * now / rate)
            elif st == "Charging" and full > now: mins = round(60 * (full - now) / rate)
        return {"pct": pct, "status": st, "mins": mins}
    return None

def safe(fn, fallback):
    # Un sensor raro (p. ej. nvidia-smi "[N/A]") no debe dejar al panel sin datos.
    try:
        return fn()
    except Exception:
        return fallback
def num(x):
    try: return int(float(x))
    except (TypeError, ValueError): return 0
mode = sys.argv[1] if len(sys.argv) > 1 else "full"
res = {"res": safe(resources, None)}
if res["res"] is not None: res["res"]["battery"] = safe(battery, None)
if mode == "full":
    res["net"] = safe(network, None); res["dev"] = safe(devices, None); res["gpu"] = safe(gpu, None)
print(json.dumps(res))
