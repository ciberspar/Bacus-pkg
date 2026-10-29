
#!/bin/sh
#
# BACUSP - Purge module
# Project: Bacus-Pkg
# Branch: fixer
# Purpose: Safely remove package-specific user data.
#
# Usage: bacusp purge PACKAGE_ID
#
# This module does NOT uninstall operating-system packages.
# It only removes an approved user binary, package cache,
# package configuration, and matching installed.db records.
#

set -u
umask 077

APP="BACUSP"
HOME_DIR=${HOME:-}
BACUSP_HOME=${BACUSP_HOME:-"${HOME:-}/.bacusp"}

RED=''
GREEN=''
YELLOW=''
RESET=''

if [ -t 1 ]; then
    RED=$(printf '\033[1;31m')
    GREEN=$(printf '\033[1;32m')
    YELLOW=$(printf '\033[1;33m')
    RESET=$(printf '\033[0m')
fi

error() {
    printf '%sError: %s%s\n' "$RED" "$*" "$RESET" >&2
}

warn() {
    printf '%sWarning: %s%s\n' "$YELLOW" "$*" "$RESET" >&2
}

success() {
    printf '%s%s%s\n' "$GREEN" "$*" "$RESET"
}

usage() {
    printf '%s\n' \
        'Uso / Usage: bacusp purge PACKAGE_ID' \
        'Elimina datos locales de un paquete registrado.' \
        'Removes local data belonging to a registered package.'
}

# ---------- Arguments ----------

if [ "$#" -ne 1 ]; then
    usage
    exit 2
fi

PAQ=$1

# Restrict identifiers to safe, simple package names.
# The first character must be alphanumeric.
case "$PAQ" in
    ''|[!A-Za-z0-9]*|*[!A-Za-z0-9._+-]*)
        error "Nombre de paquete inválido / Invalid package ID"
        exit 2
        ;;
esac

if [ "${#PAQ}" -gt 128 ]; then
    error "El nombre del paquete es demasiado largo / Package ID too long"
    exit 2
fi

# ---------- Validate home paths ----------

case "$HOME_DIR" in
    /*) ;;
    *)
        error "HOME debe ser una ruta absoluta / HOME must be absolute"
        exit 1
        ;;
esac

case "$BACUSP_HOME" in
    /*) ;;
    *)
        error "BACUSP_HOME debe ser una ruta absoluta"
        exit 1
        ;;
esac

if [ ! -d "$HOME_DIR" ] || [ -L "$HOME_DIR" ]; then
    error "HOME no es un directorio válido o es un enlace simbólico"
    exit 1
fi

if [ ! -d "$BACUSP_HOME" ] || [ -L "$BACUSP_HOME" ]; then
    error "BACUSP_HOME debe existir y no ser un enlace simbólico"
    exit 1
fi

DB_FILE="$BACUSP_HOME/installed.db"
CACHE_DIR="$BACUSP_HOME/cache"
CONFIG_DIR="$HOME_DIR/.config"

if [ ! -f "$DB_FILE" ] || [ -L "$DB_FILE" ]; then
    error "installed.db no existe, no es un archivo regular o es un enlace simbólico"
    exit 1
fi

# Do not operate on an unexpected cache directory.
if [ -e "$CACHE_DIR" ] || [ -L "$CACHE_DIR" ]; then
    if [ ! -d "$CACHE_DIR" ] || [ -L "$CACHE_DIR" ]; then
        error "La ruta de caché no es un directorio seguro"
        exit 1
    fi
fi

# Do not traverse a redirected configuration directory.
if [ -e "$CONFIG_DIR" ] || [ -L "$CONFIG_DIR" ]; then
    if [ ! -d "$CONFIG_DIR" ] || [ -L "$CONFIG_DIR" ]; then
        error "La ruta de configuración no es un directorio seguro"
        exit 1
    fi
fi

# ---------- Confirm package registration ----------

if ! awk -F '|' -v name="$PAQ" '
    $1 == name { found = 1 }
    END { exit(found ? 0 : 1) }
' "$DB_FILE"; then
    error "El paquete no está registrado en installed.db"
    error "Package is not registered; nothing was removed"
    exit 1
fi

# ---------- Resolve the recorded binary ----------

RUTA_BIN=$(awk -F '|' -v name="$PAQ" '
    $1 == name { print $2; exit }
' "$DB_FILE") || {
    error "No se pudo leer installed.db"
    exit 1
}

# Only these exact per-user binary paths are eligible.
BIN_ALLOWED=0

case "$RUTA_BIN" in
    "$HOME_DIR/bin/$PAQ")
        BIN_PARENT="$HOME_DIR/bin"
        BIN_ALLOWED=1
        ;;
    "$HOME_DIR/.local/bin/$PAQ")
        BIN_PARENT="$HOME_DIR/.local/bin"
        BIN_ALLOWED=1
        ;;
    '')
        BIN_ALLOWED=0
        ;;
    *)
        warn "Ruta de binario no autorizada; se conservará: $RUTA_BIN"
        ;;
esac

# Check the parent directory before touching the binary.
if [ "$BIN_ALLOWED" -eq 1 ]; then
    if [ -e "$BIN_PARENT" ] || [ -L "$BIN_PARENT" ]; then
        if [ ! -d "$BIN_PARENT" ] || [ -L "$BIN_PARENT" ]; then
            error "El directorio del binario no es seguro: $BIN_PARENT"
            exit 1
        fi
    fi

    # Never remove a symlink or a non-regular file as a binary.
    if [ -L "$RUTA_BIN" ]; then
        error "El binario registrado es un enlace simbólico; no se eliminará"
        exit 1
    fi

    if [ -e "$RUTA_BIN" ] && [ ! -f "$RUTA_BIN" ]; then
        error "El binario registrado no es un archivo regular"
        exit 1
    fi
fi

# ---------- Resolve package-specific data ----------

CACHE_TARGET="$CACHE_DIR/build_$PAQ"
CONFIG_TARGET="$CONFIG_DIR/$PAQ"

# Refuse unexpected symlinks rather than traversing or deleting them.
if [ -L "$CACHE_TARGET" ]; then
    error "La caché del paquete es un enlace simbólico; no se eliminará"
    exit 1
fi

if [ -L "$CONFIG_TARGET" ]; then
    error "La configuración del paquete es un enlace simbólico; no se eliminará"
    exit 1
fi

# ---------- Prepare a private database transaction ----------

# Create a private temporary directory inside BACUSP_HOME.
# Do not use predictable temporary filenames.
TMP_DIR=$(mktemp -d "$BACUSP_HOME/.purge.XXXXXXXX") || {
    error "No se pudo crear un directorio temporal seguro"
    exit 1
}

if [ ! -d "$TMP_DIR" ] || [ -L "$TMP_DIR" ]; then
    error "El directorio temporal no es seguro"
    exit 1
fi

TMP_DB="$TMP_DIR/installed.db"

cleanup() {
    if [ -n "${TMP_DIR:-}" ] &&
       [ -d "$TMP_DIR" ] &&
       [ ! -L "$TMP_DIR" ]; then
        rm -rf "$TMP_DIR"
    fi
}

trap 'cleanup' 0
trap 'exit 1' HUP INT TERM

if ! awk -F '|' -v name="$PAQ" '
    $1 != name { print }
' "$DB_FILE" > "$TMP_DB"; then
    error "No se pudo preparar la nueva base de datos"
    exit 1
fi

if [ ! -f "$TMP_DB" ] || [ -L "$TMP_DB" ]; then
    error "El archivo temporal de la base de datos no es seguro"
    exit 1
fi

# ---------- Remove only approved package-specific data ----------

printf 'Bacus-Pkg: purging "%s"\n' "$PAQ"

if [ -d "$CACHE_TARGET" ]; then
    if ! rm -rf "$CACHE_TARGET"; then
        error "No se pudo eliminar la caché del paquete"
        exit 1
    fi
    success "Caché eliminada / Cache removed"
fi

if [ -d "$CONFIG_TARGET" ]; then
    if ! rm -rf "$CONFIG_TARGET"; then
        error "No se pudo eliminar la configuración del paquete"
        exit 1
    fi
    success "Configuración eliminada / Configuration removed"
fi

if [ "$BIN_ALLOWED" -eq 1 ] && [ -f "$RUTA_BIN" ]; then
    if ! rm -f "$RUTA_BIN"; then
        error "No se pudo eliminar el binario del paquete"
        exit 1
    fi
    success "Binario eliminado / Binary removed"
fi

# ---------- Commit database update ----------

# Recheck the destination immediately before replacing it.
if [ ! -f "$DB_FILE" ] || [ -L "$DB_FILE" ]; then
    error "installed.db cambió durante la operación; no se actualizará"
    exit 1
fi

if ! mv -f "$TMP_DB" "$DB_FILE"; then
    error "No se pudo guardar la base de datos actualizada"
    exit 1
fi

success "Purga finalizada / Purge completed: $PAQ"
exit 0
