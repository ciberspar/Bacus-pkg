#!/bin/sh
# ======================================================
#  BACUSP MODULE: STORE GUI (TUI Dinámico por Repos) 🏪🎨
#  Creador: ciberspar
#  Descripción: Escanea los repositorios configurados del
#               usuario y muestra todas las apps disponibles.
# ======================================================

cmd_store_gui() {
    REPOS_FILE="$HOME/.bacusp/repos.list"
    ALL_APPS_FILE="$HOME/.bacusp/all_apps_cache.db"

    mkdir -p "$HOME/.bacusp" 2>/dev/null
    > "$ALL_APPS_FILE" # Limpiar la caché temporal de apps

    echo "🔄 Escaneando aplicaciones de todos los repositorios configurados..."

    # 1. Si no existe repos.list, agregamos el repo oficial por defecto
    if [ ! -f "$REPOS_FILE" ] || [ ! -s "$REPOS_FILE" ]; then
        echo "https://raw.githubusercontent.com/ciberspar/bacus-pkg/main/store/apps.db" > "$REPOS_FILE"
    fi

    # 2. Descargar y combinar el catálogo de CADA repositorio guardado
    while IFS= read -r REPO_URL || [ -n "$REPO_URL" ]; do
        # Omitir líneas vacías o comentarios
        case "$REPO_URL" in
            \#*|"") continue ;;
        esac

        if command -v curl >/dev/null 2>&1; then
            curl -s "$REPO_URL" >> "$ALL_APPS_FILE" 2>/dev/null
        elif command -v wget >/dev/null 2>&1; then
            wget -q -O - "$REPO_URL" >> "$ALL_APPS_FILE" 2>/dev/null
        fi
        echo "" >> "$ALL_APPS_FILE"
    done < "$REPOS_FILE"

    # 3. Eliminar duplicados o líneas vacías/comentarios
    grep -v "^#" "$ALL_APPS_FILE" | grep -v "^$" | sort -u > "${ALL_APPS_FILE}.clean"
    mv "${ALL_APPS_FILE}.clean" "$ALL_APPS_FILE"

    # 4. Mostrar la interfaz TUI con las apps de TODOS los repositorios
    if command -v whiptail >/dev/null 2>&1; then
        APPS=$(awk -F'|' 'NF >= 5 {print $1 " \"" $5 " (" $2 ")\""}' "$ALL_APPS_FILE")
        
        if [ -z "$APPS" ]; then
            whiptail --title "🏪 BACUSP STORE TUI" --msgbox "No se encontraron aplicaciones en tus repositorios configurados." 10 60
            return 0
        fi

        CHOICE=$(eval whiptail --title \"🏪 BACUSP STORE - TODOS TUS REPOS\" \
            --menu \"Seleccioná una app instalable:\" 20 75 10 $APPS \
            3>&1 1>&2 2>&3)

        if [ -n "$CHOICE" ]; then
            echo "🚀 Instalando $CHOICE desde tus repositorios..."
            bacusp install "$CHOICE"
        fi
    else
        # Fallback TUI POSIX puro para la terminal
        clear
        echo "=========================================================="
        echo "   🏪 BACUSP APP STORE TUI - APPS DE TUS REPOS "
        echo "=========================================================="
        echo ""

        if [ -s "$ALL_APPS_FILE" ]; then
            awk -F'|' 'NF >= 5 {printf "  🟢 [%-12s] %-12s - %s\n", $1, $2, $5}' "$ALL_APPS_FILE"
        else
            echo "⚠️ No se encontraron aplicaciones en los repositorios agregados."
        fi

        echo ""
        echo "=========================================================="
        printf "👉 Escribí el ID de la app que querés instalar (o 'q' para salir): "
        read -r SELECTION

        if [ "$SELECTION" != "q" ] && [ -n "$SELECTION" ]; then
            bacusp install "$SELECTION"
        fi
    fi
}
