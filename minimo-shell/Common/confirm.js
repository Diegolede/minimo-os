.pragma library
// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Diego Ledesma (TRN1) — Minimo OS
// Máquina de estados de las acciones de energía (una sola para todas):
//   reposo --clic A--> armado(A) --clic A (< armMs)--> ejecuta A una vez --> reposo
//   armado(A) --clic B--> armado(B)   (nunca hay dos armadas a la vez)
//   tras ejecutar, se ignoran clics durante guardMs (doble clic / clics rápidos).
// Funciones puras: reciben el estado y devuelven { state, run } (run = id a ejecutar o "").

function initial() { return { armed: "", armedAt: 0, firedAt: -1e15 } }

function press(st, id, now, armMs, guardMs) {
    if (now - st.firedAt < guardMs) return { state: st, run: "" }
    if (st.armed === id && now - st.armedAt < armMs)
        return { state: { armed: "", armedAt: 0, firedAt: now }, run: id }
    return { state: { armed: id, armedAt: now, firedAt: st.firedAt }, run: "" }
}

function disarm(st) { return { armed: "", armedAt: 0, firedAt: st.firedAt } }
