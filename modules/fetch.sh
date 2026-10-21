#!/bin/sh
# ======================================================
#  Módulo Fetch Universal - bacus-pkg 🐢🐧📱🪟🎨
# ======================================================

# Colores ANSI
VERDE='\033[1;32m'
AZUL='\033[1;34m'
CYAN='\033[1;36m'
ROJO='\033[1;31m'
MAGENTA='\033[1;35m'
AMARILLO='\033[1;33m'
RESET='\033[0m'

# --- DETECCIÓN DE DISTRO / OS ---
if command -v pkg >/dev/null 2>&1; then
    DISTRO="ios"
    NOM_DISTRO="chiquiOS / iOS"
elif command -v winget >/dev/null 2>&1 || command -v choco >/dev/null 2>&1 || [ -n "$WINDIR" ]; then
    DISTRO="windows"
    NOM_DISTRO="Microsoft Windows"
elif command -v pkgman >/dev/null 2>&1; then
    DISTRO="haiku"
    NOM_DISTRO="Haiku OS"
elif [ -f /etc/os-release ]; then
    . /etc/os-release
    DISTRO=$ID
    NOM_DISTRO=$NAME
else
    DISTRO="linux"
    NOM_DISTRO="$(uname -s) Generic"
fi

USUARIO=$(whoami 2>/dev/null || echo "user")
SHELL_ACTUAL=$(basename "$SHELL" 2>/dev/null || echo "sh")
ARQ=$(uname -m)

echo ""
case "$DISTRO" in
    hurd)
        echo "${CYAN}    _____                      ${RESET} 👤 ${CYAN}Usuario / User:${RESET} $USUARIO"
        echo "${CYAN}   / ___ \\                     ${RESET} 🧬 ${CYAN}Sistema / OS:${RESET} GNU/Hurd (Microkernel)"
        echo "${CYAN}  | |   | |                    ${RESET} 🐢 ${CYAN}Gestor / PM:${RESET} Bacusp v3.5 (APT/Dpkg)"
        ;;
    minix)
        echo "${AMARILLO}   _  _                       ${RESET} 👤 ${CYAN}Usuario / User:${RESET} $USUARIO"
        echo "${AMARILLO}  | || |                      ${RESET} 📚 ${CYAN}Sistema / OS:${RESET} Minix OS (Tanenbaum)"
        echo "${AMARILLO}  | || |_                     ${RESET} 🐢 ${CYAN}Gestor / PM:${RESET} Bacusp v3.5 (Pkgin)"
        ;;
    serenity)
        echo "${MAGENTA}   ╔══════╗                   ${RESET} 👤 ${CYAN}Usuario / User:${RESET} $USUARIO"
        echo "${MAGENTA}   ║ 90s  ║                   ${RESET} 🖥️  ${CYAN}Sistema / OS:${RESET} SerenityOS (Retro 90s)"
        echo "${MAGENTA}   ╚══════╝                   ${RESET} 🐢 ${CYAN}Gestor / PM:${RESET} Bacusp v3.5 (Ports)"
        ;;
    plan9)
        echo "${AZUL}   ___                        ${RESET} 👤 ${CYAN}Usuario / User:${RESET} $USUARIO"
        echo "${AZUL}  / _ \\                       ${RESET} 🌌 ${CYAN}Sistema / OS:${RESET} Plan 9 from Bell Labs"
        echo "${AZUL} | (_) |                      ${RESET} 🐢 ${CYAN}Gestor / PM:${RESET} Bacusp v3.5 (Native)"
        ;;
    termux)
        echo "${VERDE}   ___                        ${RESET} 👤 ${CYAN}Usuario / User:${RESET}$USUARIO"
        echo "${VERDE}  /   \\ ${RESET} 📱 ${CYAN}Sistema / OS:${RESET} Termux (Android)"
        echo "${VERDE} \vert{} o o \vert{}${RESET} 🐢 ${CYAN}Gestor / PM:${RESET} Bacusp v3.5 (APT)"
        echo "${VERDE}  \\___/                       ${RESET} 🐚 ${CYAN}Shell:${RESET}$SHELL_ACTUAL"
        ;;
    bsd|freebsd)
        echo "${ROJO}  \\.-./                        ${RESET} 👤 ${CYAN}Usuario / User:${RESET}$USUARIO"
        echo "${ROJO} /--v--\\ ${RESET} 😈 ${CYAN}Sistema / OS:${RESET} FreeBSD / OpenBSD"
        echo "${ROJO} \\\\___//${RESET} 🐢 ${CYAN}Gestor / PM:${RESET} Bacusp v3.5 (pkg)"
        echo "${ROJO}  `---`                        ${RESET} 🐚 ${CYAN}Shell:${RESET}$SHELL_ACTUAL"
        ;;
    opensuse)
        echo "${VERDE}   \\  /                        ${RESET} 👤 ${CYAN}Usuario / User:${RESET}$USUARIO"
        echo "${VERDE}    \\/--\\ ${RESET} 🦎 ${CYAN}Sistema / OS:${RESET} openSUSE Linux"
        echo "${VERDE}     \\Vert{}\vert{}\vert{}${RESET} 🐢 ${CYAN}Gestor / PM:${RESET} Bacusp v3.5 (Zypper)"
        ;;
    solaris|sunos)
        echo "${AMARILLO}   \\  /                        ${RESET} 👤 ${CYAN}Usuario / User:${RESET}$USUARIO"
        echo "${AMARILLO}    \\/${RESET} ☀️  ${CYAN}Sistema / OS:${RESET} Solaris / Illumos"
        echo "${AMARILLO}    /\\ ${RESET} 🐢 ${CYID}Gestor / PM:${RESET} Bacusp v3.5 (IPS)"
        ;;
    ios)
        echo "${VERDE}   __                         ${RESET} 👤 ${CYAN}Usuario / User:${RESET} $USUARIO"
        echo "${VERDE}  /  \\__                     ${RESET} 📱 ${CYAN}Sistema / OS:${RESET} $NOM_DISTRO"
        echo "${VERDE} (  .  _\\                    ${RESET} 🐢 ${CYAN}Gestor / PM:${RESET} Bacusp v3.5"
        echo "${VERDE}  / __/                      ${RESET} 🐚 ${CYAN}Shell:${RESET} $SHELL_ACTUAL"
        echo "${VERDE} / /                         ${RESET} 🧠 ${CYAN}Arquitectura:${RESET} $ARQ"
        echo "${VERDE} \\/                          ${RESET} 📦 ${CYAN}Paquetes / Pkgs:${RESET} $(pkg list 2>/dev/null | wc -l | tr -d ' ')"
        ;;
    windows)
        echo "${ROJO}   ██████${RESET}  ${VERDE}██████${RESET}           👤 ${CYAN}Usuario / User:${RESET} $USUARIO"
        echo "${ROJO}   ██████${RESET}  ${VERDE}██████${RESET}           🪟 ${CYAN}Sistema / OS:${RESET} $NOM_DISTRO"
        echo "                            🐢 ${CYAN}Gestor / PM:${RESET} Bacusp v3.5 (Winget/Choco)"
        echo "${AZUL}   ██████${RESET}  ${AMARILLO}██████${RESET}           🐚 ${CYAN}Shell:${RESET} $SHELL_ACTUAL"
        echo "${AZUL}   ██████${RESET}  ${AMARILLO}██████${RESET}           🧠 ${CYAN}Arquitectura:${RESET} $ARQ"
        ;;
    haiku)
        echo "${AMARILLO}    @@@@@@@@@@@@      ${RESET} 👤 ${CYAN}Usuario / User:${RESET} $USUARIO"
        echo "${AMARILLO}  @@@@@@@@@@@@@@@@    ${RESET} 🍃 ${CYAN}Sistema / OS:${RESET} $NOM_DISTRO"
        echo "${AMARILLO}    @@@@@@@@@@@@      ${RESET} 🐢 ${CYAN}Gestor / PM:${RESET} Bacusp v3.5 (pkgman)"
        echo "${AMARILLO}      @@@@@@@@@@      ${RESET} 🐚 ${CYAN}Shell:${RESET} $SHELL_ACTUAL"
        echo "${AMARILLO}     @@@@  @@@@       ${RESET} 🧠 ${CYAN}Arquitectura:${RESET} $ARQ"
        ;;
    debian|ubuntu)
        echo "${ROJO}  ______                     ${RESET} 👤 ${CYAN}Usuario / User:${RESET} $USUARIO"
        echo "${ROJO} / ____ \\                    ${RESET} 🌀 ${CYAN}Sistema / OS:${RESET} $NOM_DISTRO"
        echo "${ROJO}| |  | | |                   ${RESET} 🐢 ${CYAN}Gestor / PM:${RESET} Bacusp v3.5 (APT)"
        echo "${ROJO}| |__| | |                   ${RESET} 🐚 ${CYAN}Shell:${RESET} $SHELL_ACTUAL"
        echo "${ROJO} \\______/                    ${RESET} 🧠 ${CYAN}Arquitectura:${RESET} $ARQ"
        ;;
    arch)
        echo "${CYAN}       /\\                    ${RESET} 👤 ${CYAN}Usuario / User:${RESET} $USUARIO"
        echo "${CYAN}      /  \\                   ${RESET} 🏹 ${CYAN}Sistema / OS:${RESET} $NOM_DISTRO"
        echo "${CYAN}     /\\   \\                  ${RESET} 🐢 ${CYAN}Gestor / PM:${RESET} Bacusp v3.5 (Pacman)"
        echo "${CYAN}    /      \\                 ${RESET} 🐚 ${CYAN}Shell:${RESET} $SHELL_ACTUAL"
        echo "${CYAN}   /   ,,   \\                ${RESET} 🧠 ${CYAN}Arquitectura:${RESET} $ARQ"
        echo "${CYAN}  /   |  |  -\\               ${RESET}"
        ;;
    alpine)
        echo "${AZUL}   /\\                        ${RESET} 👤 ${CYAN}Usuario / User:${RESET} $USUARIO"
        echo "${AZUL}  /  \\  /\\                   ${RESET} 🏔️  ${CYAN}Sistema / OS:${RESET} $NOM_DISTRO"
        echo "${AZUL} /    \\/  \\                  ${RESET} 🐢 ${CYAN}Gestor / PM:${RESET} Bacusp v3.5 (APK)"
        echo "${AZUL}/  /\\  \\   \\                 ${RESET} 🐚 ${CYAN}Shell:${RESET} $SHELL_ACTUAL"
        echo "${AZUL}  /  \\  \\   \\                ${RESET} 🧠 ${CYAN}Arquitectura:${RESET} $ARQ"
        ;;
    fedora)
        echo "${AMARILLO}      _____                  ${RESET} 👤 ${CYAN}Usuario / User:${RESET} $USUARIO"
        echo "${AMARILLO}     / ___/                  ${RESET} 🎩 ${CYAN}Sistema / OS:${RESET} $NOM_DISTRO"
        echo "${AMARILLO}    / /__                    ${RESET} 🐢 ${CYAN}Gestor / PM:${RESET} Bacusp v3.5 (DNF)"
        echo "${AMARILLO}   / ___/                    ${RESET} 🐚 ${CYAN}Shell:${RESET} $SHELL_ACTUAL"
        echo "${AMARILLO}  /_/                        ${RESET} 🧠 ${CYAN}Arquitectura:${RESET} $ARQ"
        ;;
    *)
        echo "${MAGENTA}   /\\_/\\                     ${RESET} 👤 ${CYAN}Usuario / User:${RESET} $USUARIO"
        echo "${MAGENTA}  ( o.o )                    ${RESET} 🐧 ${CYAN}Sistema / OS:${RESET} $NOM_DISTRO"
        echo "${MAGENTA}   > ^ <                     ${RESET} 🐢 ${CYAN}Gestor / PM:${RESET} Bacusp v3.5"
        ;;
esac
echo ""
