#!/bin/sh
# ======================================================
#  BACUSP AUTOMATED INSTALLER & CONFIGURATOR 🐢⚡
#  Creator: ciberspar
#  Description: Configures the environment, aliases, and the Watch Dogs
#  Creador: ciberspar
#  Descripción: Configura el entorno, alias y el Watch Dogs
# ======================================================

resolve_lang() {
    locale="${BACUSP_LANG:-${LANG:-${LC_ALL:-}}}"
    case "${locale%%.*}" in
        en|en_US|en_GB|en_AU|C|POSIX)
            printf '%s\n' "en"
            ;;
        es|es_ES|es_MX|es_AR|es_CL|es_CO|es_PE|es_UY|es_GT)
            printf '%s\n' "es"
            ;;
        *)
            printf '%s\n' "en"
            ;;
    esac
}

BACUSP_LANG=$(resolve_lang)

CYAN='\033[1;36m'
VERDE='\033[1;32m'
AMARILLO='\033[1;33m'
RESET='\033[0m'

echo "${CYAN}🚀 Configurando el entorno para Bacusp Pure Standalone...${RESET}"

chmod +x bin/bacusp 2>/dev/null
chmod +x bin/bacusp-daemon 2>/dev/null

SHELL_CONFIG=""
if [ -f "$HOME/.zshrc" ]; then
    SHELL_CONFIG="$HOME/.zshrc"
elif [ -f "$HOME/.bashrc" ]; then
    SHELL_CONFIG="$HOME/.bashrc"
else
    SHELL_CONFIG="$HOME/.profile"
fi

echo "${VERDE}📝 Modificando archivo de configuración: $SHELL_CONFIG${RESET}"

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
