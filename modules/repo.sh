#!/bin/sh
# ======================================================
#  Módulo Repo - BACUSP v5.1 Pure Standalone 🐢🌐
#  Creador: ciberspar
#  Descripción: Gestión flexible de repositorios y fuentes
# ======================================================

CYAN='\033[1;36m'
VERDE='\033[1;32m'
AMARILLO='\033[1;33m'
ROJO='\033[1;31m'
RESET='\033[0m'

REPOS_FILE="$HOME/.bacusp/repos.list"
ACCION=$1
PARAM=$2

mkdir -p "$HOME/.bacusp"

case "$ACCION" in
    add|agregar)
        if [ -n "$PARAM" ]; then
            # Verificar si ya existe para no duplicar
            if grep -qxF "$PARAM" "$REPOS_FILE" 2>/dev/null; then
                echo "${AMARILLO}⚠️ El repositorio ya está en la lista: $PARAM${RESET}"
            else
                echo "$PARAM" >> "$REPOS_FILE"
                echo "${VERDE}✅ Repositorio añadido a ~/.bacusp/repos.list:${RESET} $PARAM"
            fi
        else
            echo "${ROJO}❌ Error: Especificá la URL del repositorio / Specify repo URL.${RESET}"
            echo "Ejemplo: bacusp repo add https://github.com/mi-usuario/mi-repo-bacusp"
        fi
        ;;

    remove|borrar|rm)
        if [ -n "$PARAM" ] && [ -f "$REPOS_FILE" ]; then
            grep -vF "$PARAM" "$REPOS_FILE" > "$REPOS_FILE.tmp" && mv "$REPOS_FILE.tmp" "$REPOS_FILE"
            echo "${VERDE}🗑️ Repositorio eliminado de la lista.${RESET}"
        else
            echo "${ROJO}❌ Error: Especificá la URL o repo a eliminar.${RESET}"
        fi
        ;;

    list|listar|*)
        echo ""
        echo "${CYAN}🌐 [Bacusp Repository Index] Repositorios registrados:${RESET}"
        echo "${CYAN}------------------------------------------------------${RESET}"
        if [ -f "$REPOS_FILE" ] && [ -s "$REPOS_FILE" ]; then
            cat "$REPOS_FILE" | awk '{print "  - " $0}'
        else
            echo "  - https://api.github.com (Default Official GitHub Index)"
        fi
        echo "${CYAN}------------------------------------------------------${RESET}"
        echo ""
        ;;
esac
