
#!/bin/sh
# ======================================================
# BACUSP MODULE: STORE TUI
# Project: Bacus-Pkg
# Author: ciberspar
# POSIX shell - keyboard-driven terminal interface
# ======================================================

set -u
umask 077

cmd_store_tui() (
    BACUSP_HOME=${BACUSP_HOME:-"$HOME/.bacusp"}
    REPOS_FILE="$BACUSP_HOME/repos.list"
    CACHE_FILE="$BACUSP_HOME/all_apps_cache.db"
    TMP_FILE="$BACUSP_HOME/store.$$"
    FETCH_FILE="$BACUSP_HOME/fetch.$$"

    cleanup() {
        rm -f "$TMP_FILE" "$FETCH_FILE"
    }
    trap cleanup EXIT HUP INT TERM

    error() {
        printf 'Error: %s\n' "$*" >&2
    }

    valid_id() {
        case "$1" in
            ''|.|..|[!A-Za-z0-9]*|*[!A-Za-z0-9._+-]*)
                return 1
                ;;
            *)
                return 0
                ;;
        esac
    }

    mkdir -p "$BACUSP_HOME" || {
        error "No se pudo crear BACUSP_HOME"
        exit 1
    }

    : > "$TMP_FILE" || {
        error "No se pudo crear el catálogo temporal"
        exit 1
    }

    if [ ! -s "$REPOS_FILE" ]; then
        printf '%s\n' \
          'https://raw.githubusercontent.com/ciberspar/bacus-pkg/main/store/apps.db' \
          > "$REPOS_FILE" || {
            error "No se pudo crear repos.list"
            exit 1
        }
    fi

    printf '%s\n' 'Bacus Store: buscando aplicaciones...'

    if ! command -v curl >/dev/null 2>&1 &&
       ! command -v wget >/dev/null 2>&1; then
        error "Se necesita curl o wget para consultar repositorios"
        exit 1
    fi

    while IFS= read -r repo_url || [ -n "$repo_url" ]; do
        case "$repo_url" in
            ''|\#*) continue ;;
            https://*) ;;
            *)
                printf 'Repositorio omitido (solo HTTPS): %s\n' \
                    "$repo_url" >&2
                continue
                ;;
        esac

        : > "$FETCH_FILE" || exit 1

        if command -v curl >/dev/null 2>&1; then
            if ! curl --fail --location --silent --show-error \
                --max-time 20 "$repo_url" -o "$FETCH_FILE"; then
                printf 'No se pudo consultar: %s\n' "$repo_url" >&2
                continue
            fi
        else
            if ! wget -q -T 20 -O "$FETCH_FILE" "$repo_url"; then
                printf 'No se pudo consultar: %s\n' "$repo_url" >&2
                continue
            fi
        fi

        # Expected catalog format:
        # id|version|field3|field4|description
        # Validate identifiers and require at least five fields.
        awk -F '|' '
            NF >= 5 &&
            $1 != "" &&
            $1 != "." &&
            $1 != ".." &&
            $1 !~ /[^A-Za-z0-9._+-]/ &&
            $1 !~ /^[^A-Za-z0-9]/ {
                print $0
            }
        ' "$FETCH_FILE" >> "$TMP_FILE" || exit 1

    done < "$REPOS_FILE"

    # Deduplicate records without interpreting catalog values as commands.
    sort -u "$TMP_FILE" > "$FETCH_FILE" || {
        error "No se pudo ordenar el catálogo"
        exit 1
    }
    mv "$FETCH_FILE" "$TMP_FILE" || exit 1

    cp "$TMP_FILE" "$CACHE_FILE" || {
        error "No se pudo guardar la caché"
        exit 1
    }

    printf '\n========================================\n'
    printf '          BACUS STORE TUI\n'
    printf '========================================\n'
    printf '  Paquetes disponibles:\n\n'

    COUNT=0
    while IFS='|' read -r id version field3 field4 description rest ||
          [ -n "${id:-}" ]; do
        [ -n "${id:-}" ] || continue
        COUNT=$((COUNT + 1))
        printf '  %s) %s - %s\n' "$COUNT" "$id" "$description"
    done < "$TMP_FILE"

    if [ "$COUNT" -eq 0 ]; then
        printf '\nNo hay paquetes válidos disponibles.\n'
        printf 'Revisá los repositorios y su formato.\n'
        exit 0
    fi

    printf '\n  r) Recargar catálogo\n'
    printf '  q) Salir\n'
    printf '\nElegí el número del paquete: '
    IFS= read -r selection || exit 0

    case "$selection" in
        q|Q|'') exit 0 ;;
        r|R)
            printf '%s\n' 'Volvé a ejecutar la tienda para recargar.'
            exit 0
            ;;
        *[!0-9]*)
            error "Selección inválida"
            exit 2
            ;;
    esac

    [ "$selection" -ge 1 ] 2>/dev/null || {
        error "Número fuera de rango"
        exit 2
    }

    SELECTED_ID=''
    INDEX=0

    while IFS='|' read -r id version field3 field4 description rest ||
          [ -n "${id:-}" ]; do
        [ -n "${id:-}" ] || continue
        INDEX=$((INDEX + 1))

        if [ "$INDEX" -eq "$selection" ]; then
            SELECTED_ID=$id
            break
        fi
    done < "$TMP_FILE"

    if [ -z "$SELECTED_ID" ] || ! valid_id "$SELECTED_ID"; then
        error "No se encontró un paquete válido para esa selección"
        exit 2
    fi

    printf '\nPaquete seleccionado: %s\n' "$SELECTED_ID"
    printf '¿Querés solicitar su instalación? [s/N] '
    IFS= read -r confirm || exit 0

    case "$confirm" in
        s|S|si|SI|Si|sí|Sí)
            ;;
        *)
            printf '%s\n' 'Instalación cancelada.'
            exit 0
            ;;
    esac

    if ! command -v bacusp >/dev/null 2>&1; then
        error "No se encontró bacusp en PATH"
        exit 127
    fi

    exec bacusp install "$SELECTED_ID"
)

# Compatible entry point for the previous module name.
cmd_store_gui() {
    cmd_store_tui "$@"
}
