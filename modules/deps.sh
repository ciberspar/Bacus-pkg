#!/bin/sh
# ======================================================
#  Módulo Deps - BACUSP v5.1 Pure Standalone 🐢🔗
#  Creador: ciberspar
#  Descripción: Verificador y resolvedor de dependencias
# ======================================================

CYAN='\033[1;36m'; VERDE='\033[1;32m'; AMARILLO='\033[1;33m'; RESET='\033[0m'
PAQ=$1

echo "${CYAN}🔗 [Bacusp Dependency Engine] Analizando prerequisitos para '$PAQ'...${RESET}"

# Herramientas fundamentales para compilar e instalar
HERRAMIENTAS_BASE="git curl make"

echo "${VERDE}🔍 Verificando herramientas de construcción base:${RESET}"
for tool in $HERRAMIENTAS_BASE; do
    if command -v "$tool" >/dev/null 2>&1; then
        echo "  - $tool: OK"
    else
        echo "  - ${AMARILLO}$tool: NO DETECTADO (Podría requerirse para compilar)${RESET}"
    fi
done

# Verificación de librerías en caché si existe el paquete en construcción
CACHE_BUILD="$HOME/.bacusp/cache/build_$PAQ"
if [ -d "$CACHE_BUILD" ]; then
    if [ -f "$CACHE_BUILD/depends.txt" ]; then
        echo "${VERDE}📋 Lista de dependencias detectada en $PAQ:${RESET}"
        cat "$CACHE_BUILD/depends.txt"
    fi
fi
