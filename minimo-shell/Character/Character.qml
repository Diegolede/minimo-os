// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Diego Ledesma (TRN1) — Minimo OS
import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
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
    readonly property real bX: eyeX * (1 - vLook) + vOX * vLook + wobble * Math.cos(wobblePh) + microX
    readonly property real bY: eyeY * (1 - vLook) + vOY * vLook + wobble * Math.sin(wobblePh) + microY
    // Micro-sacadas: saltitos de ~2 % cada 1.2–3 s, rápidos (110 ms) y quietos entre medio.
    // El timer solo corre despierto y sin otra animación grande; no hay trabajo continuo.
    property real microX: 0
    property real microY: 0
    Behavior on microX { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }
    Behavior on microY { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }
    Timer {
        running: c.active && !c.asleep && !c.dancing && !c.petting; repeat: true; interval: 1800
        onTriggered: {
            interval = 1200 + Math.random() * 1800
            const t = Math.random() * 2 * Math.PI, m = Math.random() < 0.3 ? 0 : 0.015 + Math.random() * 0.02
            c.microX = Math.cos(t) * m; c.microY = Math.sin(t) * m * 0.7
        }
    }
    // Mirada forzada desde afuera (ipc "character look"), independiente de las reacciones.
    property real gX: 0
    property real gY: 0
    property real gOn: 0
    Behavior on gOn { NumberAnimation { duration: 320; easing.type: Easing.InOutCubic } }
    // Baile: la mirada se mece rotando la esfera (no solo el cuerpo plano) y sube en cada salto.
    // Cansado: mirada apenas caída.
    readonly property real fX: bX * (1 - gOn) + gX * gOn + 0.32 * danceAmp * Math.sin(2 * Math.PI * sway)
    readonly property real fY: bY * (1 - gOn) + gY * gOn + 0.5 * squint - 0.14 * danceAmp * Math.sin(Math.PI * ((beat + 0.1) % 1)) + 0.18 * tired
    // Sacada estilo Grok Bot: resorte rígido, salto rápido con overshoot leve y quieto.
    Behavior on eyeX { SpringAnimation { spring: 0.8 + 8.2 * Math.pow(1 - c.sleepy, 2); damping: 0.58 + 0.37 * c.sleepy; mass: 0.5; epsilon: 0.001 } }
    Behavior on eyeY { SpringAnimation { spring: 0.8 + 8.2 * Math.pow(1 - c.sleepy, 2); damping: 0.58 + 0.37 * c.sleepy; mass: 0.5; epsilon: 0.001 } }

    // ===== Ojos pintados sobre una esfera 3D =====
    // Cada ojo es una forma plana (cápsula = "espina" + radio) definida en el plano
    // tangente de la esfera, en radianes de arco, alrededor de su centro M
    // (±18.4° de longitud). La forma se envuelve sobre la esfera con el mapa
    // exponencial (P = cos|q|·M + sin|q|/|q|·(x·C + y·T)), la esfera gira según la
    // mirada (pitch y luego yaw) y se proyecta ortográficamente. Así los ojos se
    // escorzan y curvan solos al acercarse al borde. Lo de atrás se aplana al contorno.
    readonly property real gazeYaw: 0.5 * fX      // rad por unidad de mirada (~29°)
    readonly property real gazePitch: 0.42 * fY   // fY > 0 = abajo
    // La forma feliz es un estado discreto que se anima en el tiempo (como en la referencia:
    // 0.28 s con bezier .4,.06,.18,1), no una función de smile: así el morph siempre dura
    // lo mismo (~9 cuadros a 30 fps) y nunca se "salta" en 2 cuadros.
    property real happyK: joy > 0.5 ? 1 : 0
    Behavior on happyK { NumberAnimation { duration: 320; easing.type: Easing.BezierSpline; easing.bezierCurve: [0.4, 0.06, 0.18, 1, 1, 1] } }
    // cubic-bezier(.4,.06,.18,1) evaluada por Newton (curva de morph de la referencia)
    function easeMorph(x) {
        x = Math.max(0, Math.min(1, x)); if (x <= 0 || x >= 1) return x
        const x1 = 0.4, y1 = 0.06, x2 = 0.18, y2 = 1
        let t = x
        for (let i = 0; i < 6; i++) {
            const u = 1 - t, fx = 3 * u * u * t * x1 + 3 * u * t * t * x2 + t * t * t - x
            const dx = 3 * u * u * x1 + 6 * u * t * (x2 - x1) + 3 * t * t * (1 - x2)
            if (Math.abs(dx) < 1e-6) break; t = Math.max(0, Math.min(1, t - fx / dx))
        }
        const u = 1 - t; return 3 * u * u * t * y1 + 3 * u * t * t * y2 + t * t * t
    }
    function eyePoints(side, op, wMul, hMul, worryK, lift, sk, sq) {
        // forma en el plano tangente (x = hacia afuera, y = arriba)
        // Entrecerrado: tamaño y bajada calibrados contra el original (pastilla plana).
        const hw = 0.13 * wMul * (1 + 0.13 * squint)
        const sAng = -28 * worryK * Math.PI / 180
        const hs0 = Math.max(0, (0.57 - 0.07 * worryK) * hMul - 2 * hw) / 2
        // Entrecerrar (como el original): la pastilla se acorta centrada, alto mínimo
        // 0.35 × ancho, y las tapas se vuelven un rectángulo redondeado (radio = alto/2).
        const hh = Math.max(0.35 * hw, (hs0 + hw) * (sq === undefined ? 1 : sq) * (1 + 0.09 * squint))
        const rr = Math.min(hw, hh), hs = hh - rr, ta = hw - rr
        const hk = vHappy
        // Sonrisa: morph de contornos con la misma parametrización (por longitud de arco,
        // mismos hitos: arriba, costados, abajo). La parte de abajo de la pastilla sube y se
        // mete en el arco mientras los costados bajan a ser las patas: nunca pasa por un
        // círculo ni gira. Curva de Grok para morphs: bezier (.4,.06,.18,1).
        const k = Math.max(0, Math.min(1, hk))
        const wa = 0.095 * wMul, R = 0.14, cc = -0.04   // v12: arco más cerrado para no juntarse con ojos grandes
        const N = 24, loc = []
        const pillAt = t => {             // mitad derecha, t∈[0,1] de arriba hacia abajo
            const q = Math.PI / 2 * rr, L = 2 * ta + 2 * q + 2 * hs
            let d = t * L
            if (d < ta) return [d, hh]
            d -= ta
            if (d < q) { const a = d / rr; return [ta + rr * Math.sin(a), hs + rr * Math.cos(a)] }
            d -= q
            if (d < 2 * hs) return [hw, hs - d]
            d -= 2 * hs
            if (d < q) { const a = d / rr; return [ta + rr * Math.cos(a), -hs - rr * Math.sin(a)] }
            d -= q
            return [Math.max(0, ta - d), -hh]
        }
        const archAt = t => {
            const Ro = R + wa, Ri = Math.max(0.005, R - wa)
            const L1 = Ro * Math.PI / 2, L2 = Math.PI * wa, L3 = Ri * Math.PI / 2, d = t * (L1 + L2 + L3)
            if (d < L1) { const th = d / Ro; return [Ro * Math.sin(th), cc + Ro * Math.cos(th)] }
            if (d < L1 + L2) { const ph = (d - L1) / wa; return [R + wa * Math.cos(ph), cc - wa * Math.sin(ph)] }
            const th = Math.PI / 2 - (d - L1 - L2) / Ri; return [Ri * Math.sin(th), cc + Ri * Math.cos(th)]
        }
        const cs = Math.cos(sAng), sn = Math.sin(sAng)
        const half = []
        for (let i = 0; i <= N; i++) {
            const t = i / N, P = pillAt(t), A = archAt(t)
            half.push([P[0] + (A[0] - P[0]) * k, P[1] + (A[1] - P[1]) * k])
        }
        for (let i = 0; i <= N; i++) loc.push(half[i])
        for (let i = N - 1; i > 0; i--) loc.push([-half[i][0], half[i][1]])
        if (sAng !== 0) for (const q of loc) { const x = q[0], y = q[1]; q[0] = x * cs + y * sn; q[1] = -x * sn + y * cs }
        const oy = -0.05 * worryK + lift
        // párpado continuo para cualquier forma: aplasta el contorno en y hacia un punto
        // al 40 % desde abajo, con un alto mínimo (guion de 0.42 × ancho de la pastilla)
        let y0 = 1e9, y1 = -1e9
        for (const q of loc) { y0 = Math.min(y0, q[1]); y1 = Math.max(y1, q[1]) }
        const Hh = Math.max(1e-6, y1 - y0), ya = y0 + 0.4 * Hh
        let lid = Math.max(Math.max(0, Math.min(1, op)), Math.min(1, 0.42 * 2 * hw / Hh))
        // Dormido: el guion del párpado se curva en un arco fino "‿" (mismo contorno
        // parametrizado, arco circular invertido) pintado sobre la esfera.
        if (sk > 0) {
            for (const q of loc) q[1] = ya + (q[1] - ya) * lid
            const wl = 0.042 * wMul, Rl = 0.17, cl = 0.10, Ro = Rl + wl, Ri = Rl - wl
            const A0 = 0.62                           // semiapertura del arco (rad)
            const L1 = Ro * 2 * A0, L2 = Math.PI * wl, L3 = Ri * 2 * A0, Lt = L1 / 2 + L2 + L3 / 2
            const arcAt = t => {                       // mitad derecha, t∈[0,1]: centro de abajo → tapa → centro de arriba
                const d = t * Lt
                if (d < L1 / 2) { const th = d / Ro; return [Ro * Math.sin(th), cl - Ro * Math.cos(th)] }
                if (d < L1 / 2 + L2) {                  // tapa redonda alrededor del extremo
                    const ex = Rl * Math.sin(A0), ey = cl - Rl * Math.cos(A0), ang = A0 - Math.PI / 2 + (d - L1 / 2) / wl
                    return [ex + wl * Math.cos(ang), ey + wl * Math.sin(ang)]
                }
                const th = Math.max(0, A0 - (d - L1 / 2 - L2) / Ri); return [Ri * Math.sin(th), cl - Ri * Math.cos(th)]
            }
            const n = loc.length, e = sk * sk * (3 - 2 * sk)
            // loc: 0 = arriba, N = abajo (por la derecha), vuelve por la izquierda
            for (let i = 0; i < n; i++) {
                let A
                if (i <= N) A = arcAt(1 - i / N)
                else { const B = arcAt((i - N) / N); A = [-B[0], B[1]] }
                loc[i][0] += (A[0] - loc[i][0]) * e; loc[i][1] += (A[1] - loc[i][1]) * e
            }
            lid = 1
        }
        // v12: a mitad del morph a sonrisa el ojo se aplasta un poco (como un parpadeo
        // suave) para que la forma intermedia no se vea grumosa
        lid *= 1 - 0.35 * Math.sin(Math.PI * k)
        const wx = 1 + 0.1 * (1 - lid)          // al cerrar se ensancha un poco (squash)
        // v11: ojos ~23 % más grandes (el entrecerrado conserva su tamaño original)
        const G = 1 + 0.23 * (1 - Math.max(0, Math.min(1, squint)))
        for (const q of loc) { q[1] = (ya + (q[1] - ya) * lid) * G; q[0] *= wx * G }
        // marco del ojo sobre la esfera (y arriba, z hacia la cámara); v12: ±20.5° (separación proporcional)
        const Mx = side * 0.3502, Mz = 0.9367, Cx = side * 0.9367, Cz = -0.3502
        const cyw = Math.cos(gazeYaw), syw = Math.sin(gazeYaw), cp = Math.cos(gazePitch), sp = Math.sin(gazePitch)
        const pts = []
        for (let j = 0; j <= loc.length; j++) {
            const u = loc[j % loc.length][0], v = loc[j % loc.length][1] + oy
            const l = Math.hypot(u, v), sc = l > 1e-9 ? Math.sin(l) / l : 1, co = Math.cos(l)
            let X = co * Mx + sc * u * Cx, Y = sc * v, Z = co * Mz + sc * u * Cz
            // pitch (eje x): mirar abajo baja los ojos
            const Y1 = Y * cp - Z * sp, Z1 = Y * sp + Z * cp
            // yaw (eje y)
            let X2 = X * cyw + Z1 * syw
            let Y2 = Y1
            const Z2 = -X * syw + Z1 * cyw
            if (Z2 < 0) { const h = Math.hypot(X2, Y2) || 1; X2 /= h; Y2 /= h }
            pts.push(Qt.point(r + X2 * r, r - Y2 * r))
        }
        return pts
    }

    // ===== Estados: parpadeo, dormir, baile =====
    property real blink: 1
    // Parpadeo natural: ~140 ms (cierre rápido, apertura más lenta), cada 3–6 s,
    // a veces doble.
    property bool doubleBlink: false
    SequentialAnimation {
        id: blinkAnim
        // tiempos de la referencia (0.26 s): cierre ~90 ms, pausa ~33 ms, apertura ~130 ms
        NumberAnimation { target: c; property: "blink"; to: 0; duration: c.petting ? 260 : 90; easing.type: c.petting ? Easing.InOutSine : Easing.InOutQuad }
        PauseAnimation { duration: c.petting ? 180 : 33 }
        NumberAnimation { target: c; property: "blink"; to: 1; duration: c.petting ? 420 : 135; easing.type: c.petting ? Easing.InOutSine : Easing.OutCubic }
        PauseAnimation { duration: c.doubleBlink ? 110 : 0 }
        NumberAnimation { target: c; property: "blink"; to: c.doubleBlink ? 0 : 1; duration: c.doubleBlink ? 80 : 0; easing.type: Easing.InOutQuad }
        PauseAnimation { duration: c.doubleBlink ? 25 : 0 }
        NumberAnimation { target: c; property: "blink"; to: 1; duration: c.doubleBlink ? 130 : 0; easing.type: Easing.OutCubic }
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
    readonly property real openness: blink * vHalf * (1 - sleepy) * (1 - 0.4 * tired) * (1 - 0.62 * petK)
    // Alegría con pastillas: más bajas y elevadas (mejillas que suben). Bailando, leve.
    // Morph a ojos cerrados curvos: empieza cuando el párpado ya es un guion.
    readonly property real sleepK: Math.max(0, Math.min(1, (sleepy - 0.55) / 0.45))
    readonly property real joy: Math.max(vSmile * (1 - winkHold), 0.45 * danceOn, 0.8 * petK) * (1 - sleepy)
    // Guiño: un ojo queda ABIERTO como pastilla normal y el otro se cierra con el
    // párpado (línea curva). La sonrisa del guiño no debe convertir los ojos en arcos:
    // mientras los ojos están asimétricos (y 500 ms después) se anula su alegría.
    readonly property bool winkAsym: Math.abs(vOL - vOR) > 0.04
    property real winkHold: 0
    onWinkAsymChanged: { if (winkAsym) { winkRelease.stop(); winkHold = 1 } else winkRelease.restart() }
    Timer { id: winkRelease; interval: 500; onTriggered: c.winkHold = 0 }

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

    // ===== Ánimo (lo fija quien usa el personaje, p. ej. el panel de estado) =====
    // "" = normal/feliz · "worried" = preocupado (ojos más chicos e inclinados, sacudón)
    // · "tired" = cansado/exigido (ojos entrecerrados, inclinado).
    property string mood: ""
    property real worry: active && !asleep && mood === "worried" ? 1 : 0
    property real tired: active && !asleep && mood === "tired" ? 1 : 0
    Behavior on worry { NumberAnimation { duration: 420; easing.type: Easing.InOutCubic } }
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

    // ===== Capa de continuidad (v10) =====
    // Lo que animan las reacciones es el OBJETIVO; lo que se dibuja (v*) lo sigue con un
    // resorte críticamente amortiguado (ω = 55 rad/s, ~35 ms de retardo, sin overshoot).
    // Así la posición Y la velocidad son continuas aunque una reacción interrumpa a otra,
    // un PropertyAction salte o un Behavior se reinicie a mitad de camino. Parpadeo,
    // entrecerrar, mirada (sacadas) y baile NO pasan por acá: conservan su timing exacto.
    readonly property var _sm: [
        ["vRot", "rRot"], ["vSx", "squashX"], ["vSy", "squashY"], ["vScale", "rScale"],
        ["vX", "rX"], ["vY", "rY"], ["vBy", "bounceY"], ["vRoll", "roll"],
        ["vEW", "eyeWMul"], ["vEH", "eyeHMul"], ["vOL", "openL"], ["vOR", "openR"],
        ["vHalf", "half"], ["vSmile", "smile"], ["vLook", "lookOverride"], ["vOX", "oX"],
        ["vOY", "oY"], ["vHappy", "happyK"]]
    property var _vel: ({})
    property real vRot: 0; property real vSx: 1; property real vSy: 1; property real vScale: 1
    property real vX: 0; property real vY: 0; property real vBy: 0; property real vRoll: 0
    property real vEW: 1; property real vEH: 1; property real vOL: 1; property real vOR: 1
    property real vHalf: 1; property real vSmile: 0; property real vLook: 0; property real vOX: 0
    property real vOY: 0; property real vHappy: 0
    property bool _moving: true
    function _kick() { _moving = true }
    onRRotChanged: _kick(); onSquashXChanged: _kick(); onSquashYChanged: _kick(); onRScaleChanged: _kick()
    onRXChanged: _kick(); onRYChanged: _kick(); onBounceYChanged: _kick(); onRollChanged: _kick()
    onEyeWMulChanged: _kick(); onEyeHMulChanged: _kick(); onOpenLChanged: _kick(); onOpenRChanged: _kick()
    onHalfChanged: _kick(); onSmileChanged: _kick(); onLookOverrideChanged: _kick(); onOXChanged: _kick()
    onOYChanged: _kick(); onHappyKChanged: _kick()
    FrameAnimation {
        running: c._moving
        onTriggered: {
            const w = 55, dtAll = Math.min(0.05, frameTime > 0 ? frameTime : 1 / 60)
            const steps = Math.max(1, Math.ceil(dtAll * 240)), dt = dtAll / steps
            let still = true
            for (const p of c._sm) {
                const tgt = c[p[1]]
                let x = c[p[0]], v = c._vel[p[0]] || 0
                for (let i = 0; i < steps; i++) { v += (w * w * (tgt - x) - 2 * w * v) * dt; x += v * dt }
                const sc = p[0] === "vRot" || p[0] === "vRoll" ? 0.02 : (p[0] === "vX" || p[0] === "vY" || p[0] === "vBy" ? 0.02 : 0.0004)
                if (Math.abs(tgt - x) < sc && Math.abs(v) < sc * 20) { x = tgt; v = 0 } else still = false
                c._vel[p[0]] = v
                if (c[p[0]] !== x) c[p[0]] = x
            }
            if (still) c._moving = false
        }
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
        rotation: c.danceRot + c.vRot + c.moodShake - 4 * c.tired + c.petSide * c.petLean * c.petK
        transform: [
            Scale { origin.x: c.s / 2; origin.y: c.s; xScale: c.vSx * c.breath * c.danceSx; yScale: c.vSy * c.breath * c.danceSy },
            Scale { origin.x: c.s / 2; origin.y: c.s / 2; xScale: c.vScale; yScale: c.vScale },
            Scale { origin.x: c.s / 2; origin.y: c.s; xScale: c.petPuff * (1 + 0.02 * c.petK); yScale: c.petPuff * (1 - 0.02 * c.petK) },
            Translate { x: c.vX + c.petSide * c.s * 0.045 * c.petK * (c.petLean - 5) / 4; y: c.vBy + c.danceY + c.vY + c.petHopY }
        ]

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
            rotation: c.vRoll
            Repeater {
                model: [-1, 1]
                delegate: Shape {
                    id: eye
                    required property int modelData
                    anchors.fill: parent
                    preferredRendererType: Shape.CurveRenderer
                    readonly property real own: modelData < 0 ? c.vOL : c.vOR
                    readonly property real other: modelData < 0 ? c.vOR : c.vOL
                    // guiño: el ojo que no guiña queda totalmente abierto (pastilla normal)
                    readonly property real shown: own >= other ? own + (1 - own) * c.winkHold : own
                    ShapePath {
                        strokeColor: "transparent"
                        fillColor: Theme.eye
                        PathPolyline {
                            path: c.eyePoints(eye.modelData, c.openness * eye.shown,
                                              c.vEW * (1 - 0.12 * c.worry) * (1 + 0.15 * c.squint),
                                              c.vEH * (1 - 0.25 * c.worry) * (1 - 0.28 * c.joy),
                                              c.worry, 0.04 * c.joy * (1 - c.vHappy), Math.max(c.sleepK, Math.max(0, Math.min(1, (0.45 - eye.own) / 0.37))), 1 - 0.8 * c.squint)
                        }
                    }
                }
            }
        }
        }
    }
}
