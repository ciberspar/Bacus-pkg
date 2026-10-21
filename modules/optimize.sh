#!/bin/sh
# ======================================================
#  Módulo Optimize - BACUSP v5.0 Pure Standalone 🐢⚡
# ======================================================
CYAN='\033[1;36m'; VERDE='\033[1;32m'; AMARILLO='\033[1;33m'; RESET='\033[0m'
INSTALL_DIR="$HOME/bin"
[ -d "/usr/local/bin" ] && [ -w "/usr/local/bin" ] && INSTALL_DIR="/usr/local/bin"

echo "${CYAN}⚡ [Bacusp Optimizer] Comprimiendo y limpiando símbolos en $INSTALL_DIR...${RESET}"

if command -v strip >/dev/null 2>&1; then
    for bin in "$INSTALL_DIR"/*; do
        if [ -f "$bin" ] && [ -x "$bin" ]; then
            ANTES=$(du -k "$bin" | awk '{print $1}')
            strip --strip-unneeded "$bin" 2>/dev/null
            DESPUES=$(du -k "$bin" | awk '{print $1}')
            echo "${VERDE}  - Optimizado: $(basename "$bin") (${ANTES}KB -> ${DESPUES}KB)${RESET}"
        fi
    done
else
    echo "${AMARILLO}⚠️ 'strip' no está disponible en este entorno.${RESET}"
fi
