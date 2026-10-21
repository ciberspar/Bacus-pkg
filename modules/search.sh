#!/bin/sh
# ======================================================
#  Módulo Search - BACUSP v5.1 Dual-Lang Engine 🐢🔍
#  Creador: ciberspar
#  Descripción: Búsqueda interactiva de paquetes y repositorios
# ======================================================

CYAN='\033[1;36m'
VERDE='\033[1;32m'
ROJO='\033[1;31m'
AMARILLO='\033[1;33m'
RESET='\033[0m'

QUERY=$1

if [ -z "$QUERY" ]; then
    echo "${ROJO}❌ Error: Especificá qué querés buscar / Specify a search term.${RESET}"
    echo "Ejemplo / Example: bacusp search htop"
    exit 1
fi

echo ""
echo "${CYAN}🔍 [Bacusp Search Engine] Buscando '$QUERY' en el registro y GitHub...${RESET}"
echo "${CYAN}------------------------------------------------------${RESET}"

# 1. Buscar primero en la base de datos local instalada (~/.bacusp/installed.db)
DB_FILE="$HOME/.bacusp/installed.db"
if [ -f "$DB_FILE" ]; then
    ENCONTRADO_LOCAL=$(grep -i "$QUERY" "$DB_FILE")
    if [ -n "$ENCONTRADO_LOCAL" ]; then
        echo "${VERDE}📦 [Instalado localmente / Locally installed]:${RESET}"
        echo "$ENCONTRADO_LOCAL" | awk -F'|' '{print "  - " $1 " (Ruta: " $2 ")"}'
        echo ""
    fi
fi

# 2. Buscar en la API de GitHub repositorios relacionados
if command -v curl >/dev/null 2>&1; then
    echo "${AZUL}🌐 Consultando repositorios públicos en GitHub...${RESET}"
    API_RESULT=$(curl -s "https://api.github.com/search/repositories?q=$QUERY+sort:stars" | grep -E '"full_name":|"description":' | head -n 6)
    
    if [ -n "$API_RESULT" ]; then
        echo "${VERDE}✨ Resultados sugeridos de la comunidad:${RESET}"
        echo "$API_RESULT" | sed 's/"full_name":/  📁 Repo:/g' | sed 's/"description":/     📝 Desc:/g' | tr -d '"' | tr -d ','
    else
        echo "${AMARILLO}⚠️ No se encontraron resultados en la API remota.${RESET}"
    fi
else
    echo "${AMARILLO}⚠️ 'curl' no está disponible para realizar la búsqueda web.${RESET}"
fi

echo "${CYAN}------------------------------------------------------${RESET}"
echo ""
