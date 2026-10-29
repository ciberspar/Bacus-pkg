
#!/bin/sh
# ======================================================
# BACUSP - Purge module
# Project: Bacus-Pkg
# Purpose: Safely remove package data
# ======================================================

set -u
umask 077

BACUSP_HOME=${BACUSP_HOME:-"${HOME:-/tmp}/.bacusp"}
DB_FILE="$BACUSP_HOME/installed.db"
CACHE_DIR="$BACUSP_HOME/cache"
CONFIG_DIR="${HOME:-/tmp}/.config"

RED=''
GREEN=''
RESET=''

if [ -t 1 ]; then
    RED=$(printf '\033[1;31m')
    GREEN=$(printf '\033[1;32m')
    RESET=$(printf '\033[0m')
fi

error() {
    printf '%sError: %s%s\n' "$RED" "$*" "$RESET" >&2
}

usage() {
    printf '%s\n' \
        'Uso / Usage: bacusp purge NOMBRE' \
        'Elimina datos de un paquete registrado.'
}

if [ "$#" -ne 1 ]; then
    usage
    exit 2
fi

PAQ=$1

# Only accept simple package identifiers.
case "$PAQ" in
    ''|.|..|[!A-Za-z0-9]*|*[!A-Za-z0-9._+-]*)
        error "Nombre de paquete inválido / Invalid package name"
        exit 2
        ;;
esac

case "$BACUSP_HOME" in
    /*) ;;
    *)
        error "BACUSP_HOME debe ser una ruta absoluta"
        exit 2
        ;;
esac

printf 'Bacus-Pkg: purging package "%s"\n' "$PAQ"

# Remove a recorded binary only when its path exactly matches
# a permitted per-user executable location.
if [ -f "$DB_FILE" ]; then
    RUTA_BIN=$(awk -F '|' -v name="$PAQ" \
        '$1 == name { print $2; exit }' "$DB_FILE") || {
        error "No se pudo leer la base de datos"
        exit 1
    }

    case "$RUTA_BIN" in
        "$HOME/bin/$PAQ"|"$HOME/.local/bin/$PAQ")
            if [ -f "$RUTA_BIN" ] || [ -L "$RUTA_BIN" ]; then
                if rm -f "$RUTA_BIN"; then
                    printf '%sRemoved binary: %s%s\n' \
                        "$GREEN" "$RUTA_BIN" "$RESET"
                else
                    error "No se pudo eliminar el binario"
                    exit 1
                fi
            fi
            ;;
        '')
            ;;
        *)
            printf '%s\n' \
                "Aviso: ruta no autorizada; no se eliminó: $RUTA_BIN" >&2
            ;;
    esac

    TMP_DB="$BACUSP_HOME/installed.db.tmp.$$"

    if ! awk -F '|' -v name="$PAQ" \
        '$1 != name' "$DB_FILE" > "$TMP_DB"; then
        rm -f "$TMP_DB"
        error "No se pudo actualizar la base de datos"
        exit 1
    fi

    if ! mv "$TMP_DB" "$DB_FILE"; then
        rm -f "$TMP_DB"
        error "No se pudo guardar la base de datos"
        exit 1
    fi
fi

# Remove only the exact package cache directory.
if [ -d "$CACHE_DIR/build_$PAQ" ] ||
   [ -L "$CACHE_DIR/build_$PAQ" ]; then
    if ! rm -rf "$CACHE_DIR/build_$PAQ"; then
        error "No se pudo eliminar la caché"
        exit 1
    fi
fi

# Remove only the exact package configuration directory.
if [ -d "$CONFIG_DIR/$PAQ" ] ||
   [ -L "$CONFIG_DIR/$PAQ" ]; then
    if ! rm -rf "$CONFIG_DIR/$PAQ"; then
        error "No se pudo eliminar la configuración"
        exit 1
    fi
fi

printf '%sPurge completed / Purga finalizada: %s%s\n' \
    "$GREEN" "$PAQ" "$RESET"
