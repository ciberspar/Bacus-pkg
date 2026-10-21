#!/bin/sh
# ======================================================
#  Módulo Upgrade - BACUSP v5.1 Dual-Lang Engine 🐢🔄
#  Creador: ciberspar
# ======================================================

VERDE='\033[1;32m'
AZUL='\033[1;34m'
CYAN='\033[1;36m'
ROJO='\033[1;31m'
AMARILLO='\033[1;33m'
RESET='\033[0m'

echo ""
echo "${CYAN}======================================================${RESET}"
echo "${VERDE}  🐢 BACUSP System & Core Upgrade Engine${RESET}"
echo "${CYAN}======================================================${RESET}"
echo ""

# 1. ACTUALIZACIÓN DEL NÚCLEO DE BACUSP
echo "${AZUL}🔄 [1/2] Verificando actualizaciones del núcleo de Bacusp...${RESET}"
BACUSP_DIR="$(cd "$(dirname "$0")/.." && pwd)"

if [ -d "$BACUSP_DIR/.git" ]; then
    SALIDA_GIT=$(cd "$BACUSP_DIR" && git pull origin main 2>/dev/null || cd "$BACUSP_DIR" && git pull origin master 2>/dev/null)
    if echo "$SALIDA_GIT" | grep -qi "Already up to date"; then
        echo "${VERDE}  ✨ El núcleo de Bacusp ya está en su última versión.${RESET}"
    elif [ -n "$SALIDA_GIT" ]; then
        echo "${VERDE}  ✅ Bacusp actualizado con éxito.${RESET}"
    else
        echo "${AMARILLO}  ⚠️ No se pudo conectar con el repositorio remoto de GitHub.${RESET}"
    fi
else
    echo "${AMARILLO}  ⚠️ No se detectó repositorio git. Bacusp opera en modo local estático.${RESET}"
fi

echo ""

# 2. ACTUALIZACIÓN DEL SISTEMA BASE (SI EXISTE GESTOR NATIVO)
echo "${AZUL}🖥️  [2/2] Verificando actualizaciones del Sistema Operativo...${RESET}"

ACTUALIZADO=0
case "$ENTORNO" in
    debian|ubuntu)
        if command -v apt-get >/dev/null 2>&1; then
            sudo apt-get update
            UPGRADABLES=$(apt-get -s upgrade 2>/dev/null | grep -i "upgraded,")
            echo "  $UPGRADABLES"
            sudo apt-get upgrade -y
            ACTUALIZADO=1
        fi
        ;;
    arch)
        if command -v pacman >/dev/null 2>&1; then
            sudo pacman -Sy
            sudo pacman -Syu --noconfirm
            ACTUALIZADO=1
        fi
        ;;
    alpine)
        if command -v apk >/dev/null 2>&1; then
            apk update && apk upgrade
            ACTUALIZADO=1
        fi
        ;;
    fedora)
        if command -v dnf >/dev/null 2>&1; then
            sudo dnf check-update
            sudo dnf upgrade -y
            ACTUALIZADO=1
        fi
        ;;
    opensuse)
        if command -v zypper >/dev/null 2>&1; then
            sudo zypper refresh
            sudo zypper update -y
            ACTUALIZADO=1
        fi
        ;;
    ios|termux)
        if command -v pkg >/dev/null 2>&1; then
            pkg upgrade -y 2>/dev/null
            ACTUALIZADO=1
        fi
        ;;
esac

if [ "$ACTUALIZADO" -eq 0 ]; then
    echo "${VERDE}  ✨ El sistema está al día o opera en Pure Standalone sin gestor nativo.${RESET}"
else
    echo "${VERDE}  ✨ Proceso de actualización finalizado.${RESET}"
fi
echo ""
