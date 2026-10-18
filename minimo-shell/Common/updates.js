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
            var m = h2[1].match(/^v?(\d+\.\d+(?:\.\d+)?)\s*(?:[—–-]\s*(\d{4}-\d{2}-\d{2}))?/)
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
