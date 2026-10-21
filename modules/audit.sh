#!/bin/sh
# ======================================================
#  Módulo Audit - BACUSP v5.0 Pure Standalone 🐢🛡️
# ======================================================
CYAN='\033[1;36m'; VERDE='\033[1;32m'; ROJO='\033[1;31m'; RESET='\033[0m'
DB_FILE="$HOME/.bacusp/installed.db"

echo "${CYAN}🛡️ [Bacusp Security Audit] Analizando integridad del sistema...${RESET}"

if [ ! -f "$DB_FILE" ]; then
    echo "${ROJO}❌ No hay paquetes registrados en la base de datos.${RESET}"
    exit 0
fi

echo "${VERDE}🔍 Verificando binarios registrados en ~/.bacusp/installed.db:${RESET}"
while IFS='|' read -r PAQ RUTA FECHA; do
    if [ -f "$RUTA" ]; then
        PERM=$(ls -l "$RUTA" | awk '{print $1}')
        TAM=$(du -h "$RUTA" | awk '{print $1}')
        echo "  - $PAQ ($TAM) -> Status: OK | Permisos: $PERM"
    else
        echo "  - ${ROJO}$PAQ -> ALERTA: Binario no encontrado en $RUTA${RESET}"
    fi
done < "$DB_FILE"
