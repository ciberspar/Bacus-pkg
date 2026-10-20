#!/bin/sh
# ======================================================
#  Módulo de Limpieza Avanzada - Bacusp 🐢🧹
# ======================================================

echo "🧹 Iniciando análisis y limpieza del sistema..."
echo "--------------------------------------------------"

TOTAL_BORRADOS=0

limpiar_ruta() {
    RUTA=$1
    ETIQUETA=$2
    if [ -d "$RUTA" ] || [ -f "$RUTA" ]; then
        ARCHIVOS=$(ls -A "$RUTA" 2>/dev/null | wc -l | tr -d ' ')
        if [ "$ARCHIVOS" -gt 0 ]; then
            echo "🗑️  Limpiando $ETIQUETA ($ARCHIVOS elementos en $RUTA)..."
            rm -rf "$RUTA"/* 2>/dev/null
            TOTAL_BORRADOS=$((TOTAL_BORRADOS + ARCHIVOS))
        else
            echo "✨ $ETIQUETA ($RUTA) ya estaba limpio."
        fi
    fi
}

# Rutas de temporales comunes en iOS/a-shell y Linux
limpiar_ruta "$HOME/.cache" "Caché de usuario"
limpiar_ruta "/tmp" "Archivos temporales (/tmp)"
limpiar_ruta "$HOME/.tmp" "Temporales de a-shell"
limpiar_ruta "$HOME/.bash_history_tmp" "Historiales temporales"

echo "--------------------------------------------------"
echo "✅ ¡Limpieza completada! Se eliminaron/procesaron $TOTAL_BORRADOS elementos."
