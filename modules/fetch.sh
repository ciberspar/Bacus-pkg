#!/bin/sh
# ======================================================
#  Módulo Fetch Universal - bacusp v5.0 Pure Standalone 🐢🐧📱🪟🎨
#  Creador: ciberspar
# ======================================================

# Colores ANSI
VERDE='\033[1;32m'
AZUL='\033[1;34m'
CYAN='\033[1;36m'
ROJO='\033[1;31m'
MAGENTA='\033[1;35m'
AMARILLO='\033[1;33m'
RESET='\033[0m'

# Ruta de la base de datos autónoma de Bacusp
DB_FILE="$HOME/.bacusp/installed.db"

# --- DETECCIÓN DE DISTRO / OS ---
if [ -d "/kolibrios" ] || uname -m 2>/dev/null | grep -qi "kolibri"; then
    DISTRO="kolibrios"
    NOM_DISTRO="KolibriOS (Assembly Nativo)"
elif command -v pkg >/dev/null 2>&1 && [ ! -d "/data/data/com.termux" ]; then
    DISTRO="ios"
    NOM_DISTRO="chiquiOS / iOS Sandbox"
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
    NOM_DISTRO="$(uname -s 2>/dev/null || echo 'Generic') POSIX"
fi

USUARIO=$(whoami 2>/dev/null || echo "user")
SHELL_ACTUAL=$(basename "$SHELL" 2>/dev/null || echo "sh")
ARQ=$(uname -m 2>/dev/null || echo "unknown")

# Contar paquetes instalados en la DB propia de Bacusp
if [ -f "$DB_FILE" ]; then
    PKGS_BACUSP=$(wc -l < "$DB_FILE" | tr -d ' ')
else
    PKGS_BACUSP="0"
fi

echo ""
case "$DISTRO" in
    kolibrios)
        echo "${CYAN}     __                     ${RESET} 👤 ${CYAN}Usuario / User:${RESET} $USUARIO"
        echo "${CYAN}   / \`  )                   ${RESET} 🪶 ${CYAN}Sistema / OS:${RESET}$NOM_DISTRO"
        echo "${CYAN}  (   /___${RESET} 🐢 ${CYAN}Gestor / PM:${RESET} Bacusp v5.0 (Pure Standalone)"
        echo "${CYAN}   \\____.-'${RESET} ⚡ ${CYAN}Núcleo:${RESET} 100% Assembly / RAM Exec"
        echo "${CYAN}                            ${RESET} 📦 ${CYAN}Paquetes DB:${RESET}$PKGS_BACUSP"
        ;;
    hurd)
        echo "${CYAN}    _____                      ${RESET} 👤 ${CYAN}Usuario / User:${RESET}$USUARIO"
        echo "${CYAN}   / ___ \\ ${RESET} 🧬 ${CYAN}Sistema / OS:${RESET} GNU/Hurd (Microkernel)"
        echo "${CYAN}  \vert{} \vert{}   \vert{} \vert{}${RESET} 🐢 ${CYAN}Gestor / PM:${RESET} Bacusp v5.0 (Autonomous)"
        echo "${CYAN}                               ${RESET} 📦 ${CYAN}Paquetes DB:${RESET}$PKGS_BACUSP"
        ;;
    minix)
        echo "${AMARILLO}   _  _                       ${RESET} 👤 ${CYAN}Usuario / User:${RESET}$USUARIO"
        echo "${AMARILLO}  \vert{} \vert{}\vert{} \vert{}${RESET} 📚 ${CYAN}Sistema / OS:${RESET} Minix OS (Tanenbaum)"
        echo "${AMARILLO}  \vert{} \vert{}\vert{} \vert{}_${RESET} 🐢 ${CYAN}Gestor / PM:${RESET} Bacusp v5.0 (Autonomous)"
        echo "${AMARILLO}                              ${RESET} 📦 ${CYAN}Paquetes DB:${RESET}$PKGS_BACUSP"
        ;;
    serenity)
        echo "${MAGENTA}   ╔══════╗                   ${RESET} 👤 ${CYAN}Usuario / User:${RESET}$USUARIO"
        echo "${MAGENTA}   ║ 90s  ║${RESET} 🖥️  ${CYAN}Sistema / OS:${RESET} SerenityOS (Retro 90s)"
        echo "${MAGENTA}   ╚══════╝                   ${RESET} 🐢 ${CYAN}Gestor / PM:${RESET} Bacusp v5.0 (Autonomous)"
        echo "${MAGENTA}                              ${RESET} 📦 ${CYAN}Paquetes DB:${RESET}$PKGS_BACUSP"
        ;;
    plan9)
        echo "${AZUL}   ___                        ${RESET} 👤 ${CYAN}Usuario / User:${RESET}$USUARIO"
        echo "${AZUL}  / _ \\ ${RESET} 🌌 ${CYAN}Sistema / OS:${RESET} Plan 9 from Bell Labs"
        echo "${AZUL} \vert{} (_) \vert{}${RESET} 🐢 ${CYAN}Gestor / PM:${RESET} Bacusp v5.0 (Autonomous)"
        echo "${AZUL}                              ${RESET} 📦 ${CYAN}Paquetes DB:${RESET}$PKGS_BACUSP"
        ;;
    termux)
        echo "${VERDE}   ___                        ${RESET} 👤 ${CYAN}Usuario / User:${RESET}$USUARIO"
        echo "${VERDE}  /   \\ ${RESET} 📱 ${CYAN}Sistema / OS:${RESET} Termux (Android)"
        echo "${VERDE} \vert{} o o \vert{}${RESET} 🐢 ${CYAN}Gestor / PM:${RESET} Bacusp v5.0 (Standalone)"
        echo "${VERDE}  \\___/                       ${RESET} 🐚 ${CYAN}Shell:${RESET}$SHELL_ACTUAL"
        echo "${VERDE}                              ${RESET} 📦 ${CYAN}Paquetes DB:${RESET}$PKGS_BACUSP"
        ;;
    bsd|freebsd|openbsd)
        echo "${ROJO}  \\.-./                        ${RESET} 👤 ${CYAN}Usuario / User:${RESET}$USUARIO"
        echo "${ROJO} /--v--\\ ${RESET} 😈 ${CYAN}Sistema / OS:${RESET} FreeBSD / OpenBSD"
        echo "${ROJO} \\\\___//${RESET} 🐢 ${CYAN}Gestor / PM:${RESET} Bacusp v5.0 (Standalone)"
        echo "${ROJO}  \`---\`                        ${RESET} 🐚 ${CYAN}Shell:${RESET}$SHELL_ACTUAL"
        echo "${ROJO}                              ${RESET} 📦 ${CYAN}Paquetes DB:${RESET}$PKGS_BACUSP"
        ;;
    opensuse)
        echo "${VERDE}   \\  /                        ${RESET} 👤 ${CYAN}Usuario / User:${RESET}$USUARIO"
        echo "${VERDE}    \\/--\\ ${RESET} 🦎 ${CYAN}Sistema / OS:${RESET} openSUSE Linux"
        echo "${VERDE}     \\Vert{}\vert{}\vert{}${RESET} 🐢 ${CYAN}Gestor / PM:${RESET} Bacusp v5.0 (Standalone)"
        echo "${VERDE}                              ${RESET} 📦 ${CYAN}Paquetes DB:${RESET}$PKGS_BACUSP"
        ;;
    solaris|sunos)
        echo "${AMARILLO}   \\  /                        ${RESET} 👤 ${CYAN}Usuario / User:${RESET}$USUARIO"
        echo "${AMARILLO}    \\/${RESET} ☀️  ${CYAN}Sistema / OS:${RESET} Solaris / Illumos"
        echo "${AMARILLO}    /\\ ${RESET} 🐢 ${CYAN}Gestor / PM:${RESET} Bacusp v5.0 (Standalone)"
        echo "${AMARILLO}                              ${RESET} 📦 ${CYAN}Paquetes DB:${RESET}$PKGS_BACUSP"
        ;;
    ios)
        echo "${VERDE}   __                         ${RESET} 👤 ${CYAN}Usuario / User:${RESET}$USUARIO"
        echo "${VERDE}  /  \\__                     ${RESET} 📱 ${CYAN}Sistema / OS:${RESET}$NOM_DISTRO"
        echo "${VERDE} (  .  _\\ ${RESET} 🐢 ${CYAN}Gestor / PM:${RESET} Bacusp v5.0 (Standalone)"
        echo "${VERDE}  / __/                      ${RESET} 🐚 ${CYAN}Shell:${RESET}$SHELL_ACTUAL"
        echo "${VERDE} / /                         ${RESET} 🧠 ${CYAN}Arquitectura:${RESET}$ARQ"
        echo "${VERDE} \\/                          ${RESET} 📦 ${CYAN}Paquetes DB:${RESET}$PKGS_BACUSP"
        ;;
    windows)
        echo "${ROJO}   ██████${RESET}${VERDE}██████${RESET}           👤 ${CYAN}Usuario / User:${RESET}$USUARIO"
        echo "${ROJO}   ██████${RESET}${VERDE}██████${RESET}           🪟 ${CYAN}Sistema / OS:${RESET}$NOM_DISTRO"
        echo "                            🐢 ${CYAN}Gestor / PM:${RESET} Bacusp v5.0 (Standalone)"
        echo "${AZUL}   ██████${RESET}${AMARILLO}██████${RESET}           🐚 ${CYAN}Shell:${RESET}$SHELL_ACTUAL"
        echo "${AZUL}   ██████${RESET}${AMARILLO}██████${RESET}           🧠 ${CYAN}Arquitectura:${RESET}$ARQ"
        echo "                            📦 ${CYAN}Paquetes DB:${RESET}$PKGS_BACUSP"
        ;;
    haiku)
        echo "${AMARILLO}    @@@@@@@@@@@@      ${RESET} 👤 ${CYAN}Usuario / User:${RESET}$USUARIO"
        echo "${AMARILLO}  @@@@@@@@@@@@@@@@    ${RESET} 🍃 ${CYAN}Sistema / OS:${RESET}$NOM_DISTRO"
        echo "${AMARILLO}    @@@@@@@@@@@@      ${RESET} 🐢 ${CYAN}Gestor / PM:${RESET} Bacusp v5.0 (Standalone)"
        echo "${AMARILLO}      @@@@@@@@@@      ${RESET} 🐚 ${CYAN}Shell:${RESET}$SHELL_ACTUAL"
        echo "${AMARILLO}     @@@@  @@@@       ${RESET} 🧠 ${CYAN}Arquitectura:${RESET}$ARQ"
        echo "${AMARILLO}                      ${RESET} 📦 ${CYAN}Paquetes DB:${RESET}$PKGS_BACUSP"
        ;;
    debian|ubuntu)
        echo "${ROJO}  ______                     ${RESET} 👤 ${CYAN}Usuario / User:${RESET}$USUARIO"
        echo "${ROJO} / ____ \\                    ${RESET} 🌀 ${CYAN}Sistema / OS:${RESET}$NOM_DISTRO"
        echo "${ROJO}\vert{} \vert{}  \vert{} \vert{} \vert{}${RESET} 🐢 ${CYAN}Gestor / PM:${RESET} Bacusp v5.0 (Standalone)"
        echo "${ROJO}| |__| | |                   ${RESET} 🐚 ${CYAN}Shell:${RESET}$SHELL_ACTUAL"
        echo "${ROJO} \\______/                    ${RESET} 🧠 ${CYAN}Arquitectura:${RESET}$ARQ"
        echo "${ROJO}                             ${RESET} 📦 ${CYAN}Paquetes DB:${RESET}$PKGS_BACUSP"
        ;;
    arch)
        echo "${CYAN}       /\\                    ${RESET} 👤 ${CYAN}Usuario / User:${RESET}$USUARIO"
        echo "${CYAN}      /  \\                   ${RESET} 🏹 ${CYAN}Sistema / OS:${RESET}$NOM_DISTRO"
        echo "${CYAN}     /\\   \\ ${RESET} 🐢 ${CYAN}Gestor / PM:${RESET} Bacusp v5.0 (Standalone)"
        echo "${CYAN}    /      \\                 ${RESET} 🐚 ${CYAN}Shell:${RESET}$SHELL_ACTUAL"
        echo "${CYAN}   /   ,,   \\                ${RESET} 🧠 ${CYAN}Arquitectura:${RESET}$ARQ"
        echo "${CYAN}  /   |  |  -\\               ${RESET} 📦 ${CYAN}Paquetes DB:${RESET}$PKGS_BACUSP"
        ;;
    alpine)
        echo "${AZUL}   /\\                        ${RESET} 👤 ${CYAN}Usuario / User:${RESET}$USUARIO"
        echo "${AZUL}  /  \\  /\\                   ${RESET} 🏔️  ${CYAN}Sistema / OS:${RESET}$NOM_DISTRO"
        echo "${AZUL} /    \\/  \\ ${RESET} 🐢 ${CYAN}Gestor / PM:${RESET} Bacusp v5.0 (Standalone)"
        echo "${AZUL}/  /\\  \\   \\                 ${RESET} 🐚 ${CYAN}Shell:${RESET}$SHELL_ACTUAL"
        echo "${AZUL}  /  \\  \\   \\                ${RESET} 🧠 ${CYAN}Arquitectura:${RESET}$ARQ"
        echo "${AZUL}                             ${RESET} 📦 ${CYAN}Paquetes DB:${RESET}$PKGS_BACUSP"
        ;;
    fedora)
        echo "${AMARILLO}      _____                  ${RESET} 👤 ${CYAN}Usuario / User:${RESET}$USUARIO"
        echo "${AMARILLO}     / ___/                  ${RESET} 🎩 ${CYAN}Sistema / OS:${RESET}$NOM_DISTRO"
        echo "${AMARILLO}    / /__${RESET} 🐢 ${CYAN}Gestor / PM:${RESET} Bacusp v5.0 (Standalone)"
        echo "${AMARILLO}   / ___/                    ${RESET} 🐚 ${CYAN}Shell:${RESET}$SHELL_ACTUAL"
        echo "${AMARILLO}  /_/                        ${RESET} 🧠 ${CYAN}Arquitectura:${RESET}$ARQ"
        echo "${AMARILLO}                             ${RESET} 📦 ${CYAN}Paquetes DB:${RESET}$PKGS_BACUSP"
        ;;
    *)
        echo "${MAGENTA}   /\\_/\\                     ${RESET} 👤 ${CYAN}Usuario / User:${RESET}$USUARIO"
        echo "${MAGENTA}  ( o.o )                    ${RESET} 🐧 ${CYAN}Sistema / OS:${RESET}$NOM_DISTRO"
        echo "${MAGENTA}   > ^ <${RESET} 🐢 ${CYAN}Gestor / PM:${RESET} Bacusp v5.0 (Standalone)"
        echo "${MAGENTA}                             ${RESET} 📦 ${CYAN}Paquetes DB:${RESET}$PKGS_BACUSP"
        ;;
esac
echo ""
