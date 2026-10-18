#!/usr/bin/env python3
# python3 tests/window_action_test.py — window-action.py con un hyprctl simulado (registra cada llamada).
import json, os, subprocess, sys, tempfile
HERE = os.path.dirname(os.path.realpath(__file__))
SCRIPT = os.path.join(HERE, "..", "minimo-shell", "scripts", "window-action.py")
d = tempfile.mkdtemp(); log = os.path.join(d, "log")
clients = [{"address": "0x5a1b2c", "workspace": {"id": 1}, "class": "ghostty"},
           {"address": "0x77aa", "workspace": {"id": 2}, "class": "helium"}]
open(os.path.join(d, "clients.json"), "w").write(json.dumps(clients))
open(os.path.join(d, "hyprctl"), "w").write(f"""#!/bin/sh
echo "$@" >> {log}
if [ "$1" = clients ]; then cat {d}/clients.json; exit 0; fi
echo ok
""")
os.chmod(os.path.join(d, "hyprctl"), 0o755)
env = dict(os.environ, PATH=d + ":" + os.environ["PATH"])

def run(*a):
    if os.path.exists(log): os.remove(log)
    r = subprocess.run([sys.executable, SCRIPT, *a], capture_output=True, text=True, env=env)
    calls = open(log).read().splitlines() if os.path.exists(log) else []
    return json.loads(r.stdout), calls

res = []
def case(n, c): res.append(c); print(("OK   " if c else "FALLA"), n)

o, c = run("move", "0x5a1b2c", "3")
case("mover: consulta fresca y luego hl.dsp.window.move sin seguir", o["ok"] and c[0] == "clients -j" and c[1] == 'dispatch hl.dsp.window.move({ workspace = "3", follow = false, window = "address:0x5a1b2c" })')
o, c = run("move", "5a1b2c", "emptynm")
case("dirección sin 0x y escritorio nuevo (emptynm)", o["ok"] and 'workspace = "emptynm"' in c[1] and "address:0x5a1b2c" in c[1])
o, c = run("move", "0x5a1b2c", "1")
case("mismo escritorio: no se despacha nada", o["noop"] and len(c) == 1)
o, c = run("move", "0xdead", "2")
case("ventana desaparecida: no se despacha nada (reason gone)", not o["ok"] and o["reason"] == "gone" and len(c) == 1)
o, c = run("close", "0x77aa")
case("cerrar: hl.dsp.window.close (amable), nunca kill", o["ok"] and c[1] == 'dispatch hl.dsp.window.close({ window = "address:0x77aa" })' and "kill" not in " ".join(c))
o, c = run("close", "0xdead")
case("cerrar ventana desaparecida: nada", o["reason"] == "gone" and len(c) == 1)
for bad in [("move", '0x1" }) hl.dsp.exec_cmd("rm', "2"), ("move", "0x5a1b2c", '2" })'), ("move", "0x5a1b2c", "0"), ("close", "zz"), ("kill", "0x5a1b2c"), ("move", "0x5a1b2c")]:
    o, c = run(*bad)
    case("rechaza argumentos inválidos/inyección %r" % (bad,), not o["ok"] and len(c) == 0)
assert all(res), "fallas"
print(f"window-action: {len(res)} casos OK")
