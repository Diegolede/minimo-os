// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Diego Ledesma (TRN1) — Minimo OS
.pragma library
// Sesiones para el selector de la pantalla de inicio. Funciones puras (tests/sessions.test.js).
// Entrada: la salida de `scripts`/shell.qml, bloques "@@FILE <ruta>" seguidos del .desktop.

// Exec según la especificación Desktop Entry: comillas dobles, escapes \" \` \$ \\,
// y los códigos de campo (%f %F %u %U %i %c %k…) se quitan; %% → %.
function splitExec(exec) {
    const out = []; let cur = "", inQ = false, has = false
    for (let i = 0; i < exec.length; i++) {
        const ch = exec[i]
        if (inQ) {
            if (ch === "\\" && i + 1 < exec.length && "\"`$\\".indexOf(exec[i + 1]) >= 0) { cur += exec[++i]; continue }
            if (ch === "\"") { inQ = false; continue }
            cur += ch
        } else if (ch === "\"") { inQ = true; has = true }
        else if (ch === " " || ch === "\t") { if (cur !== "" || has) out.push(cur); cur = ""; has = false }
        else cur += ch
    }
    if (inQ) return []                       // comillas sin cerrar: Exec inválido
    if (cur !== "" || has) out.push(cur)
    return out.map(a => a.replace(/%%/g, "\u0000")).filter(a => !/^%[a-zA-Z]$/.test(a))
              .map(a => a.replace(/%[a-zA-Z]/g, "").replace(/\u0000/g, "%")).filter(a => a !== "")
}

// Un .desktop → { id, name, exec: [argv], desktopNames } o null (oculto, sin Exec, otro tipo).
function parseDesktop(text, file) {
    let inMain = false; const kv = {}
    for (const raw of text.split("\n")) {
        const line = raw.trim()
        if (line === "" || line[0] === "#") continue
        if (line[0] === "[") { inMain = line === "[Desktop Entry]"; continue }
        if (!inMain) continue
        const eq = line.indexOf("="); if (eq < 0) continue
        const k = line.slice(0, eq).trim(), v = line.slice(eq + 1).trim()
        if (!(k in kv)) kv[k] = v
    }
    if (kv.Hidden === "true" || kv.NoDisplay === "true") return null
    if (kv.Type && kv.Type !== "Application") return null
    const exec = splitExec(kv.Exec || "")
    if (!exec.length) return null
    const base = file.split("/").pop().replace(/\.desktop$/, "")
    return { id: base, name: kv.Name || base, exec: exec, desktopNames: kv.DesktopNames || "" }
}

// Lista completa: primero la de Minimo (minimo-session, Hyprland), luego las válidas
// ordenadas por nombre. Las que lanzan Hyprland directamente quedan, con su nombre.
function parseAll(dump, minimoExec) {
    const list = [], parts = dump.split("@@FILE ")
    for (const p of parts) {
        const nl = p.indexOf("\n"); if (nl < 0) continue
        const s = parseDesktop(p.slice(nl + 1), p.slice(0, nl).trim())
        if (s && !list.some(x => x.id === s.id)) list.push(s)
    }
    list.sort((a, b) => a.name.localeCompare(b.name))
    return [{ id: "minimo", name: "Minimo OS", exec: minimoExec, desktopNames: "Hyprland" }].concat(list)
}
// Variables de entorno para greetd según la sesión.
function envFor(s) {
    const d = (s.desktopNames || "").split(";").filter(x => x)
    const env = ["XDG_SESSION_TYPE=wayland"]
    if (d.length) env.push("XDG_SESSION_DESKTOP=" + d[0], "XDG_CURRENT_DESKTOP=" + d.join(":"))
    return env
}
// Elección inicial: la recordada si sigue existiendo; si no, Minimo.
function pick(list, remembered) {
    const id = (remembered || "").trim()
    return list.some(s => s.id === id) ? id : "minimo"
}
