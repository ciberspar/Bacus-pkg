#!/bin/sh
# ======================================================
#  Módulo Friends - BACUSP v5.1 Pure Standalone 🐢🤝
#  Creador: ciberspar
#  Descripción: Red social y de repositorios amigos para Bacusp
# ======================================================

CYAN='\033[1;36m'
VERDE='\033[1;32m'
AMARILLO='\033[1;33m'
ROJO='\033[1;31m'
MAGENTA='\033[1;35m'
RESET='\033[0m'

FRIENDS_FILE="$HOME/.bacusp/friends.list"
ACCION=$1
AMIGO=$2

mkdir -p "$HOME/.bacusp"

case "$ACCION" in
    add|agregar)
        if [ -n "$AMIGO" ]; then
            if grep -qxF "$AMIGO" "$FRIENDS_FILE" 2>/dev/null; then
                echo "${AMARILLO}⚠️ ¡$AMIGO ya es amigo de Bacusp!${RESET}"
            else
                echo "$AMIGO" >> "$FRIENDS_FILE"
                # Automáticamente lo agrega a los repos si existe el script repo.sh
                [ -f "$(dirname "$0")/repo.sh" ] && sh "$(dirname "$0")/repo.sh" add "https://github.com/$AMIGO/bacus-pkg"
                echo "${VERDE}✨ ¡Nuevo vínculo establecido! '$AMIGO' ahora es amigo de Bacusp. 🐢❤️${RESET}"
            fi
        else
            echo "${ROJO}❌ Error: Especificá el usuario de GitHub de tu amigo.${RESET}"
            echo "Ejemplo: bacusp friends add ciberspar"
        fi
        ;;

    remove|borrar|rm)
        if [ -n "$AMIGO" ] && [ -f "$FRIENDS_FILE" ]; then
            grep -vF "$AMIGO" "$FRIENDS_FILE" > "$FRIENDS_FILE.tmp" && mv "$FRIENDS_FILE.tmp" "$FRIENDS_FILE"
            echo "${VERDE}🗑️ '$AMIGO' fue eliminado de la lista de amigos.${RESET}"
        else
            echo "${ROJO}❌ Error: Especificá el amigo a remover.${RESET}"
        fi
        ;;

    greet|saludar)
        echo "${MAGENTA}🐢💬 ¡Hola! Bacusp manda saludos a todos los repositorios y creadores de la red decentralizada.${RESET}"
        if [ -f "$FRIENDS_FILE" ] && [ -s "$FRIENDS_FILE" ]; then
            echo "${CYAN}Amigos conectados actualmente:${RESET}"
            cat "$FRIENDS_FILE" | awk '{print "  - 🌟 " $0}'
        else
            echo "${AMARILLO}Todavía no hay amigos en la red. ¡Agregá uno con 'bacusp friends add <usuario>'!${RESET}"
        fi
        ;;

    list|listar|*)
        echo ""
        echo "${CYAN}🤝 [Bacusp Friends Network] Red de Repos Amigos:${RESET}"
        echo "${CYAN}------------------------------------------------------${RESET}"
        if [ -f "$FRIENDS_FILE" ] && [ -s "$FRIENDS_FILE" ]; then
            cat "$FRIENDS_FILE" | awk '{print "  👤 Desarrollador/Nodo: " $0}'
        else
            echo "  (No hay amigos registrados todavía. ¡Haz que Bacusp conozca gente!)"
        fi
        echo "${CYAN}------------------------------------------------------${RESET}"
        echo ""
        ;;
es:
