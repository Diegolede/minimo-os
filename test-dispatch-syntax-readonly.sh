#!/bin/bash
# Test read-only de sintaxis dispatch de Hyprland 0.57.1
# NO cambia de escritorio, solo valida sintaxis

set -euo pipefail

echo "=== Test de sintaxis dispatch Hyprland 0.57.1 ==="
echo ""
echo "Workspace actual:"
hyprctl activeworkspace -j | jq -r '.id'
echo ""

# Test 1: Validar que hl.dsp.focus existe y acepta parámetros
echo "Test 1: Validar constructor hl.dsp.focus"
if hyprctl eval 'return type(hl.dsp.focus)' 2>&1 | grep -q "function"; then
    echo "✓ hl.dsp.focus es una función"
else
    echo "✗ hl.dsp.focus NO es una función"
    hyprctl eval 'return type(hl.dsp.focus)' 2>&1
fi
echo ""

# Test 2: Crear dispatcher object SIN ejecutarlo
echo "Test 2: Crear dispatcher con sintaxis sin espacios"
RESULT=$(hyprctl eval 'local d = hl.dsp.focus({workspace="r+1"}); return type(d), d.__act' 2>&1)
if echo "$RESULT" | grep -q "table"; then
    echo "✓ Sintaxis SIN espacios: {workspace=\"r+1\"} crea objeto válido"
    echo "  Resultado: $RESULT"
else
    echo "✗ Sintaxis SIN espacios FALLÓ"
    echo "  Error: $RESULT"
fi
echo ""

# Test 3: Crear dispatcher con espacios
echo "Test 3: Crear dispatcher con sintaxis con espacios"
RESULT=$(hyprctl eval 'local d = hl.dsp.focus({ workspace = "r+1" }); return type(d), d.__act' 2>&1)
if echo "$RESULT" | grep -q "table"; then
    echo "✓ Sintaxis CON espacios: { workspace = \"r+1\" } crea objeto válido"
    echo "  Resultado: $RESULT"
else
    echo "✗ Sintaxis CON espacios FALLÓ"
    echo "  Error: $RESULT"
fi
echo ""

# Test 4: Comparar si son equivalentes
echo "Test 4: Comparar representación de ambas sintaxis"
NOSPC=$(hyprctl eval 'return tostring(hl.dsp.focus({workspace="r+1"}))' 2>&1)
WITHSPC=$(hyprctl eval 'return tostring(hl.dsp.focus({ workspace = "r+1" }))' 2>&1)
if [ "$NOSPC" = "$WITHSPC" ]; then
    echo "✓ Ambas sintaxis producen resultado idéntico"
    echo "  Valor: $NOSPC"
else
    echo "⚠ Sintaxis producen resultados diferentes"
    echo "  Sin espacios: $NOSPC"
    echo "  Con espacios: $WITHSPC"
fi
echo ""

# Test 5: Probar que dispatch real EJECUTA (esto SÍ cambiará workspace)
echo "Test 5: Ejecutar dispatch real con sintaxis sin espacios"
echo "⚠️  ADVERTENCIA: Esto SÍ cambiará de escritorio"
read -p "Presiona Enter para continuar o Ctrl+C para cancelar..."
echo ""

BEFORE=$(hyprctl activeworkspace -j | jq -r '.id')
echo "Workspace antes: $BEFORE"

hyprctl dispatch 'hl.dsp.focus({workspace="r+1"})' 2>&1
sleep 0.5

AFTER=$(hyprctl activeworkspace -j | jq -r '.id')
echo "Workspace después: $AFTER"

if [ "$BEFORE" != "$AFTER" ]; then
    echo "✓ Dispatch FUNCIONÓ - workspace cambió de $BEFORE a $AFTER"
    echo ""
    echo "Volviendo al workspace original..."
    hyprctl dispatch "hl.dsp.focus({workspace=\"$BEFORE\"})" 2>&1
else
    echo "✗ Dispatch NO cambió workspace (quedó en $AFTER)"
fi
echo ""

echo "=== Fin del test ==="
echo ""
echo "Resumen:"
echo "- Si Tests 1-4 pasan: Sintaxis es válida en Lua"
echo "- Si Test 5 falla: Problema está en cómo Hyprland procesa el selector"
echo "- Si Test 5 pasa: Problema está en cómo Quickshell llama a hyprctl"
