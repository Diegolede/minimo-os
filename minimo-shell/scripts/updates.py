#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Diego Ledesma (TRN1) — Minimo OS
"""Comprobación de actualizaciones (solo lectura): imprime un JSON y termina.

Minimo OS: el instalador deja un clon git (~/Proyectos/minimo-os por defecto) y enlaza
minimo-shell desde ahí. Se compara HEAD con la rama remota usando `git ls-remote`
(no hace fetch, no toca el repo ni el árbol de trabajo). Si hay una versión nueva y el
remoto es GitHub, se lee minimo-shell/VERSION de esa rama para mostrar el número.

Sistema (--system): `checkupdates` de pacman-contrib (base de datos temporal; nunca
instala nada). Sin checkupdates, el estado es "unknown": jamás se informa "al día" sin
una comprobación real.

Estados: uptodate | available | offline | error | unknown.
"""
import json, os, re, shlex, shutil, subprocess, sys, urllib.request

TIMEOUT = 15


def git(top, *args, timeout=TIMEOUT):
    env = dict(os.environ, GIT_TERMINAL_PROMPT="0", GIT_ASKPASS="/bin/true", SSH_ASKPASS="/bin/true",
               GIT_SSH_COMMAND="ssh -o BatchMode=yes -o ConnectTimeout=10", LC_ALL="C")
    return subprocess.run(["git", "-C", top, *args], capture_output=True, text=True, timeout=timeout, env=env)


def ok(r):
    return r.returncode == 0


def offline_msg(err):
    return bool(re.search(r"could not resolve|unable to access|timed out|network is unreachable|connection (refused|reset)|failed to connect", err, re.I))


def check_minimo(path):
    out = {"state": "unknown", "reason": "", "repo": "", "version": "", "branch": "", "commit": "",
           "remoteCommit": "", "remoteVersion": "", "ahead": False, "dirty": False, "pull": ""}
    try:
        r = git(path, "rev-parse", "--show-toplevel")
    except (OSError, subprocess.TimeoutExpired):
        out["reason"] = "no-git"; return out
    if not ok(r):
        out["reason"] = "no-repo"; return out
    top = r.stdout.strip()
    out["repo"] = top
    try:
        with open(os.path.join(top, "minimo-shell", "VERSION")) as f:
            out["version"] = f.read().strip()
    except OSError:
        pass
    out["commit"] = git(top, "rev-parse", "HEAD").stdout.strip()
    out["dirty"] = git(top, "status", "--porcelain", "--untracked-files=no").stdout.strip() != ""
    b = git(top, "symbolic-ref", "--quiet", "--short", "HEAD")
    if not ok(b):
        out["reason"] = "detached"; return out
    out["branch"] = branch = b.stdout.strip()
    remote = git(top, "config", "--get", f"branch.{branch}.remote").stdout.strip()
    merge = git(top, "config", "--get", f"branch.{branch}.merge").stdout.strip()
    if not remote or not merge:
        out["reason"] = "no-upstream"; return out
    q = shlex.quote(top)          # rutas con espacios: el comando copiado sigue funcionando
    out["pull"] = f"git -C {q} pull --ff-only && {shlex.quote(top + '/install.sh')}"
    try:
        ls = git(top, "ls-remote", "--exit-code", remote, merge)
    except subprocess.TimeoutExpired:
        out["state"] = "offline"; out["reason"] = "timeout"; return out
    if not ok(ls):
        err = ls.stderr.strip()
        if ls.returncode == 2:
            out["state"] = "error"; out["reason"] = "no-remote-branch"
        else:
            out["state"] = "offline" if offline_msg(err) else "error"
            out["reason"] = err.splitlines()[-1][:200] if err else "ls-remote"
        return out
    rsha = ls.stdout.split()[0] if ls.stdout.split() else ""
    out["remoteCommit"] = rsha
    if not rsha:
        out["state"] = "error"; out["reason"] = "ls-remote-empty"; return out
    if rsha == out["commit"]:
        out["state"] = "uptodate"; return out
    # El commit remoto ya está en la historia local: el clon está adelantado (no hay nada nuevo).
    known = ok(git(top, "cat-file", "-e", rsha + "^{commit}"))
    if known and ok(git(top, "merge-base", "--is-ancestor", rsha, "HEAD")):
        out["state"] = "uptodate"; out["ahead"] = True; return out
    out["state"] = "available"
    url = git(top, "remote", "get-url", remote).stdout.strip()
    m = re.match(r"(?:https://github\.com/|git@github\.com:)([^/]+/[^/]+?)(?:\.git)?/?$", url)
    if m:
        ref = merge.replace("refs/heads/", "")
        try:
            with urllib.request.urlopen(f"https://raw.githubusercontent.com/{m.group(1)}/{rsha}/minimo-shell/VERSION", timeout=8) as f:
                v = f.read(64).decode("utf-8", "replace").strip()
                if re.fullmatch(r"[0-9][0-9A-Za-z.+-]{0,30}", v):
                    out["remoteVersion"] = v
        except Exception:
            pass
    return out


def check_system():
    if not shutil.which("checkupdates"):
        return {"state": "unknown", "reason": "no-checkupdates", "count": 0}
    try:
        r = subprocess.run(["checkupdates"], capture_output=True, text=True, timeout=120)
    except subprocess.TimeoutExpired:
        return {"state": "offline", "reason": "timeout", "count": 0}
    # checkupdates: 0 = hay actualizaciones, 2 = ninguna, 1 = error.
    if r.returncode == 0:
        n = len([l for l in r.stdout.splitlines() if l.strip()])
        return {"state": "available" if n else "uptodate", "reason": "", "count": n}
    if r.returncode == 2:
        return {"state": "uptodate", "reason": "", "count": 0}
    err = (r.stderr or "").strip()
    return {"state": "offline" if offline_msg(err) else "error", "reason": err.splitlines()[-1][:200] if err else "checkupdates", "count": 0}


def main():
    path = os.path.dirname(os.path.dirname(os.path.realpath(__file__)))
    args = sys.argv[1:]
    if "--dir" in args:
        path = args[args.index("--dir") + 1]
    res = {"minimo": check_minimo(path)}
    if "--system" in args:
        res["system"] = check_system()
    print(json.dumps(res))


if __name__ == "__main__":
    main()
