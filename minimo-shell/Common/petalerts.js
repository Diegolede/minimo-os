.pragma library
// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Diego Ledesma (TRN1) — Minimo OS
// Avisos de necesidades de la mascota (funciones puras; tests/petalerts.test.js).
// Un aviso por necesidad y por "episodio": se avisa al ENTRAR en necesidad (nivel < umbral),
// con un intervalo mínimo por necesidad y otro global (nunca una ráfaga). Cuando la necesidad
// se atiende (nivel ≥ umbral) el episodio termina y el aviso viejo se retira.
//   alerts = { food: { alerted, last }, fun: {...}, energy: {...}, lastAny }

var IDS = ["food", "fun", "energy"]

function initial() {
    return { food: { alerted: false, last: 0 }, fun: { alerted: false, last: 0 }, energy: { alerted: false, last: 0 }, lastAny: 0 }
}

// Normaliza lo leído del disco (campos faltantes o basura → valores seguros).
function sane(a) {
    var r = initial()
    if (!a || typeof a !== "object") return r
    IDS.forEach(function (id) {
        var x = a[id]
        if (x && typeof x === "object") r[id] = { alerted: x.alerted === true, last: +x.last > 0 ? +x.last : 0 }
    })
    r.lastAny = +a.lastAny > 0 ? +a.lastAny : 0
    return r
}

function copy(a) { return JSON.parse(JSON.stringify(a)) }

// levels = { food, fun, energy } (0..1); below = umbrales del modelo.
// Devuelve { alerts, post: id|"", ended: [ids], retryAt: ms|Infinity }.
function step(alerts, levels, below, now, minPer, minGlobal) {
    var a = copy(alerts), post = "", ended = [], retryAt = Infinity
    IDS.forEach(function (id) {
        if (levels[id] >= below[id] && a[id].alerted) { a[id].alerted = false; ended.push(id) }
    })
    IDS.forEach(function (id) {
        if (post !== "" || levels[id] >= below[id] || a[id].alerted) return
        var ready = Math.max(a[id].last + minPer, a.lastAny + minGlobal)
        if (now >= ready) { post = id; a[id].alerted = true; a[id].last = now; a.lastAny = now }
        else retryAt = Math.min(retryAt, ready)
    })
    // Otra necesidad esperando su turno detrás de la que se avisó ahora.
    if (post !== "") IDS.forEach(function (id) {
        if (id !== post && levels[id] < below[id] && !a[id].alerted) retryAt = Math.min(retryAt, Math.max(a[id].last + minPer, a.lastAny + minGlobal))
    })
    return { alerts: a, post: post, ended: ended, retryAt: retryAt }
}

// Al volver a activar la mascota: lo que ya está en necesidad cuenta como avisado (sin ráfaga).
function suppress(alerts, levels, below, now) {
    var a = copy(alerts)
    IDS.forEach(function (id) { if (levels[id] < below[id]) { a[id].alerted = true; a[id].last = now } })
    return a
}

// Próximo instante en que alguna necesidad hoy satisfecha cruzará su umbral (sin sondeo).
// m = { lastFed, lastPlayed, activeSince, idle, foodSpan, funSpan, energySpan }
function nextCrossing(m, below, now) {
    var t = [m.lastFed + m.foodSpan * (1 - below.food), m.lastPlayed + m.funSpan * (1 - below.fun)]
    if (!m.idle) t.push(m.activeSince + m.energySpan * (1 - below.energy))
    var best = Infinity
    t.forEach(function (x) { if (x > now && x < best) best = x })
    return best
}
