#!/bin/sh
# ======================================================
#  Módulo Repo - BACUSP v5.1 Pure Standalone 🐢🌐
#  Creador: ciberspar
#  Descripción: Gestión de repositorios comunitarios y oficiales
# ======================================================

CYAN='\033[1;36m'; VERDE='\033[1;32m'; AMARILLO='\033[1;33m'; RESET='\033[0m'
REPOS_FILE="$HOME/.bacusp/repos.list"

ACCION=$1
URL=$2

mkdir -p "$HOME/.bacusp"

case "$ACCION" in
    add|agregar)
        if [ -n "$URL" ]; then
            echo "$URL" >> "$REPOS_FILE"
            echo "${VERDE}✅ Repositorio añadido a ~/.bacusp/repos.list: $URL${RESET}"
        else
            echo "${AMARILLO}⚠️ Especificá la URL del repositorio.${RESET}"
        fi
        ;;
    list|listar|*)
        echo "${CYAN}🌐 Repositorios registrados en Bacusp:${RESET}"
        if [ -f "$REPOS_FILE" ]; then
            cat "$REPOS_FILE" | awk '{print "  - " $0}'
        else
            echo "  - https://api.github.com (Default Official GitHub Index)"
        fi
        ;;
esac
