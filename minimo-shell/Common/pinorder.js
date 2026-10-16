// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Diego Ledesma (TRN1) — Minimo OS
.pragma library
// Orden del menú de la isla: lista de TODOS los elementos (fijados o no), así
// desactivar y volver a activar conserva la posición. Funciones puras (tests/pinorder.test.js).

// Orden completo: lo guardado (sin duplicados ni borrados), luego los fijados que falten
// (respeta el orden histórico de `pins`) y por último el resto en el orden del catálogo.
function full(saved, pins, all) {
    const out = []
    const add = id => { if (all.indexOf(id) >= 0 && out.indexOf(id) < 0) out.push(id) }
    ;(saved || []).forEach(add); (pins || []).forEach(add); all.forEach(add)
    return out
}
// Mueve `id` una posición (delta -1 arriba, +1 abajo). Fuera de rango: sin cambios.
function move(order, id, delta) {
    const i = order.indexOf(id), j = i + delta
    if (i < 0 || j < 0 || j >= order.length) return order.slice()
    const out = order.slice(); out[i] = order[j]; out[j] = id
    return out
}
// Fijados ordenados según `order` (sin duplicados).
function sortPins(pins, order) {
    return order.filter(id => pins.indexOf(id) >= 0)
}
