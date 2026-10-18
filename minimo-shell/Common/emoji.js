// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Diego Ledesma (TRN1) — Minimo OS
// Selector de emojis: lógica pura (se prueba con node en tests/emoji.test.js).
.pragma library

var TONES = ["", "\u{1F3FB}", "\u{1F3FC}", "\u{1F3FD}", "\u{1F3FE}", "\u{1F3FF}"]

// Minúsculas y sin tildes, para buscar "cafe" y encontrar "café".
function norm(s) {
    return String(s || "").normalize("NFD").replace(/[\u0300-\u036f]/g, "").toLowerCase().trim()
}

// emoji.json → [{ id, label, icon, items: [{ e, name, key, tone }] }] en el idioma pedido.
function parse(text, lang) {
    var d
    try { d = JSON.parse(text) } catch (e) { return [] }
    if (!d || !Array.isArray(d.categories)) return []
    var en = lang === "en"
    return d.categories.map(function (c) {
        return {
            id: c.id, label: en ? c.en : c.es, icon: c.icon,
            items: (c.items || []).filter(function (it) { return Array.isArray(it) && typeof it[0] === "string" && it[0] }).map(function (it) {
                return { e: it[0], name: en ? it[2] : it[1], key: norm(it[1] + " " + it[2]), tone: it[3] === 1 }
            })
        }
    })
}

// Busca en los nombres en español e inglés (todas las palabras deben aparecer). Máx. `limit`.
function search(cats, query, limit) {
    var words = norm(query).split(/\s+/).filter(function (w) { return w })
    if (words.length === 0) return []
    var out = []
    for (var i = 0; i < cats.length; i++)
        for (var j = 0; j < cats[i].items.length; j++) {
            var it = cats[i].items[j]
            if (words.every(function (w) { return it.key.indexOf(w) >= 0 })) {
                out.push(it)
                if (out.length >= (limit || 64)) return out
            }
        }
    return out
}

// Tono de piel: el modificador va justo después del primer código (y sin el selector
// de variación U+FE0F, que el modificador reemplaza: ✌️ + 🏽 → ✌🏽).
function withTone(e, tone) {
    var t = TONES[tone] || ""
    if (!t) return e
    // Sin Array.from: el motor JS de Qt 6.8 itera por unidades UTF-16 y partía los pares sustitutos.
    var first = String.fromCodePoint(e.codePointAt(0))
    var rest = e.slice(first.length)
    if (rest.charAt(0) === "\uFE0F") rest = rest.slice(1)
    return first + t + rest
}

// Texto exacto que se copia para un elemento.
function textFor(item, tone) { return item.tone ? withTone(item.e, tone) : item.e }

// Solo para dibujar: Qt 6.8 parte en dos las secuencias ZWJ que llevan U+FE0F antes del
// U+200D (🏳️‍🌈 → 🏳 + 🌈); sin ese selector, la fuente de emojis las une igual. Lo copiado
// siempre es la secuencia completa (textFor), nunca esta.
function glyph(s) { return String(s).replace(/\uFE0F\u200D/g, "\u200D") }
