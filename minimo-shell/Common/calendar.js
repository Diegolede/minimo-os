// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Diego Ledesma (TRN1) — Minimo OS
.pragma library
// Cuadrícula de un mes para el calendario de la isla. Funciones puras
// (sin Date del sistema salvo para el día de la semana); pruebas en tests/calendar.test.js.

function isLeap(y) { return (y % 4 === 0 && y % 100 !== 0) || y % 400 === 0 }
function daysIn(y, m) { return [31, isLeap(y) ? 29 : 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31][m] }
// Día de la semana (0 = domingo) por la congruencia de Zeller; m en 0..11.
function weekday(y, m, d) {
    let mm = m + 1, yy = y
    if (mm < 3) { mm += 12; yy -= 1 }
    const k = yy % 100, j = Math.floor(yy / 100)
    const h = (d + Math.floor(13 * (mm + 1) / 5) + k + Math.floor(k / 4) + Math.floor(j / 4) + 5 * j) % 7
    return (h + 6) % 7
}
// Suma meses: { y, m } con cambio de año.
function addMonths(y, m, n) {
    const t = y * 12 + m + n
    return { y: Math.floor(t / 12), m: ((t % 12) + 12) % 12 }
}
// 6 semanas × 7 días empezando en firstDay (0 = domingo … 6 = sábado).
// Cada celda: { y, m, d, inMonth }.
function monthGrid(y, m, firstDay) {
    const lead = (weekday(y, m, 1) - firstDay + 7) % 7
    const prev = addMonths(y, m, -1), next = addMonths(y, m, 1)
    const prevDays = daysIn(prev.y, prev.m), n = daysIn(y, m)
    const cells = []
    for (let i = 0; i < 42; i++) {
        const d = i - lead + 1
        if (d < 1) cells.push({ y: prev.y, m: prev.m, d: prevDays + d, inMonth: false })
        else if (d > n) cells.push({ y: next.y, m: next.m, d: d - n, inMonth: false })
        else cells.push({ y: y, m: m, d: d, inMonth: true })
    }
    return cells
}
