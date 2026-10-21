#!/bin/sh
# ======================================================
#  BACUSP AUTOMATED INSTALLER & CONFIGURATOR 🐢⚡
#  Creador: ciberspar
#  Descripción: Configura el entorno, alias y el Watch Dogs
# ======================================================

CYAN='\033[1;36m'
VERDE='\033[1;32m'
AMARILLO='\033[1;33m'
RESET='\033[0m'

echo "${CYAN}🚀 Configurando el entorno para Bacusp Pure Standalone...${RESET}"

# 1. Dar permisos de ejecución a los binarios
chmod +x bin/bacusp 2>/dev/null
chmod +x bin/bacusp-daemon 2>/dev/null

# 2. Detectar el archivo de configuración de la shell (.bashrc o .zshrc)
SHELL_CONFIG=""
if [ -f "$HOME/.zshrc" ]; then
    SHELL_CONFIG="$HOME/.zshrc"
elif [ -f "$HOME/.bashrc" ]; then
    SHELL_CONFIG="$HOME/.bashrc"
else
    SHELL_CONFIG="$HOME/.profile"
fi

echo "${VERDE}📝 Modificando archivo de configuración: $SHELL_CONFIG${RESET}"

# 3. Agregar el autocompletado y el Watch Dogs Daemon si no están ya agregados
if ! grep -q "BACUSP WATCH DOGS DAEMON" "$SHELL_CONFIG" 2>/dev/null; then
    cat << 'EOF' >> "$SHELL_CONFIG"

# ======================================================
#  🐢 BACUSP AUTOMATION & WATCH DOGS DAEMON
# ======================================================
[ -f "$HOME/bin/bacusp-completion" ] && source "$HOME/bin/bacusp-completion"

if ! pgrep -f "bacusp-daemon" > /dev/null 2>&1; then
    nice -n 19 sh "$HOME/bin/bacusp-daemon" >/dev/null 2>&1 &
fi
EOF
    echo "${VERDE}✅ Configuración agregada con éxito.${RESET}"
else
    echo "${AMARILLO}⚠️ Bacusp ya estaba configurado en tu $SHELL_CONFIG.${RESET}"
fi

echo ""
echo "${CYAN}✨ ¡Instalación completa! Reiniciá tu terminal o ejecutá: source $SHELL_CONFIG${RESET}"
