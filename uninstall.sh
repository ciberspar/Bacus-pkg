#!/bin/sh
# ======================================================
#  BACUSP UNINSTALLER 🐢
# ======================================================

CYAN='\033[1;36m'
ROJO='\033[1;31m'
RESET='\033[0m'

echo "${ROJO}⚠️ Removiendo Bacusp y deteniendo servicios...${RESET}"

# Detener el centinela si está ejecutándose
pkill -f "bacusp-daemon" 2>/dev/null

SHELL_CONFIG=""
[ -f "$HOME/.zshrc" ] && SHELL_CONFIG="$HOME/.zshrc"
[ -f "$HOME/.bashrc" ] && SHELL_CONFIG="$HOME/.bashrc"

if [ -n "$SHELL_CONFIG" ]; then
    sed -i.bak '/BACUSP AUTOMATION/d' "$SHELL_CONFIG" 2>/dev/null
    sed -i.bak '/bacusp-completion/d' "$SHELL_CONFIG" 2>/dev/null
    sed -i.bak '/bacusp-daemon/d' "$SHELL_CONFIG" 2>/dev/null
    rm -f "${SHELL_CONFIG}.bak"
    echo "${CYAN}✅ Se limpiaron las referencias en $SHELL_CONFIG${RESET}"
fi

echo "${CYAN}✨ Desinstalación completada.${RESET}"
