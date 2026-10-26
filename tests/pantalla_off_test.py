#!/usr/bin/env python3
# python3 tests/pantalla_off_test.py — pantalla-off.sh con un hyprctl simulado: espera, DPMS por
# software (nunca suspende ni bloquea), un solo apagado a la vez y atajo registrado en la ayuda.
import os, subprocess, sys, tempfile, time
HERE = os.path.dirname(os.path.realpath(__file__)); ROOT = os.path.join(HERE, "..")
SCRIPT = os.path.join(ROOT, "minimo-shell", "scripts", "pantalla-off.sh")
d = tempfile.mkdtemp(); log = os.path.join(d, "log")
open(os.path.join(d, "hyprctl"), "w").write(f'#!/bin/sh\necho "$@" >> {log}\n')
os.chmod(os.path.join(d, "hyprctl"), 0o755)
env = dict(os.environ, PATH=d + ":" + os.environ["PATH"], XDG_RUNTIME_DIR=d, MINIMO_DPMS_DELAY="0.5")
res = []
def case(n, c): res.append(c); print(("OK   " if c else "FALLA"), n)

t = time.time(); subprocess.run([SCRIPT], env=env); dt = time.time() - t
calls = open(log).read().splitlines()
case("espera antes de apagar", dt >= 0.5)
case("una sola llamada: DPMS disable", calls == ['dispatch hl.dsp.dpms({ action = "disable" })'])
src = "\n".join(l for l in open(SCRIPT).read().splitlines() if not l.lstrip().startswith("#"))
case("nunca suspende, bloquea ni cierra sesión", not any(w in src for w in ("systemctl", "suspend", "hyprlock", "loginctl", "exit()")))
os.remove(log)
a = subprocess.Popen([SCRIPT], env=env); time.sleep(0.1); subprocess.run([SCRIPT], env=env); a.wait()
case("doble pulsación: un solo apagado", len(open(log).read().splitlines()) == 1)
cfg = open(os.path.join(ROOT, "hypr/minimo/apariencia.lua")).read()
case("despierta con mouse y teclado", "mouse_move_enables_dpms = true" in cfg and "key_press_enables_dpms = true" in cfg)
out = subprocess.run([sys.executable, os.path.join(ROOT, "minimo-shell/scripts/atajos.py")], capture_output=True, text=True).stdout
case("Super+Shift+M aparece como Apagar monitor", "Apagar monitor" in out and "Apagar pantalla" not in out)
qi = open(os.path.join(ROOT, "minimo-shell/Common/QuickItems.qml")).read(); ds = open(os.path.join(ROOT, "minimo-shell/Common/DisplayState.qml")).read()
case("atajo rápido en la isla, fijado por defecto", "id: \"screenoff\"" in qi and "\"files\", \"screenoff\"]" in ds)
act = open(os.path.join(ROOT, "minimo-shell/Island/sections/ActionsSection.qml")).read()
case("fila de energía sin el botón", "pantalla-off" not in act and "screenOff" not in act)
sys.exit(0 if all(res) else 1)
