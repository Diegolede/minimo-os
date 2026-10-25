// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Diego Ledesma (TRN1) — Minimo OS
// Actualizaciones: notas (CHANGELOG.md) y reglas de comprobación. Lógica pura (tests/updates.test.js).
.pragma library

var MIN_MANUAL = 60 * 1000              // entre dos comprobaciones manuales
var AUTO_EVERY = 24 * 3600 * 1000       // comprobación automática (si está activada)
var AUTO_FIRST = 2 * 60 * 1000          // no comprobar en el arranque mismo

// "## 1.1.0 — 2026-10-16" / "## Próxima versión"; "### Título"; "- punto".
// → [{ version, date, next, sections: [{ title, items: [string] }] }]
function parseChangelog(md) {
    var out = [], cur = null, sec = null
    var lines = String(md || "").split(/\r?\n/)
    for (var i = 0; i < lines.length; i++) {
        var l = lines[i]
        var h2 = l.match(/^##\s+(.+?)\s*$/)
        var h3 = l.match(/^###\s+(.+?)\s*$/)
        var li = l.match(/^\s*[-*]\s+(.+?)\s*$/)
        if (h2 && !h3) {
            var m = h2[1].match(/^v?(\d+\.\d+(?:\.\d+)?(?:[ -]?(?:alpha|beta|rc)\d*)?)\s*(?:[—–-]\s*(\d{4}-\d{2}-\d{2}))?/)
            cur = { version: m ? m[1] : h2[1], date: m && m[2] ? m[2] : "", next: !m, sections: [] }
            sec = null
            out.push(cur)
        } else if (h3 && cur) {
            sec = { title: h3[1], items: [] }
            cur.sections.push(sec)
        } else if (li && sec) {
            sec.items.push(li[1].replace(/\*\*(.+?)\*\*/g, "$1").replace(/`([^`]+)`/g, "$1"))
        }
    }
    return out.filter(function (v) { return v.sections.some(function (s) { return s.items.length > 0 }) })
}

// ¿Se puede lanzar una comprobación ahora? Nunca dos a la vez; las manuales, con un mínimo
// entre una y otra; las automáticas, solo si ya pasó AUTO_EVERY desde la última.
function canCheck(now, last, running, manual) {
    if (running) return false
    if (!last) return true
    if (manual && last > now) return true   // reloj atrasado: la manual no queda bloqueada para siempre
    return now - last >= (manual ? MIN_MANUAL : AUTO_EVERY)
}

// Milisegundos hasta la próxima comprobación automática (un único temporizador).
function autoDelay(now, last) {
    var due = last ? last + AUTO_EVERY : now
    return Math.max(AUTO_FIRST, Math.min(AUTO_EVERY, due - now))
}

// Estado mostrado: un error o una comprobación fallida jamás se muestra como "al día".
var STATES = ["unknown", "checking", "uptodate", "available", "offline", "error"]
function sane(s) { return STATES.indexOf(s) >= 0 ? s : "unknown" }

// Novedades de la versión remota que todavía no están instaladas: las entradas del CHANGELOG
// remoto anteriores a la versión instalada (sin "Próxima versión"). Si la instalada no
// aparece, solo la primera (la más nueva), para no repetir el historial completo.
function newerNotes(remote, installed) {
    var v = parseChangelog(remote).filter(function (x) { return !x.next })
    var cur = String(installed || "").trim(), out = []
    for (var i = 0; i < v.length; i++) {
        if (v[i].version === cur) return out
        out.push(v[i])
    }
    return v.slice(0, 1)
}

// Una comprobación guardada deja de valer si la versión instalada cambió desde entonces
// (p. ej. después de actualizar): "disponible" no puede quedar pegado.
function stale(saved, installed) {
    if (!saved || !saved.version || !installed) return false
    return String(saved.version).trim() !== String(installed).trim()
}

// Líneas "@@..." de scripts/update-run.sh e install.sh --update.
// → { kind: "step"|"needsSudo"|"error"|"pulled"|"version"|"done"|"finished"|"", ... }
function parseLine(line) {
    var l = String(line || "")
    if (l.indexOf("@@") !== 0) return { kind: "" }
    var p = l.slice(2).split(" ")
    switch (p[0]) {
    case "STEP": return { kind: "step", step: Number(p[1]) || 0, total: Number(p[2]) || 0, title: p.slice(3).join(" ") }
    case "NEEDS_SUDO": return { kind: "needsSudo", packages: p.slice(1).filter(function (x) { return x !== "" }) }
    case "ERROR": return { kind: "error", reason: p[1] || "unknown" }
    case "PULLED": return { kind: "pulled", from: p[1] || "", to: p[2] || "" }
    case "VERSION": return { kind: "version", version: p.slice(1).join(" ") }
    case "DONE": return { kind: "done", ok: p[1] === "ok" }
    case "FINISHED": return { kind: "finished" }
    }
    return { kind: "" }
}

// Progreso 0..1: la descarga cuenta como un paso más que los del instalador.
function progress(step, total) {
    if (!total) return 0
    return Math.max(0, Math.min(1, (step + 1) / (total + 1)))
}
