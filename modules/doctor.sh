#!/bin/sh
# ======================================================
#  Módulo Doctor - BACUSP v5.1 Pure Standalone 🐢🩺
#  Creador: ciberspar
#  Descripción: Autodiagnóstico del sistema y estado de salud
# ======================================================

CYAN='\033[1;36m'; VERDE='\033[1;32m'; AMARILLO='\033[1;33m'; ROJO='\033[1;31m'; RESET='\033[0m'
BACUSP_HOME="$HOME/.bacusp"

echo "${CYAN}🩺 [Bacusp Doctor] Ejecutando diagnóstico de salud...${RESET}"
echo ""

# 1. Comprobar estructura de carpetas
[ -d "$BACUSP_HOME" ] && echo "${VERDE}  - Carpeta ~/.bacusp: OK${RESET}" || echo "${ROJO}  - Carpeta ~/.bacusp: NO ENCONTRADA${RESET}"

# 2. Comprobar base de datos
[ -f "$BACUSP_HOME/installed.db" ] && echo "${VERDE}  - Base de datos installed.db: OK${RESET}" || echo "${AMARILLO}  - Base de datos installed.db: No creada aún${RESET}"

# 3. Comprobar $PATH
if echo "$PATH" | grep -q "$HOME/bin" || echo "$PATH" | grep -q "/usr/local/bin"; then
    echo "${VERDE}  - Rutas de binarios en \$PATH: OK${RESET}"
else
    echo "${AMARILLO}  - Advertencia: Asegurate de tener ~/bin o /usr/local/bin en tu \$PATH${RESET}"
fi

echo ""
echo "${VERDE}✨ Diagnóstico finalizado. Sistema listo para operar. 🐢🚀${RESET}"
