// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Diego Ledesma (TRN1) — Minimo OS
pragma Singleton
import QtQuick
import Quickshell
import "i18n.js" as D

// Idioma de la interfaz (español / inglés). Uso: I18n.tr("Texto en español", arg1, …).
// Como `tr` lee `lang`, los bindings se reevalúan solos al cambiar de idioma.
// El contenido del usuario (notas, nombres de accesos, títulos de ventanas…) no pasa por acá.
Singleton {
    id: root
    readonly property string lang: DisplayState.language
    readonly property var languages: D.languages
    readonly property var locale: Qt.locale(D.localeName(lang))

    function tr(s) { return D.translate(root.lang, s, Array.prototype.slice.call(arguments, 1)) }
    // "Jueves 15 de octubre" / "Thursday, October 15"
    function longDate(d) {
        const t = d.toLocaleDateString(root.locale, root.lang === "en" ? "dddd, MMMM d" : "dddd d 'de' MMMM")
        return t.charAt(0).toUpperCase() + t.slice(1)
    }
}
