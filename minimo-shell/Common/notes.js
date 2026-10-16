// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Diego Ledesma (TRN1) — Minimo OS
.pragma library
// Notas de la isla: funciones puras sobre la lista [{ id, text, updated }]
// (más reciente primero). Pruebas en tests/notes.test.js.

function parse(text) {
    try {
        const d = JSON.parse(text)
        const list = Array.isArray(d) ? d : (d && Array.isArray(d.notes) ? d.notes : [])
        return list.filter(n => n && typeof n.id === "string" && typeof n.text === "string")
                   .map(n => ({ id: n.id, text: n.text, updated: Number(n.updated) || 0 }))
    } catch (e) { return [] }
}
function serialize(notes) { return JSON.stringify({ version: 1, notes: notes }, null, 2) + "\n" }
function newId(now, notes) {
    let id = "n" + now.toString(36), k = 0
    while (notes.some(n => n.id === id)) id = "n" + now.toString(36) + "-" + (++k)
    return id
}
function add(notes, now) { const n = { id: newId(now, notes), text: "", updated: now }; return { notes: [n].concat(notes), id: n.id } }
// Editar sube la nota arriba; sin cambios, la lista queda igual.
function update(notes, id, text, now) {
    const n = notes.find(x => x.id === id)
    if (!n || n.text === text) return notes
    return [{ id: id, text: text, updated: now }].concat(notes.filter(x => x.id !== id))
}
function remove(notes, id) { return notes.filter(x => x.id !== id) }
// Título = primera línea no vacía (la vista pone "Nota nueva" si está vacía).
function title(text) { const l = text.split("\n").find(s => s.trim() !== ""); return l ? l.trim() : "" }
function preview(text) {
    const lines = text.split("\n").filter(s => s.trim() !== "")
    return lines.slice(1).join(" ").trim()
}
// Al guardar se descartan las notas vacías.
function prune(notes) { return notes.filter(n => n.text.trim() !== "") }
