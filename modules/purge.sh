#!/bin/sh
# ======================================================
#  Módulo Purge - BACUSP v5.1 Pure Standalone 🐢💥
#  Creador: ciberspar
#  Descripción: Limpieza profunda y eliminación de configuraciones
# ======================================================

CYAN='\033[1;36'; VERDE='\033[1;32m'; ROJO='\033[1;31m'; AMARILLO='\033[1;33m'; RESET='\033[0m'
DB_FILE="$HOME/.bacusp/installed.db"
CACHE_DIR="$HOME/.bacusp/cache"
PAQ=$1

if [ -z "$PAQ" ]; then
    echo "${ROJO}❌ Error: Especificá el paquete a purgar / Specify package to purge.${RESET}"
    exit 1
fi

echo "${ROJO}🔥 [Bacusp Purge Engine] Purgando completamente '$PAQ'...${RESET}"

# 1. Eliminar binarios
if [ -f "$DB_FILE" ]; then
    REGISTRO=$(grep "^$PAQ|" "$DB_FILE")
    if [ -n "$REGISTRO" ]; then
        RUTA_BIN=$(echo "$REGISTRO" | awk -F'|' '{print $2}')
        [ -f "$RUTA_BIN" ] && rm -f "$RUTA_BIN" && echo "${VERDE}  - Binario eliminado: $RUTA_BIN${RESET}"
        grep -v "^$PAQ|" "$DB_FILE" > "$DB_FILE.tmp" && mv "$DB_FILE.tmp" "$DB_FILE"
    fi
fi

# 2. Eliminar carpetas de caché y configuración
rm -rf "$CACHE_DIR/build_$PAQ"
rm -rf "$HOME/.config/$PAQ" 2>/dev/null

echo "${VERDE}✨ Purga completa de '$PAQ' y sus rastros finalizada. 🗑️${RESET}"
