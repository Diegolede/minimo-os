# Comandos de diagnóstico read-only para regresión de scroll

**IMPORTANTE**: Estos comandos NO modifican nada, solo recopilan información.

## 1. Verificar sintaxis del comando actual

```bash
# Ver la función dispatchWs actual
grep -A 3 "function dispatchWs" ~/Proyectos/minimo-os/minimo-shell/Common/Workspaces.qml

# Ver la función wheel actual  
grep -A 10 "function wheel" ~/Proyectos/minimo-os/minimo-shell/Common/Workspaces.qml
```

## 2. Probar comando hyprctl manualmente (cambiará de escritorio)

⚠️ **ADVERTENCIA**: Estos comandos SÍ cambiarán de escritorio

```bash
# Probar sintaxis actual de Minimo
hyprctl dispatch 'hl.dsp.focus({workspace="r+1"})'

# Probar con espacios
hyprctl dispatch 'hl.dsp.focus({ workspace = "r+1" })'

# Ver qué escritorios existen
hyprctl workspaces -j | jq '.[] | {id, name, monitor}'

# Ver escritorio activo
hyprctl activeworkspace -j | jq '{id, name, monitor}'
```

## 3. Verificar que quickshell recibe eventos de scroll

Necesitaremos agregar logging temporal. Crear archivo de prueba:

```bash
cd ~/Proyectos/minimo-os
cat > test-wheel-logging.patch << 'EOF'
--- a/minimo-shell/Common/Workspaces.qml
+++ b/minimo-shell/Common/Workspaces.qml
@@ -24,6 +24,7 @@ Singleton {
     // Una muesca de rueda = un workspace (con enfriamiento).
     function wheel(deltaY) {
         const now = Date.now()
+        console.log("[WHEEL DEBUG] deltaY:", deltaY, "wheelAcc:", wheelAcc, "now-wheelT:", now - wheelT)
         if (deltaY === 0) return
         // Touchpads mandan muchos deltas chicos: se acumulan hasta una "muesca" (120)
         // para que un roce accidental no cambie de escritorio. Pausa o cambio de sentido: reinicia.
@@ -32,6 +33,7 @@ Singleton {
         wheelAcc += deltaY
         if (Math.abs(wheelAcc) < 120 || now - lastWheel < 220) return
         lastWheel = now; wheelAcc = 0
+        console.log("[WHEEL DEBUG] Calling dispatchWs with:", deltaY > 0 ? "r-1" : "r+1")
         dispatchWs(deltaY > 0 ? "r-1" : "r+1")
     }
EOF

# Ver el patch (NO aplicarlo todavía)
cat test-wheel-logging.patch
```

## 4. Verificar eventos QML en Island.qml

```bash
# Ver handler de wheel en Island.qml
grep -B 5 -A 5 "onWheel" ~/Proyectos/minimo-os/minimo-shell/Island/Island.qml
```

## 5. Test directo del comando desde la shell

⚠️ **Cambiará de escritorio**:

```bash
# Ejecutar exactamente lo que Minimo ejecuta
sh -c "hyprctl dispatch 'hl.dsp.focus({workspace=\"r+1\"})' >/dev/null 2>&1"

# Ver si hay output/error sin redirigir
sh -c "hyprctl dispatch 'hl.dsp.focus({workspace=\"r+1\"})'"
```

## 6. Verificar logs de minimo-shell

```bash
# Ver últimos 50 logs de minimo-shell
journalctl --user -u minimo-shell -n 50 --no-pager

# Ver logs en tiempo real mientras pruebas el scroll (otra terminal)
journalctl --user -u minimo-shell -f
```

## 7. Test de si hyprland responde a dispatches

```bash
# Probar un dispatch simple que sabemos que funciona
hyprctl dispatch 'hl.dsp.exec_cmd("echo test")'

# Probar cambio de escritorio directo (cambiará al escritorio 2)
hyprctl dispatch 'hl.dsp.focus({ workspace = "2" })'

# Verificar que cambió
hyprctl activeworkspace -j | jq '.id'
```

## 8. Verificar si Quickshell.execDetached funciona

Crear script temporal de prueba:

```bash
# Crear test en /tmp
cat > /tmp/test-quickshell-exec.qml << 'EOF'
import Quickshell

ShellRoot {
    Component.onCompleted: {
        console.log("Test 1: execDetached con sh -c")
        Quickshell.execDetached(["sh", "-c", "hyprctl dispatch 'hl.dsp.focus({workspace=\"1\"})' >/dev/null 2>&1"])
        
        console.log("Test 2: execDetached sin sh -c")
        Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.focus({ workspace = \"2\" })"])
        
        Qt.quit()
    }
}
EOF

# NO ejecutar, solo ver el archivo
cat /tmp/test-quickshell-exec.qml
```

## Resumen de qué buscar

1. **Si el comando hyprctl funciona manualmente** → El problema está en QML/Quickshell
2. **Si los logs no muestran "[WHEEL DEBUG]"** → El evento wheel no llega a la función
3. **Si los logs muestran debug pero no cambia de escritorio** → El problema está en el dispatch
4. **Si funciona con sintaxis con espacios pero no sin espacios** → Validaría el fix
5. **Si no funciona con ninguna sintaxis** → Hay un problema diferente

## Comandos seguros para recopilar toda la info

```bash
cd ~/Proyectos/minimo-os

echo "=== Git status ===" 
git status

echo "=== Hyprland version ===" 
hyprctl version | head -5

echo "=== Quickshell version ===" 
quickshell --version 2>&1 || qs --version 2>&1 || echo "quickshell no encontrado"

echo "=== Config provider ===" 
hyprctl systeminfo | grep -i provider

echo "=== Config errors ===" 
hyprctl configerrors

echo "=== Workspaces actuales ===" 
hyprctl workspaces -j | jq '.[] | {id, name, monitor, windows}'

echo "=== Dispatcher wheel en Island ===" 
grep -A 2 "onWheel" minimo-shell/Island/Island.qml

echo "=== Función wheel en Workspaces ===" 
grep -A 15 "function wheel" minimo-shell/Common/Workspaces.qml

echo "=== Función dispatchWs ===" 
grep -A 3 "function dispatchWs" minimo-shell/Common/Workspaces.qml

echo "=== Últimos logs minimo-shell ===" 
journalctl --user -u minimo-shell -n 20 --no-pager | tail -10
```
