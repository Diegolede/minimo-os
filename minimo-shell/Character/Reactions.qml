// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Diego Ledesma (TRN1) — Minimo OS
import QtQuick

// Reacciones del personaje: animaciones con nombre, elegidas al azar con pesos y sin
// repetir las últimas dos. Principios: anticipación → acción → asentamiento con overshoot
// sutil; squash & stretch ≤ 8 % que conserva volumen; ease-out-cubic/quint para entradas,
// ease-in-out para idas y vueltas. Los ojos son SIEMPRE pastillas (la alegría se expresa
// con `smile`: pastillas un poco más bajas y elevadas, como mejillas que suben).
// Si una reacción interrumpe a otra, primero se asienta todo a neutro (~160 ms): sin saltos.
Item {
    id: rx
    required property Item c
    property var history: []
    readonly property bool busy: (current !== null && current.running) || settle.running
    property var current: null
    property var pending: null

    readonly property real s: c.s

    // Repertorio espontáneo (raro: cada 45–120 s, ver Character). "yawn" sube si lleva rato quieto.
    function idleWeights(idleMs) {
        return { hop: 1.8, wink: 2.2, doubleHop: 0.8, giggle: 1.2, lookAround: 1.6,
                 surprise: 0.6, dizzy: 0.3, curious: 1.4, yawn: idleMs > 25000 ? 2.5 : 0.4 }
    }
    function pick(weights) {
        // El guiño puede repetirse (máx. 2 seguidos); el resto no repite las últimas dos.
        const ks = Object.keys(weights).filter(k => k === "wink" ? !(history[0] === "wink" && history[1] === "wink") : history.indexOf(k) < 0)
        let total = 0; for (const k of ks) total += weights[k]
        let x = Math.random() * total
        for (const k of ks) { x -= weights[k]; if (x <= 0) return k }
        return ks[ks.length - 1]
    }
    function playRandom(idleMs) { play(pick(idleWeights(idleMs))) }
    // Mascota: "Jugar" elige entre juegos variados sin repetir los dos últimos.
    readonly property var playWeights: ({ sway: 1.3, wiggle: 1.2, peekaboo: 1.1, giggle: 1, curious: 0.7, wink: 0.6 })
    function playGame() { play(pick(playWeights)) }
    function playOpen() { play(pick({ greet: 1.3, happyBounce: 1.1 })) }
    // Clic: ciclo fijo (siempre se ve algo distinto); el primero tras mostrarse es el guiño.
    readonly property var clickCycle: ["wink", "giggle", "wink", "happyBounce", "wink", "curious"]
    property int clickIdx: 0
    function resetClicks() { clickIdx = 0 }
    function playClick() { const n = clickCycle[clickIdx % clickCycle.length]; clickIdx++; play(n, true) }

    readonly property var anims: ({ hop: hop, doubleHop: doubleHop, giggle: giggle, lookAround: lookAround,
        surprise: surprise, wink: wink, dizzy: dizzy, yawn: yawn, curious: curious,
        greet: greet, happyBounce: happyBounce, startled: startled,
        chew: chew, sway: sway, wiggle: wiggle, peekaboo: peekaboo })

    function play(name, fromClick) {
        const a = anims[name]
        if (!a) return
        if (!fromClick) history = [name].concat(history).slice(0, 2)
        if (busy) { stopAll(); pending = a; settle.restart() }
        else { reset(); current = a; a.start() }
    }
    // Detiene todo y vuelve a neutro suavemente (dormir, baile, ánimo tienen prioridad).
    function rest() { stopAll(); pending = null; settle.restart() }   // a pose neutra, siempre
    function calm() { if (busy) { stopAll(); pending = null; settle.restart() } }
    function stopAll() {
        if (current && current.running) current.stop()
        current = null
        // giros a su equivalente más cercano a 0 para volver por el camino corto
        c.roll = ((c.roll % 360) + 540) % 360 - 180
        c.rRot = ((c.rRot % 360) + 540) % 360 - 180
    }
    function reset() {
        c.rScale = 1; c.rX = 0; c.rY = 0; c.rRot = 0; c.roll = 0
        c.bounceY = 0; c.squashX = 1; c.squashY = 1
        c.lookOverride = 0; c.oX = 0; c.oY = 0
        c.eyeHMul = 1; c.eyeWMul = 1; c.openL = 1; c.openR = 1; c.smile = 0; c.wobble = 0; c.half = 1
    }
    SequentialAnimation {
        id: settle
        ParallelAnimation {
            NumberAnimation { target: rx.c; properties: "rScale,squashX,squashY,eyeHMul,eyeWMul,openL,openR,half"; to: 1; duration: 160; easing.type: Easing.OutCubic }
            NumberAnimation { target: rx.c; properties: "rX,rY,rRot,roll,bounceY,lookOverride,oX,oY,smile,wobble"; to: 0; duration: 160; easing.type: Easing.OutCubic }
        }
        ScriptAction { script: { rx.reset(); if (rx.pending) { rx.current = rx.pending; rx.pending = null; rx.current.start() } } }
    }

    // ---------- saltos ----------
    // Anticipación (agacharse) → despegue estirado → caída → aterrizaje aplastado → asentar.
    SequentialAnimation {
        id: hop
        Squash { who: rx.c; sx: 1.06; sy: 0.94; ms: 130; ease: Easing.OutCubic }
        Squash { who: rx.c; sx: 0.96; sy: 1.05; toY: -rx.s * 0.16; ms: 200; ease: Easing.OutCubic }
        Squash { who: rx.c; sx: 1; sy: 1; toY: 0; ms: 170; ease: Easing.InQuad }
        Squash { who: rx.c; sx: 1.05; sy: 0.95; ms: 70; ease: Easing.OutQuad }
        Squash { who: rx.c; sx: 1; sy: 1; ms: 260; ease: Easing.OutBack }
    }
    SequentialAnimation {
        id: doubleHop
        Squash { who: rx.c; sx: 1.06; sy: 0.94; ms: 120; ease: Easing.OutCubic }
        Squash { who: rx.c; sx: 0.97; sy: 1.04; toY: -rx.s * 0.12; ms: 170; ease: Easing.OutCubic }
        Squash { who: rx.c; sx: 1; sy: 1; toY: 0; ms: 140; ease: Easing.InQuad }
        Squash { who: rx.c; sx: 1.05; sy: 0.95; ms: 70; ease: Easing.OutQuad }
        Squash { who: rx.c; sx: 0.96; sy: 1.05; toY: -rx.s * 0.18; ms: 200; ease: Easing.OutCubic }
        Squash { who: rx.c; sx: 1; sy: 1; toY: 0; ms: 180; ease: Easing.InQuad }
        Squash { who: rx.c; sx: 1.05; sy: 0.95; ms: 70; ease: Easing.OutQuad }
        Squash { who: rx.c; sx: 1; sy: 1; ms: 280; ease: Easing.OutBack }
    }

    // ---------- risita: se aleja un poco, sonríe y se balancea ----------
    SequentialAnimation {
        id: giggle
        ParallelAnimation {
            NumberAnimation { target: rx.c; property: "rScale"; to: 0.92; duration: 280; easing.type: Easing.OutCubic }
            NumberAnimation { target: rx.c; property: "rY"; to: -rx.s * 0.04; duration: 280; easing.type: Easing.OutCubic }
            NumberAnimation { target: rx.c; property: "smile"; to: 1; duration: 220; easing.type: Easing.OutCubic }
        }
        Repeater3 { target: rx.c; amp: 6; drop: rx.s * 0.035 }
        ParallelAnimation {
            NumberAnimation { target: rx.c; property: "rScale"; to: 1; duration: 360; easing.type: Easing.OutBack; easing.overshoot: 1.0 }
            NumberAnimation { target: rx.c; property: "rY"; to: 0; duration: 360; easing.type: Easing.OutCubic }
            SequentialAnimation { PauseAnimation { duration: 140 } NumberAnimation { target: rx.c; property: "smile"; to: 0; duration: 260; easing.type: Easing.InOutSine } }
        }
    }

    // ---------- mirar alrededor (con persecución suave y leve giro de cuerpo) ----------
    SequentialAnimation {
        id: lookAround
        ParallelAnimation {
            NumberAnimation { target: rx.c; property: "lookOverride"; to: 1; duration: 220; easing.type: Easing.OutCubic }
            NumberAnimation { target: rx.c; property: "oX"; from: 0; to: -0.85; duration: 460; easing.type: Easing.InOutSine }
            NumberAnimation { target: rx.c; property: "rRot"; to: -4; duration: 520; easing.type: Easing.InOutSine }
        }
        PauseAnimation { duration: 380 }
        ParallelAnimation {
            NumberAnimation { target: rx.c; property: "oX"; to: 0.85; duration: 820; easing.type: Easing.InOutCubic }
            NumberAnimation { target: rx.c; property: "rRot"; to: 4; duration: 880; easing.type: Easing.InOutCubic }
        }
        PauseAnimation { duration: 420 }
        ParallelAnimation {
            NumberAnimation { target: rx.c; property: "oX"; to: 0; duration: 420; easing.type: Easing.OutCubic }
            NumberAnimation { target: rx.c; property: "rRot"; to: 0; duration: 480; easing.type: Easing.OutBack; easing.overshoot: 1.0 }
        }
        NumberAnimation { target: rx.c; property: "lookOverride"; to: 0; duration: 320; easing.type: Easing.InOutSine }
    }

    // ---------- sorpresa ----------
    SequentialAnimation {
        id: surprise
        ParallelAnimation {
            NumberAnimation { target: rx.c; property: "eyeHMul"; to: 1.18; duration: 140; easing.type: Easing.OutCubic }
            NumberAnimation { target: rx.c; property: "eyeWMul"; to: 1.15; duration: 140; easing.type: Easing.OutCubic }
            Squash { who: rx.c; sx: 0.95; sy: 1.05; toY: -rx.s * 0.08; ms: 160; ease: Easing.OutCubic }
        }
        Squash { who: rx.c; sx: 1; sy: 1; toY: 0; ms: 260; ease: Easing.OutBack }
        PauseAnimation { duration: 520 }
        ParallelAnimation {
            NumberAnimation { target: rx.c; property: "eyeHMul"; to: 1; duration: 360; easing.type: Easing.InOutSine }
            NumberAnimation { target: rx.c; property: "eyeWMul"; to: 1; duration: 360; easing.type: Easing.InOutSine }
        }
    }

    // ---------- guiño ----------
    // Asimétrico: un ojo se cierra rápido con la mejilla que sube (ojo un poco más ancho),
    // el otro se entrecierra apenas, cabeza inclinada hacia el lado del guiño.
    // Cierre ~90 ms, pausa ~180 ms, apertura más suave con overshoot mínimo.
    SequentialAnimation {
        id: wink
        property real side: 1          // 1 = ojo derecho, -1 = izquierdo
        ScriptAction { script: wink.side = Math.random() < 0.7 ? 1 : -1 }
        ParallelAnimation {
            NumberAnimation { target: rx.c; property: "openR"; to: wink.side > 0 ? 0.08 : 0.82; duration: wink.side > 0 ? 90 : 140; easing.type: wink.side > 0 ? Easing.InQuad : Easing.OutCubic }
            NumberAnimation { target: rx.c; property: "openL"; to: wink.side > 0 ? 0.82 : 0.08; duration: wink.side > 0 ? 140 : 90; easing.type: wink.side > 0 ? Easing.OutCubic : Easing.InQuad }
            NumberAnimation { target: rx.c; property: "smile"; to: 0.7; duration: 140; easing.type: Easing.OutCubic }
            NumberAnimation { target: rx.c; property: "eyeWMul"; to: 1.06; duration: 120; easing.type: Easing.OutCubic }
            NumberAnimation { target: rx.c; property: "rRot"; to: 5 * wink.side; duration: 200; easing.type: Easing.OutCubic }
            Squash { who: rx.c; sx: 1.03; sy: 0.97; ms: 110; ease: Easing.OutCubic }
        }
        PauseAnimation { duration: 180 }
        ParallelAnimation {
            NumberAnimation { target: rx.c; properties: "openR,openL"; to: 1; duration: 260; easing.type: Easing.OutBack; easing.overshoot: 1.2 }
            NumberAnimation { target: rx.c; property: "eyeWMul"; to: 1; duration: 260; easing.type: Easing.OutCubic }
            Squash { who: rx.c; sx: 1; sy: 1; ms: 300; ease: Easing.OutBack }
            NumberAnimation { target: rx.c; property: "rRot"; to: 0; duration: 380; easing.type: Easing.OutBack; easing.overshoot: 1.0 }
            SequentialAnimation { PauseAnimation { duration: 80 } NumberAnimation { target: rx.c; property: "smile"; to: 0; duration: 320; easing.type: Easing.InOutSine } }
        }
    }
    // ---------- mareo (más corto y suave) ----------
    SequentialAnimation {
        id: dizzy
        NumberAnimation { target: rx.c; property: "roll"; from: 0; to: 360; duration: 620; easing.type: Easing.InOutCubic }
        PropertyAction { target: rx.c; property: "roll"; value: 0 }
        ParallelAnimation {
            NumberAnimation { target: rx.c; property: "wobble"; to: 0.28; duration: 200; easing.type: Easing.OutCubic }
            NumberAnimation { target: rx.c; property: "wobblePh"; from: 0; to: Math.PI * 4; duration: 1200; easing.type: Easing.OutSine }
            SequentialAnimation {
                NumberAnimation { target: rx.c; property: "rRot"; to: 6; duration: 320; easing.type: Easing.InOutSine }
                NumberAnimation { target: rx.c; property: "rRot"; to: -4; duration: 400; easing.type: Easing.InOutSine }
                NumberAnimation { target: rx.c; property: "rRot"; to: 0; duration: 420; easing.type: Easing.InOutSine }
            }
            SequentialAnimation { PauseAnimation { duration: 800 } NumberAnimation { target: rx.c; property: "wobble"; to: 0; duration: 400; easing.type: Easing.InOutSine } }
        }
    }

    // ---------- bostezo / estirarse ----------
    SequentialAnimation {
        id: yawn
        ParallelAnimation {
            NumberAnimation { target: rx.c; property: "half"; to: 0.45; duration: 500; easing.type: Easing.InOutSine }
            Squash { who: rx.c; sx: 0.94; sy: 1.07; toY: -rx.s * 0.02; ms: 760; ease: Easing.InOutSine }
            NumberAnimation { target: rx.c; property: "lookOverride"; to: 1; duration: 420; easing.type: Easing.InOutSine }
            NumberAnimation { target: rx.c; property: "oY"; to: -0.45; duration: 760; easing.type: Easing.InOutSine }
        }
        PauseAnimation { duration: 380 }
        ParallelAnimation {
            Squash { who: rx.c; sx: 1.05; sy: 0.95; toY: 0; ms: 300; ease: Easing.InOutSine }
            NumberAnimation { target: rx.c; property: "oY"; to: 0.15; duration: 360; easing.type: Easing.InOutSine }
        }
        ParallelAnimation {
            Squash { who: rx.c; sx: 1; sy: 1; ms: 420; ease: Easing.OutBack }
            NumberAnimation { target: rx.c; property: "half"; to: 1; duration: 640; easing.type: Easing.InOutSine }
            NumberAnimation { target: rx.c; property: "lookOverride"; to: 0; duration: 640; easing.type: Easing.InOutSine }
        }
    }

    // ---------- curioso: inclina la cabeza y mira a un costado ----------
    SequentialAnimation {
        id: curious
        property real side: 1
        ScriptAction { script: curious.side = Math.random() < 0.5 ? -1 : 1 }
        ParallelAnimation {
            NumberAnimation { target: rx.c; property: "rRot"; to: 9 * curious.side; duration: 460; easing.type: Easing.OutBack; easing.overshoot: 1.0 }
            NumberAnimation { target: rx.c; property: "rX"; to: rx.s * 0.03 * curious.side; duration: 460; easing.type: Easing.OutCubic }
            NumberAnimation { target: rx.c; property: "lookOverride"; to: 1; duration: 300; easing.type: Easing.OutCubic }
            NumberAnimation { target: rx.c; property: "oX"; to: 0.85 * curious.side; duration: 420; easing.type: Easing.OutCubic }
            NumberAnimation { target: rx.c; property: "oY"; to: -0.15; duration: 420; easing.type: Easing.OutCubic }
            NumberAnimation { target: rx.c; property: "eyeHMul"; to: 1.06; duration: 360; easing.type: Easing.OutCubic }
        }
        PauseAnimation { duration: 950 }
        ParallelAnimation {
            NumberAnimation { target: rx.c; property: "rRot"; to: 0; duration: 480; easing.type: Easing.OutBack; easing.overshoot: 1.0 }
            NumberAnimation { target: rx.c; property: "rX"; to: 0; duration: 480; easing.type: Easing.InOutSine }
            NumberAnimation { target: rx.c; property: "lookOverride"; to: 0; duration: 480; easing.type: Easing.InOutSine }
            NumberAnimation { target: rx.c; property: "eyeHMul"; to: 1; duration: 360; easing.type: Easing.InOutSine }
        }
    }

    // ---------- saludo (al abrir): saltito con sonrisa y un "sí" de cabeza ----------
    SequentialAnimation {
        id: greet
        Squash { who: rx.c; sx: 1.05; sy: 0.95; ms: 110; ease: Easing.OutCubic }
        ParallelAnimation {
            NumberAnimation { target: rx.c; property: "smile"; to: 1; duration: 220; easing.type: Easing.OutCubic }
            Squash { who: rx.c; sx: 0.97; sy: 1.04; toY: -rx.s * 0.1; ms: 220; ease: Easing.OutCubic }
        }
        ParallelAnimation {
            Squash { who: rx.c; sx: 1; sy: 1; toY: 0; ms: 300; ease: Easing.OutBack }
            SequentialAnimation {
                NumberAnimation { target: rx.c; property: "rRot"; to: 6; duration: 180; easing.type: Easing.InOutSine }
                NumberAnimation { target: rx.c; property: "rRot"; to: -4; duration: 220; easing.type: Easing.InOutSine }
                NumberAnimation { target: rx.c; property: "rRot"; to: 0; duration: 260; easing.type: Easing.OutBack; easing.overshoot: 1.0 }
            }
        }
        PauseAnimation { duration: 240 }
        NumberAnimation { target: rx.c; property: "smile"; to: 0; duration: 320; easing.type: Easing.InOutSine }
    }

    // ---------- rebote feliz (al abrir): dos rebotes que se amortiguan ----------
    SequentialAnimation {
        id: happyBounce
        ParallelAnimation {
            NumberAnimation { target: rx.c; property: "smile"; to: 1; duration: 180; easing.type: Easing.OutCubic }
            Squash { who: rx.c; sx: 1.06; sy: 0.94; ms: 110; ease: Easing.OutCubic }
        }
        Squash { who: rx.c; sx: 0.96; sy: 1.05; toY: -rx.s * 0.14; ms: 180; ease: Easing.OutCubic }
        Squash { who: rx.c; sx: 1; sy: 1; toY: 0; ms: 150; ease: Easing.InQuad }
        Squash { who: rx.c; sx: 1.04; sy: 0.96; ms: 70; ease: Easing.OutQuad }
        Squash { who: rx.c; sx: 0.98; sy: 1.02; toY: -rx.s * 0.07; ms: 150; ease: Easing.OutCubic }
        Squash { who: rx.c; sx: 1; sy: 1; toY: 0; ms: 130; ease: Easing.InQuad }
        Squash { who: rx.c; sx: 1; sy: 1; ms: 220; ease: Easing.OutBack }
        NumberAnimation { target: rx.c; property: "smile"; to: 0; duration: 300; easing.type: Easing.InOutSine }
    }

    // ---------- sobresalto (mouse muy rápido) ----------
    SequentialAnimation {
        id: startled
        ParallelAnimation {
            NumberAnimation { target: rx.c; property: "eyeHMul"; to: 1.14; duration: 100; easing.type: Easing.OutCubic }
            NumberAnimation { target: rx.c; property: "eyeWMul"; to: 1.12; duration: 100; easing.type: Easing.OutCubic }
            Squash { who: rx.c; sx: 0.96; sy: 1.04; toY: -rx.s * 0.06; ms: 120; ease: Easing.OutCubic }
        }
        Squash { who: rx.c; sx: 1; sy: 1; toY: 0; ms: 260; ease: Easing.OutBack }
        ParallelAnimation {
            NumberAnimation { target: rx.c; property: "eyeHMul"; to: 1; duration: 320; easing.type: Easing.InOutSine }
            NumberAnimation { target: rx.c; property: "eyeWMul"; to: 1; duration: 320; easing.type: Easing.InOutSine }
        }
    }

    // ---------- mascota: comer y jugar (sin saltos ni giros; ojos siempre pastillas) ----------
    // Masticar: mira hacia abajo, entrecierra los ojos con gusto y el cuerpo "mastica"
    // con squash & stretch rítmico (5 bocados); al final, satisfecho.
    SequentialAnimation {
        id: chew
        ParallelAnimation {
            NumberAnimation { target: rx.c; property: "lookOverride"; to: 1; duration: 200; easing.type: Easing.OutCubic }
            NumberAnimation { target: rx.c; property: "oY"; to: 0.55; duration: 240; easing.type: Easing.OutCubic }
            NumberAnimation { target: rx.c; property: "half"; to: 0.6; duration: 240; easing.type: Easing.OutCubic }
            NumberAnimation { target: rx.c; property: "rY"; to: rx.s * 0.02; duration: 240; easing.type: Easing.OutCubic }
        }
        SequentialAnimation {        // 5 bocados
            loops: 5
            Squash { who: rx.c; sx: 1.05; sy: 0.95; ms: 130; ease: Easing.OutQuad }
            Squash { who: rx.c; sx: 0.98; sy: 1.02; ms: 150; ease: Easing.InOutSine }
        }
        ParallelAnimation {
            Squash { who: rx.c; sx: 1; sy: 1; ms: 220; ease: Easing.OutBack }
            NumberAnimation { target: rx.c; property: "oY"; to: 0; duration: 280; easing.type: Easing.InOutSine }
            NumberAnimation { target: rx.c; property: "rY"; to: 0; duration: 280; easing.type: Easing.OutCubic }
            NumberAnimation { target: rx.c; property: "half"; to: 1; duration: 280; easing.type: Easing.InOutSine }
            NumberAnimation { target: rx.c; property: "smile"; to: 1; duration: 260; easing.type: Easing.OutCubic }
        }
        PauseAnimation { duration: 420 }
        ParallelAnimation {
            NumberAnimation { target: rx.c; property: "smile"; to: 0; duration: 320; easing.type: Easing.InOutSine }
            NumberAnimation { target: rx.c; property: "lookOverride"; to: 0; duration: 320; easing.type: Easing.InOutSine }
        }
    }
    // Vaivén: se inclina a un lado y al otro siguiendo algo con la mirada.
    SequentialAnimation {
        id: sway
        ParallelAnimation {
            NumberAnimation { target: rx.c; property: "lookOverride"; to: 1; duration: 200; easing.type: Easing.OutCubic }
            NumberAnimation { target: rx.c; property: "smile"; to: 0.8; duration: 240; easing.type: Easing.OutCubic }
            NumberAnimation { target: rx.c; property: "rRot"; to: -7; duration: 320; easing.type: Easing.InOutSine }
            NumberAnimation { target: rx.c; property: "oX"; to: -0.7; duration: 320; easing.type: Easing.InOutSine }
        }
        ParallelAnimation {
            NumberAnimation { target: rx.c; property: "rRot"; to: 7; duration: 520; easing.type: Easing.InOutSine }
            NumberAnimation { target: rx.c; property: "oX"; to: 0.7; duration: 520; easing.type: Easing.InOutSine }
        }
        ParallelAnimation {
            NumberAnimation { target: rx.c; property: "rRot"; to: -4; duration: 460; easing.type: Easing.InOutSine }
            NumberAnimation { target: rx.c; property: "oX"; to: -0.4; duration: 460; easing.type: Easing.InOutSine }
        }
        ParallelAnimation {
            NumberAnimation { target: rx.c; property: "rRot"; to: 0; duration: 420; easing.type: Easing.OutBack; easing.overshoot: 1.0 }
            NumberAnimation { target: rx.c; property: "oX"; to: 0; duration: 420; easing.type: Easing.InOutSine }
            SequentialAnimation { PauseAnimation { duration: 200 } NumberAnimation { target: rx.c; property: "smile"; to: 0; duration: 300; easing.type: Easing.InOutSine } }
            SequentialAnimation { PauseAnimation { duration: 200 } NumberAnimation { target: rx.c; property: "lookOverride"; to: 0; duration: 300 } }
        }
    }
    // Contoneo: estremecimiento alegre rápido (squash alternado, sin despegar del suelo).
    SequentialAnimation {
        id: wiggle
        NumberAnimation { target: rx.c; property: "smile"; to: 1; duration: 160; easing.type: Easing.OutCubic }
        SequentialAnimation {
            loops: 4
            Squash { who: rx.c; sx: 1.06; sy: 0.94; ms: 90; ease: Easing.OutQuad }
            Squash { who: rx.c; sx: 0.95; sy: 1.05; ms: 90; ease: Easing.OutQuad }
        }
        Squash { who: rx.c; sx: 1; sy: 1; ms: 260; ease: Easing.OutBack }
        NumberAnimation { target: rx.c; property: "smile"; to: 0; duration: 320; easing.type: Easing.InOutSine }
    }
    // Escondidas: cierra los ojos, espera y los abre grandes con alegría.
    SequentialAnimation {
        id: peekaboo
        ParallelAnimation {
            NumberAnimation { target: rx.c; properties: "openL,openR"; to: 0.08; duration: 180; easing.type: Easing.InCubic }
            NumberAnimation { target: rx.c; property: "rScale"; to: 0.95; duration: 220; easing.type: Easing.OutCubic }
        }
        PauseAnimation { duration: 520 }
        ParallelAnimation {
            NumberAnimation { target: rx.c; properties: "openL,openR"; to: 1; duration: 160; easing.type: Easing.OutCubic }
            NumberAnimation { target: rx.c; property: "eyeHMul"; to: 1.15; duration: 160; easing.type: Easing.OutCubic }
            NumberAnimation { target: rx.c; property: "rScale"; to: 1.04; duration: 200; easing.type: Easing.OutBack; easing.overshoot: 1.0 }
            NumberAnimation { target: rx.c; property: "smile"; to: 1; duration: 200; easing.type: Easing.OutCubic }
        }
        PauseAnimation { duration: 360 }
        ParallelAnimation {
            NumberAnimation { target: rx.c; property: "eyeHMul"; to: 1; duration: 320; easing.type: Easing.InOutSine }
            NumberAnimation { target: rx.c; property: "rScale"; to: 1; duration: 320; easing.type: Easing.InOutSine }
            NumberAnimation { target: rx.c; property: "smile"; to: 0; duration: 360; easing.type: Easing.InOutSine }
        }
    }
}
