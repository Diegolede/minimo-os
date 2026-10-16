// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Diego Ledesma (TRN1) — Minimo OS
import QtQuick
import QtQuick.Effects
import "../Common"

// Personaje de Minimo OS (v2, según reference2): esfera negra mate con dos ojos
// pastilla blancos, PARALELOS. La "cara" (el par de ojos) se desliza por la
// superficie de la esfera hacia donde mira, con proyección esférica: cerca del borde
// los ojos se acortan en la dirección radial y el par se inclina en las diagonales.
// Además: parpadeo, respiración, trucos espontáneos, giro al abrir/cerrar, baile con
// música (cava) y modo dormir por inactividad. Ojos SIEMPRE pastilla.
// Prioridad de estados: dormir > ánimo > baile > truco > reposo.
Item {
    id: c
    property int size: 22
    property bool active: true          // anima solo si está visible
    width: size; height: size

    readonly property real s: size
    readonly property real r: size / 2

    // ===== Mirada =====
    // look: vector en el disco unidad (0,0 = te mira de frente; |look| = 1 = máximo giro).
    property real lookX: 0
    property real lookY: 0
    readonly property bool tracking: Cursor.ok && Cursor.x >= 0
    // Sigue el mouse solo si está visible y despierto (dormido no consulta el cursor).
    readonly property bool followsMouse: active && !asleep
    onFollowsMouseChanged: followsMouse ? Cursor.acquire() : Cursor.release()
    Component.onCompleted: if (followsMouse) Cursor.acquire()
    Component.onDestruction: { if (followsMouse) Cursor.release(); if (dancing) Media.release() }

    property real idleX: 0
    property real idleY: 0

    function updateLook() {
        if (!active) return
        if (asleep) { lookX = 0; lookY = 0.75; return }
        const idle = !tracking || Date.now() - Cursor.lastMove > 4000
        if (idle) { lookX = idleX; lookY = idleY; return }
        const win = c.Window.window
        const p = c.mapToItem(null, width / 2, height / 2)
        const sx = (win && win.screen && win.screen.x !== undefined) ? win.screen.x : 0
        const sy = (win && win.screen && win.screen.y !== undefined) ? win.screen.y : 0      // QScreen (sin Quickshell) no tiene x/y
        const dx = Cursor.x - (sx + p.x), dy = Cursor.y - (sy + p.y)
        // Escala anisotrópica: la isla está pegada al borde superior, así que hacia
        // arriba hay poco recorrido; se normaliza con la distancia al borde.
        const nx = dx / 320
        const ny = dy < 0 ? dy / Math.max(24, sy + p.y) : dy / 320
        const m = Math.sqrt(nx * nx + ny * ny)
        const k = m > 1 ? 1 / m : 1             // cerca = te mira de frente
        lookX = nx * k; lookY = ny * k
    }
    Connections {
        target: Cursor
        function onXChanged() { c.cursorMoved() }
        function onYChanged() { c.cursorMoved() }
    }
    // Velocidad del mouse: si se mueve muy rápido, sobresalto (con enfriamiento).
    property real _px: -1
    property real _py: -1
    property real _pt: 0
    property real _lastStartle: 0
    function cursorMoved() {
        updateLook()
        const now = Date.now()
        if (_pt > 0 && now - _pt < 200) {
            const d = Math.hypot(Cursor.x - _px, Cursor.y - _py)
            const v = d / Math.max(16, now - _pt) * 1000          // px/s
            if (v > 4500 && now - _lastStartle > 5000 && !reactions.busy && active && !dancing) {
                _lastStartle = now; reactions.play("startled")
            }
        }
        _px = Cursor.x; _py = Cursor.y; _pt = now
    }

    Timer {
        // mirada distraída ocasional cuando el mouse está quieto (despierto)
        running: c.active && !c.asleep; repeat: true; interval: 3000
        onTriggered: {
            interval = 2500 + Math.random() * 2500
            if (Math.random() < 0.5) { const t = Math.random() * Math.PI * 2, m = 0.25 + Math.random() * 0.4; c.idleX = Math.cos(t) * m; c.idleY = Math.sin(t) * m }
            else { c.idleX = 0; c.idleY = 0 }
            c.updateLook()
        }
    }

    // Mirada suavizada con resorte (más lenta al dormirse).
    property real eyeX: lookX
    property real eyeY: lookY
    // Mirada efectiva: seguimiento del mouse mezclado con la de la reacción (override)
    // y un bamboleo circular opcional (mareo).
    readonly property real bX: eyeX * (1 - lookOverride) + oX * lookOverride + wobble * Math.cos(wobblePh)
    readonly property real bY: eyeY * (1 - lookOverride) + oY * lookOverride + wobble * Math.sin(wobblePh)
    // Mirada forzada desde afuera (ipc "character look"), independiente de las reacciones.
    property real gX: 0
    property real gY: 0
    property real gOn: 0
    Behavior on gOn { NumberAnimation { duration: 250 } }
    readonly property real fX: bX * (1 - gOn) + gX * gOn
    readonly property real fY: bY * (1 - gOn) + gY * gOn + 0.3 * squint
    // Resorte casi crítico: sacada rápida con un overshoot mínimo, sin temblor.
    Behavior on eyeX { SpringAnimation { spring: c.asleep ? 0.8 : 2.8; damping: c.asleep ? 0.95 : 0.5; epsilon: 0.002 } }
    Behavior on eyeY { SpringAnimation { spring: c.asleep ? 0.8 : 2.8; damping: c.asleep ? 0.95 : 0.5; epsilon: 0.002 } }

    // ===== Geometría de la cara (proyección esférica) =====
    // Medidas tomadas de reference2 (esfera de diámetro D): ojo 0.149D x 0.3375D,
    // separación entre centros 0.30D; desplazamiento máximo ≈ 0.62R.
    readonly property real eyeW: s * 0.149
    readonly property real eyeH: s * 0.3375
    readonly property real eyeSep: s * 0.149        // medio desplazamiento entre centros
    // Proyección esférica: la mirada se traduce en yaw/pitch de la cabeza. Cada ojo
    // es un punto sobre la esfera (yaw ± separación angular); su posición en pantalla
    // es R·sin(ángulo) — se mueve menos cerca del borde — y se escorza con cos(yaw)
    // en ancho y cos(pitch) en alto. El ojo más cercano al borde se comprime más y,
    // si pasa la silueta, queda recortado por la máscara circular de la cara.
    readonly property real lookLen: Math.sqrt(fX * fX + fY * fY)
    readonly property real gk: lookLen > 1 ? 1 / lookLen : 1          // limitar al disco unidad
    readonly property real yaw: fX * gk * 0.80                        // rad (máx ≈ 46°)
    readonly property real pitch: fY * gk * (fY > 0 ? 0.66 : 0.6)     // arriba hay menos lugar (isla)
    readonly property real eyeAng: Math.asin(Math.min(0.9, eyeSep / r))   // separación angular de cada ojo
    readonly property real sinP: Math.sin(pitch)
    readonly property real cosP: Math.cos(pitch)
    // Leve rotación siguiendo la curvatura en diagonales ("//" mirando arriba-izquierda).
    readonly property real tilt: Math.max(-30, Math.min(30, 120 * Math.sin(yaw) * sinP))

    // ===== Estados: parpadeo, dormir, baile =====
    property real blink: 1
    // Parpadeo natural: ~140 ms (cierre rápido, apertura más lenta), cada 3–6 s,
    // a veces doble.
    property bool doubleBlink: false
    SequentialAnimation {
        id: blinkAnim
        NumberAnimation { target: c; property: "blink"; to: 0.06; duration: c.petting ? 260 : 55; easing.type: c.petting ? Easing.InOutSine : Easing.InQuad }
        PauseAnimation { duration: c.petting ? 180 : 25 }
        NumberAnimation { target: c; property: "blink"; to: 1; duration: c.petting ? 420 : 80; easing.type: c.petting ? Easing.InOutSine : Easing.OutCubic }
        PauseAnimation { duration: c.doubleBlink ? 90 : 0 }
        NumberAnimation { target: c; property: "blink"; to: c.doubleBlink ? 0.06 : 1; duration: c.doubleBlink ? 55 : 0; easing.type: Easing.InQuad }
        NumberAnimation { target: c; property: "blink"; to: 1; duration: c.doubleBlink ? 85 : 0; easing.type: Easing.OutCubic }
    }
    function doBlink(twice) { doubleBlink = twice; blinkAnim.restart() }
    Timer {
        running: c.active && !c.asleep; repeat: true
        interval: 3500
        onTriggered: { interval = 3000 + Math.random() * 3000; c.doBlink(Math.random() < 0.15) }
    }

    // Dormir: cuando toda la PC está inactiva (IdleState, ext-idle-notify), salvo si
    // suena música (baila) o se está grabando. Al volver la actividad: estira y parpadea.
    readonly property bool asleep: IdleState.sleeping && !Media.playing && !Recorder.recording
    property real sleepy: asleep ? 1 : 0
    // Se duerme despacio (2.4 s); al despertar abre los ojos con suavidad (0.7 s).
    Behavior on sleepy { NumberAnimation { duration: c.asleep ? 2400 : 700; easing.type: c.asleep ? Easing.InOutSine : Easing.OutCubic } }
    onAsleepChanged: { updateLook(); if (asleep) { reactions.calm(); petting = false } else if (active) wakeAnim.restart() }
    function wake() { IdleState.wake() }
    readonly property bool dancing: active && Media.playing
    onDancingChanged: { dancing ? Media.acquire() : Media.release(); if (dancing) reactions.calm() }
    readonly property real amp: Media.hasLevel ? 0.35 + Math.min(1, Media.level * 1.6) : 1
    property real beat: 0
    property real sway: 0
    NumberAnimation on beat { running: c.dancing; loops: Animation.Infinite; from: 0; to: 1; duration: 500 }
    NumberAnimation on sway { running: c.dancing; loops: Animation.Infinite; from: 0; to: 1; duration: 1000 }
    // Baile contenido: un ánimo (preocupado/cansado) tiene prioridad sobre el baile.
    property real danceOn: dancing && mood === "" ? 1 : 0
    Behavior on danceOn { NumberAnimation { duration: 400; easing.type: Easing.InOutSine } }
    readonly property real hopT: Math.sin(Math.PI * beat)
    readonly property real danceAmp: Math.min(1, amp) * danceOn
    readonly property real danceY: -hopT * s * 0.08 * danceAmp
    readonly property real danceSy: 1 + danceAmp * (0.03 * hopT - 0.05 * Math.pow(1 - hopT, 3))
    readonly property real danceSx: 1 + danceAmp * (0.05 * Math.pow(1 - hopT, 3) - 0.02 * hopT)
    readonly property real danceRot: danceAmp * 4 * Math.sin(2 * Math.PI * sway)

    // Apertura final de los ojos (1 = abiertos; dormido = pastilla fina).
    readonly property real openness: (1 - 0.8 * squint) * blink * half * (1 - 0.9 * sleepy) * (1 - 0.4 * tired) * (1 - 0.62 * petK)
    // Alegría con pastillas: más bajas y elevadas (mejillas que suben). Bailando, leve.
    readonly property real joy: Math.max(smile, 0.45 * danceOn, 0.8 * petK) * (1 - sleepy)

    // ===== Reacciones (ver Reactions.qml) =====
    function opened() { if (active) { reactions.resetClicks(); reactions.playOpen() } }
    function hop() { if (active && !asleep && !reactions.busy) reactions.play("hop") }
    function react(name) { if (active && !asleep) reactions.play(name) }
    function playGame() { if (active && !asleep) reactions.playGame() }
    // Clics: dormido → despierta suave. 1 clic → reacción. ≥4 clics en 1,5 s → caricias.
    // `side` (-1..1): dónde cayó el clic respecto del centro (para acurrucarse hacia ahí).
    property var clickTimes: []
    function clicked(side) {
        if (!active) return
        if (asleep) { wake(); clickTimes = []; return }
        const now = Date.now()
        clickTimes = clickTimes.filter(t => now - t < 1500).concat([now])
        if (petting || clickTimes.length >= 4) pet(side)
        else if (clickTimes.length === 1) reactions.playClick()
    }

    // ===== Caricias =====
    // Se acurruca hacia la mano (inclinación 6–9° + leve corrimiento, frotando lento),
    // ojos de felicidad (pastillas finas ~25 %, algo elevadas, parpadeos lentos), un
    // "puff" al empezar, saltitos con cada ráfaga de corazones y un suspiro al terminar.
    // Prioridad: debajo de dormir, encima de los trucos.
    property bool petting: false
    property real petSide: 1
    property real petK: petting ? 1 : 0
    Behavior on petK { NumberAnimation { duration: c.petting ? 700 : 420; easing.type: Easing.InOutSine } }
    property real petLean: 6          // 6..9° (frotarse)
    property real petPuff: 1
    property real petHopY: 0
    function pet(side) {
        if (!active || asleep) return
        if (side !== undefined && side !== null && Math.abs(side) > 0.05) petSide = side > 0 ? 1 : -1
        if (!petting) {
            if (side === undefined || side === null) petSide = Math.random() < 0.5 ? -1 : 1
            reactions.calm(); petting = true; puffAnim.restart()
        }
        petEnd.restart()
        if (!petHop.running) petHop.restart()
        const n = 2 + (Math.random() < 0.5 ? 1 : 0)
        for (let i = 0; i < n; i++) spawnHeart(i * 90)
    }
    Timer { id: petEnd; interval: 1700; onTriggered: { c.petting = false; sighAnim.restart() } }
    SequentialAnimation {           // frotarse: vaivén lento hacia el lado de la mano
        running: c.petK > 0.01 && c.active
        loops: Animation.Infinite
        NumberAnimation { target: c; property: "petLean"; to: 9; duration: 900; easing.type: Easing.InOutSine }
        NumberAnimation { target: c; property: "petLean"; to: 6; duration: 900; easing.type: Easing.InOutSine }
    }
    SequentialAnimation {           // "puff" de alegría al empezar
        id: puffAnim
        NumberAnimation { target: c; property: "petPuff"; to: 1.04; duration: 220; easing.type: Easing.OutCubic }
        NumberAnimation { target: c; property: "petPuff"; to: 1.0; duration: 460; easing.type: Easing.OutBack; easing.overshoot: 1.2 }
    }
    SequentialAnimation {           // saltitos felices con cada ráfaga
        id: petHop
        NumberAnimation { target: c; property: "petHopY"; to: -c.s * 0.06; duration: 150; easing.type: Easing.OutCubic }
        NumberAnimation { target: c; property: "petHopY"; to: 0; duration: 150; easing.type: Easing.InQuad }
        NumberAnimation { target: c; property: "petHopY"; to: -c.s * 0.035; duration: 120; easing.type: Easing.OutCubic }
        NumberAnimation { target: c; property: "petHopY"; to: 0; duration: 130; easing.type: Easing.InQuad }
    }
    SequentialAnimation {           // suspiro satisfecho al terminar + apertura con doble parpadeo
        id: sighAnim
        Squash { who: c; sx: 1.04; sy: 0.96; ms: 320; ease: Easing.InOutSine }
        Squash { who: c; sx: 1; sy: 1; ms: 460; ease: Easing.OutBack }
        ScriptAction { script: if (!c.asleep) c.doBlink(true) }
    }
    Component { id: heartComp; Heart {} }
    function spawnHeart(delay) {
        if (CharacterBus.hearts >= 24) return      // tope global de partículas
        // Los corazones van a la raíz de la ventana: no los recorta la tarjeta (clip).
        const win = c.Window.window
        const host = win && win.contentItem ? win.contentItem : c
        const p = c.mapToItem(host, c.width / 2, c.height * 0.2)
        const hs = Math.max(7, c.s * (0.16 + Math.random() * 0.16))
        heartComp.createObject(host, {
            size: hs, x: p.x - hs / 2 + (Math.random() - 0.5) * c.s * 0.5, y: p.y - hs / 2,
            rise: c.s * (0.7 + Math.random() * 0.5), drift: (Math.random() - 0.5) * c.s * 0.7,
            delay: delay || 0, z: 1000 })
    }

    // Propiedades que animan las reacciones (valores neutros).
    property real roll: 0          // giro de la cara
    property real bounceY: 0
    property real squashX: 1
    property real squashY: 1
    property real breath: 1
    property real rScale: 1        // escala de todo el cuerpo
    property real rX: 0            // desplazamiento del cuerpo
    property real rY: 0
    property real rRot: 0          // inclinación/giro del cuerpo
    property real lookOverride: 0  // 0 = mouse, 1 = mirada de la reacción (oX, oY)
    property real oX: 0
    property real oY: 0
    property real eyeHMul: 1       // ojos más altos/anchos (sorpresa)
    property real eyeWMul: 1
    property real openL: 1         // apertura por ojo (guiño)
    property real openR: 1
    property real smile: 0         // alegría (0..1): pastillas algo más bajas y elevadas
    property real wobble: 0        // radio del bamboleo de la mirada (mareo)
    property real wobblePh: 0
    property real half: 1          // ojos entrecerrados (bostezo)
    // Comer (solo los usa la reacción "chew"; en reposo todo vale 0 y no se dibuja nada):
    property real cheek: 0         // cachetes llenos (0..1): sobresalen de la silueta abajo a los lados
    property real cheekLR: 0       // alternancia izquierda/derecha al masticar (-1..1)
    property real cheekSq: 0       // aplastado vertical de los cachetes en cada mordisco (0..1)
    property real foodT: 0         // bocado: 0 = abajo al frente, 1 = dentro del cuerpo
    property real foodK: 0         // tamaño del bocado (0 = no hay)
    // punto donde entra el bocado: parte baja del cuerpo, al frente (sin boca)
    readonly property real biteX: r
    readonly property real biteY: s * 0.86

    // ===== Ánimo (lo fija quien usa el personaje, p. ej. el panel de estado) =====
    // "" = normal/feliz · "worried" = preocupado (ojos más chicos e inclinados, sacudón)
    // · "tired" = cansado/exigido (ojos entrecerrados, inclinado).
    property string mood: ""
    property real worry: active && !asleep && mood === "worried" ? 1 : 0
    property real tired: active && !asleep && mood === "tired" ? 1 : 0
    Behavior on worry { NumberAnimation { duration: 500; easing.type: Easing.InOutSine } }
    onMoodChanged: if (mood !== "") reactions.calm()
    Behavior on tired { NumberAnimation { duration: 600; easing.type: Easing.InOutSine } }
    property real moodShake: 0
    SequentialAnimation {
        running: c.active && !c.asleep && c.mood === "worried"
        loops: Animation.Infinite
        PauseAnimation { duration: 2200 }
        NumberAnimation { target: c; property: "moodShake"; to: 3; duration: 90; easing.type: Easing.OutCubic }
        NumberAnimation { target: c; property: "moodShake"; to: -2.5; duration: 120; easing.type: Easing.InOutSine }
        NumberAnimation { target: c; property: "moodShake"; to: 1.2; duration: 110; easing.type: Easing.InOutSine }
        NumberAnimation { target: c; property: "moodShake"; to: 0; duration: 140; easing.type: Easing.OutCubic }
        onStopped: c.moodShake = 0
    }

    Reactions { id: reactions; c: c }

    // ===== Entrecerrar al escribir (campos del shell) =====
    // Ojos como guion "-": ~20 % de alto, 115 % de ancho, extremos redondos; mirada apenas abajo.
    property real squint: 0
    // Velocidad constante (independiente de los fps): teclas rápidas no reinician la animación.
    Behavior on squint { SmoothedAnimation { velocity: 3.5 } }
    Timer { id: squintRelax; interval: 600; onTriggered: c.squint = 0 }
    Connections {
        target: CharacterBus
        function onTyped() { if (c.active && !c.asleep) { c.squint = 1; squintRelax.interval = 600; squintRelax.restart() } }
        function onTypingStopped() { squintRelax.stop(); c.squint = 0 }
        function onSquintFor(ms) {
            if (!c.active || c.asleep) return
            console.info("minimo: squint", ms, "ms (personaje de", c.size, "px)")
            c.squint = 1; squintRelax.interval = ms; squintRelax.restart()
        }
    }
    // Salto hacia atrás juguetón cuando llega una notificación (si se ve y está despierto).
    Connections {
        target: Notifs
        function onCurrentChanged() { if (Notifs.current !== null) c.react("curious") }
    }

    // Pose estática natural al pausar (animaciones apagadas, oculto): de frente, ojos
    // abiertos y centrados, sin quedar a mitad de parpadeo, mirada o reacción.
    onActiveChanged: { if (!active) toRest(); else reactions.resetClicks() }
    function toRest() {
        blinkAnim.stop(); petHop.stop(); puffAnim.stop(); petEnd.stop()
        petting = false; clickTimes = []
        squintRelax.stop(); squint = 0
        idleX = 0; idleY = 0; lookX = 0; lookY = asleep ? 0.75 : 0; gOn = 0
        reactions.rest()
        restAnim.restart()
    }
    ParallelAnimation {
        id: restAnim
        NumberAnimation { target: c; property: "blink"; to: 1; duration: 220; easing.type: Easing.OutCubic }
        NumberAnimation { target: c; property: "petHopY"; to: 0; duration: 260; easing.type: Easing.OutCubic }
        NumberAnimation { target: c; property: "petPuff"; to: 1; duration: 260; easing.type: Easing.OutCubic }
        NumberAnimation { target: c; property: "petLean"; to: 6; duration: 260; easing.type: Easing.OutCubic }
        NumberAnimation { target: c; property: "moodShake"; to: 0; duration: 200; easing.type: Easing.OutCubic }
    }
    NumberAnimation { id: breathRest; target: c; property: "breath"; to: 1; duration: 600; easing.type: Easing.InOutSine }

    Connections {
        target: CharacterBus
        function onReact(name) { c.react(name) }
        function onPet() { c.pet() }
        function onGaze(x, y, ms) { if (!c.active) return; c.gX = x; c.gY = y; c.gOn = 1; gazeHold.interval = ms; gazeHold.restart() }
    }

    Timer {
        // truco espontáneo cada 45–120 s (despierto, visible, sin música ni ánimo)
        running: c.active && !c.asleep && !c.dancing && !c.petting && c.mood === ""; repeat: true
        interval: 60000
        onTriggered: {
            interval = 45000 + Math.random() * 75000
            if (!reactions.busy) reactions.playRandom(Date.now() - Cursor.lastMove)
        }
    }
    Timer { id: gazeHold; onTriggered: c.gOn = 0 }
    SequentialAnimation {
        // al despertar: estiramiento leve mientras abre los ojos y un parpadeo doble suave
        id: wakeAnim
        Squash { who: c; sx: 0.96; sy: 1.04; toY: -c.s * 0.02; ms: 420; ease: Easing.InOutSine }
        Squash { who: c; sx: 1; sy: 1; toY: 0; ms: 380; ease: Easing.OutBack }
        PauseAnimation { duration: 120 }
        ScriptAction { script: c.doBlink(true) }
    }
    SequentialAnimation {
        // respiración (más lenta y profunda dormido); al detenerse vuelve suave a 1
        onStopped: breathRest.restart()
        running: c.active && !(c.asleep && IdleState.unattended); loops: Animation.Infinite
        NumberAnimation { target: c; property: "breath"; to: c.asleep ? 1.025 : 1.012; duration: c.asleep ? 3200 : 2400; easing.type: Easing.InOutSine }
        NumberAnimation { target: c; property: "breath"; to: 1.0; duration: c.asleep ? 3200 : 2400; easing.type: Easing.InOutSine }
    }

    // ===== Dibujo =====
    Item {
        id: body
        width: c.s; height: c.s
        rotation: c.danceRot + c.rRot + c.moodShake - 4 * c.tired + c.petSide * c.petLean * c.petK
        transform: [
            Scale { origin.x: c.s / 2; origin.y: c.s; xScale: c.squashX * c.breath * c.danceSx; yScale: c.squashY * c.breath * c.danceSy },
            Scale { origin.x: c.s / 2; origin.y: c.s / 2; xScale: c.rScale; yScale: c.rScale },
            Scale { origin.x: c.s / 2; origin.y: c.s; xScale: c.petPuff * (1 + 0.02 * c.petK); yScale: c.petPuff * (1 - 0.02 * c.petK) },
            Translate { x: c.rX + c.petSide * c.s * 0.045 * c.petK * (c.petLean - 5) / 4; y: c.bounceY + c.danceY + c.rY + c.petHopY }
        ]

        // Cachetes: dos círculos del mismo negro plano, escondidos dentro de la esfera en
        // reposo; al inflarse asoman por los costados de abajo (sin brillo ni sombra).
        Repeater {
            model: c.cheek > 0.001 ? [-1, 1] : []
            delegate: Rectangle {
                id: ck
                required property int modelData
                readonly property real d: c.s * 0.40
                width: d; height: d; radius: d / 2
                readonly property real k: Math.max(0, c.cheek * (1 + 0.18 * modelData * c.cheekLR))
                x: c.r + modelData * c.s * (0.27 + 0.10 * k) - d / 2
                y: c.s * 0.64 - d / 2 + c.s * 0.03 * c.cheekSq
                transform: Scale { origin.x: c.s * 0.20; origin.y: c.s * 0.20; xScale: (0.75 + 0.25 * ck.k) * (1 + 0.06 * c.cheekSq); yScale: (0.75 + 0.25 * ck.k) * (1 - 0.12 * c.cheekSq) }
                color: Theme.sphere
                antialiasing: true
            }
        }
        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: Theme.sphere
            Behavior on color { ColorAnimation { duration: 250 } }
            antialiasing: true
        }
        // Máscara circular: los ojos que pasan la silueta quedan recortados.
        Item {
            id: faceMask
            anchors.fill: parent
            visible: false
            layer.enabled: true
            layer.smooth: true
            Rectangle { anchors.fill: parent; radius: width / 2; antialiasing: true }
        }
        Item {
            anchors.fill: parent
            layer.enabled: true
            layer.effect: MultiEffect { maskEnabled: true; maskSource: faceMask; maskThresholdMin: 0.5; maskSpreadAtMin: 1.0 }

        // Cara: gira entera con los trucos (roll). Los ojos son siempre paralelos.
        Item {
            anchors.fill: parent
            rotation: c.roll
            Repeater {
                model: [-1, 1]
                delegate: Item {
                    id: eye
                    required property int modelData
                    // Punto del ojo sobre la esfera.
                    readonly property real yw: c.yaw + modelData * c.eyeAng
                    readonly property real cosY: Math.cos(yw)
                    readonly property real px: c.r * Math.sin(yw) * c.cosP
                    readonly property real py: c.r * c.sinP
                    // giro del par por `tilt` alrededor del centro de la cara
                    readonly property real t: c.tilt * Math.PI / 180
                    readonly property real fcx: c.r * Math.sin(c.yaw) * c.cosP     // centro de la cara
                    readonly property real dx: px - fcx
                    readonly property real cx: c.r + fcx + dx * Math.cos(t)
                    readonly property real cy: c.r + py + dx * Math.sin(t)
                    // escorzo (pastilla siempre): ancho por cos(yaw) del ojo, alto por cos(pitch)
                    readonly property real kB: Math.max(0.12, cosY)
                    readonly property real kA: Math.max(0.2, c.cosP)
                    readonly property real own: modelData < 0 ? c.openL : c.openR
                    readonly property real w: c.eyeW * kB * c.eyeWMul * (1 - 0.12 * c.worry) * (1 + 0.15 * c.squint)
                    opacity: cosY > 0 ? 1 : 0
                    x: cx; y: cy
                    rotation: c.tilt - modelData * 14 * c.worry

                    // Ojo pastilla.
                    Rectangle {
                        width: eye.w
                        height: Math.max(width * 0.35, c.eyeH * eye.kA * c.eyeHMul * c.openness * eye.own * (1 - 0.25 * c.worry) * (1 - 0.28 * c.joy))
                        radius: Math.min(width, height) / 2
                        x: -width / 2; y: -height / 2 - c.eyeH * 0.12 * c.joy
                        color: Theme.eye
                        Behavior on color { ColorAnimation { duration: 250 } }
                        antialiasing: true
                    }
                }
            }
        }
        }
        // Bocado: sube desde abajo y se funde en la parte baja del cuerpo (sin boca).
        Rectangle {
            visible: c.foodK > 0.01
            readonly property real d: c.s * 0.16 * c.foodK
            width: d; height: d; radius: d / 2
            x: c.biteX - d / 2 + (1 - c.foodT) * c.s * 0.06
            y: c.biteY - d / 2 + (1 - c.foodT) * c.s * 0.40
            color: Theme.sphere
            antialiasing: true
        }
    }
}
