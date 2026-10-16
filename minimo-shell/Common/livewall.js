.pragma library
// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Diego Ledesma (TRN1) — Minimo OS
// Ciclo de vida del proceso de fondo animado (mpvpaper), sin efectos: el que llama ejecuta
// la acción devuelta ("start" | "stop" | "none") y avisa cuando el proceso termina.
//   · Nunca hay dos procesos: para cambiar de archivo primero se detiene y se arranca el nuevo
//     recién cuando el anterior terminó (exited).
//   · Si un proceso muere solo en menos de 2 s (archivo inválido, falta GPU…) no se reintenta
//     ese archivo hasta que se elija otro (evita un bucle de reinicios).

function initial() { return { current: "", running: false, stopping: false, startedAt: 0, failed: "" } }

function want(st, path, now) {
    const s = Object.assign({}, st)
    if (path !== s.failed) s.failed = ""            // otro archivo: se puede volver a intentar
    if (s.running) {
        if (s.current === path || s.stopping) return { state: s, act: "none" }
        s.stopping = true                           // al terminar, el que llama vuelve a pedir want()
        return { state: s, act: "stop" }
    }
    if (path === "" || path === s.failed) return { state: s, act: "none" }
    s.current = path; s.running = true; s.stopping = false; s.startedAt = now
    return { state: s, act: "start" }
}

function exited(st, now) {
    const s = Object.assign({}, st)
    if (!s.stopping && now - s.startedAt < 2000) s.failed = s.current
    s.running = false; s.stopping = false; s.current = ""
    return s
}
