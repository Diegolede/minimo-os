#!/usr/bin/env python3
# python3 tests/updates_test.py — comprobación de actualizaciones con repos git temporales reales
# (remoto local, sin red) y checkupdates simulado en PATH. Verifica que no se toque el repo.
import json, os, subprocess, sys, tempfile

HERE = os.path.dirname(os.path.realpath(__file__))
SCRIPT = os.path.join(HERE, "..", "minimo-shell", "scripts", "updates.py")
ENV = dict(os.environ, GIT_AUTHOR_NAME="t", GIT_AUTHOR_EMAIL="t@t", GIT_COMMITTER_NAME="t", GIT_COMMITTER_EMAIL="t@t")


def sh(cwd, *cmd):
    return subprocess.run(cmd, cwd=cwd, check=True, capture_output=True, text=True, env=ENV).stdout.strip()


def run(path, *extra, env=None):
    r = subprocess.run([sys.executable, SCRIPT, "--dir", path, *extra], capture_output=True, text=True, env=env or ENV, timeout=60)
    assert r.returncode == 0, r.stderr
    return json.loads(r.stdout)


def snapshot(repo):
    return sh(repo, "git", "for-each-ref", "--format=%(refname) %(objectname)") + sh(repo, "git", "rev-parse", "HEAD") + sh(repo, "git", "status", "--porcelain")


t = tempfile.mkdtemp()
origin, clone, other = (os.path.join(t, n) for n in ("origin.git", "clone", "other"))
sh(t, "git", "init", "-q", "--bare", "-b", "main", origin)
sh(t, "git", "clone", "-q", origin, other)
os.makedirs(os.path.join(other, "minimo-shell"))
open(os.path.join(other, "minimo-shell", "VERSION"), "w").write("1.1.0\n")
sh(other, "git", "add", "-A"); sh(other, "git", "commit", "-qm", "1.1.0"); sh(other, "git", "push", "-q", "origin", "main")
sh(t, "git", "clone", "-q", origin, clone)
shell = os.path.join(clone, "minimo-shell")
results = []

def case(name, cond):
    results.append((name, cond)); print(("OK   " if cond else "FALLA"), name)

m = run(shell)["minimo"]
case("al día: mismo commit → uptodate, versión local 1.1.0", m["state"] == "uptodate" and m["version"] == "1.1.0" and not m["ahead"])

open(os.path.join(other, "minimo-shell", "VERSION"), "w").write("1.2.0\n")
sh(other, "git", "commit", "-qam", "1.2.0"); sh(other, "git", "push", "-q", "origin", "main")
before = snapshot(clone)
m = run(shell)["minimo"]
case("remoto con commit nuevo → available", m["state"] == "available" and m["remoteCommit"] == sh(other, "git", "rev-parse", "HEAD"))
case("la comprobación no toca el repo (sin fetch, HEAD y refs iguales)", snapshot(clone) == before)
case("comando sugerido: pull --ff-only + install.sh", m["pull"] == f"git -C {clone} pull --ff-only && {clone}/install.sh")

sh(clone, "git", "pull", "-q", "--ff-only")
open(os.path.join(clone, "local.txt"), "w").write("x"); sh(clone, "git", "add", "-A"); sh(clone, "git", "commit", "-qm", "local")
m = run(shell)["minimo"]
case("clon adelantado (remoto ya incluido) → uptodate con ahead", m["state"] == "uptodate" and m["ahead"])

open(os.path.join(clone, "local.txt"), "w").write("y")
case("cambios sin commit → dirty", run(shell)["minimo"]["dirty"])
sh(clone, "git", "checkout", "-q", "--", "local.txt")

sh(clone, "git", "remote", "set-url", "origin", "https://minimo-os.invalid/x.git")
m = run(shell)["minimo"]
case("sin conexión (host inexistente) → offline, nunca uptodate", m["state"] == "offline")
sh(clone, "git", "remote", "set-url", "origin", origin)

sh(clone, "git", "checkout", "-q", "-b", "solo-local")
sh(clone, "git", "config", "branch.solo-local.remote", "origin"); sh(clone, "git", "config", "branch.solo-local.merge", "refs/heads/no-existe")
m = run(shell)["minimo"]
case("rama remota inexistente → error", m["state"] == "error" and m["reason"] == "no-remote-branch")
sh(clone, "git", "config", "--unset", "branch.solo-local.remote"); sh(clone, "git", "config", "--unset", "branch.solo-local.merge")
case("sin rama de seguimiento → unknown", run(shell)["minimo"]["state"] == "unknown")
sh(clone, "git", "checkout", "-q", "--detach", "HEAD")
case("HEAD separado → unknown (detached)", run(shell)["minimo"]["reason"] == "detached")
case("carpeta que no es un repo → unknown", run(tempfile.mkdtemp())["minimo"]["state"] == "unknown")

# Sistema: checkupdates simulado.
fake = tempfile.mkdtemp()
def sysrun(code, out=""):
    p = os.path.join(fake, "checkupdates")
    open(p, "w").write(f"#!/bin/sh\nprintf '{out}'\nexit {code}\n"); os.chmod(p, 0o755)
    return run(shell, "--system", env=dict(ENV, PATH=fake + ":" + os.environ["PATH"]))["system"]
s = sysrun(0, "linux 6.1 -> 6.2\\nmesa 1 -> 2\\n")
case("checkupdates con 2 paquetes → available, count 2", s["state"] == "available" and s["count"] == 2)
case("checkupdates código 2 → uptodate", sysrun(2)["state"] == "uptodate")
case("checkupdates código 1 → error (nunca uptodate)", sysrun(1)["state"] in ("error", "offline"))
nopath = dict(ENV, PATH="/usr/bin:/bin")
has = subprocess.run(["sh", "-c", "command -v checkupdates"], env=nopath, capture_output=True).returncode == 0
if not has:
    s = run(shell, "--system", env=nopath)["system"]
    case("sin checkupdates → unknown (no se informa «al día»)", s["state"] == "unknown" and s["reason"] == "no-checkupdates")

bad = [n for n, c in results if not c]
assert not bad, bad
print(f"updates: {len(results)} casos OK")
