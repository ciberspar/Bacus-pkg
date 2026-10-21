#!/bin/sh
# ======================================================
#  Módulo Export - BACUSP v5.0 Pure Standalone 🐢📦
# ======================================================
CYAN='\033[1;36m'; VERDE='\033[1;32m'; RESET='\033[0m'
DESTINO="$HOME/bacusp_backup_$(date +%Y%m%d).tar.gz"

echo "${CYAN}📦 [Bacusp Exporter] Empaquetando entorno y base de datos autónoma...${RESET}"

if [ -d "$HOME/.bacusp" ]; then
    tar -czf "$DESTINO" -C "$HOME" .bacusp bin 2>/dev/null
    echo "${VERDE}✨ Entorno exportado exitosamente en: $DESTINO${RESET}"
else
    echo "⚠️ No se encontró la carpeta de Bacusp."
fi
