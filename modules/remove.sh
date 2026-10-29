
#!/bin/sh
# BACUSP v7.5 - Remove BP Packages
# Project: Bacus-Pkg
# Author: ciberspar
# Languages: Spanish / English

set -eu

BACUSP_HOME=${BACUSP_HOME:-"${HOME:-/tmp}/.bacusp"}
APP_ROOT="$BACUSP_HOME/apps"
LANGUAGE=${BACUSP_LANG:-es}

usage() {
    printf '%s\n' \
        "Uso: bacusp remove NOMBRE [VERSION]" \
        "Usage: bacusp remove NAME [VERSION]"
}

if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
    usage
    exit 2
fi

NAME=$1
VERSION=${2:-}

# Accept only safe package/version directory names.
case "$NAME" in
    ""|.|..|*[!A-Za-z0-9._+-]*)
        echo "Error: nombre de paquete inválido." >&2
        exit 2
        ;;
esac

if [ -n "$VERSION" ]; then
    case "$VERSION" in
        .|..|*[!A-Za-z0-9._+-]*)
            echo "Error: versión inválida." >&2
            exit 2
            ;;
    esac
fi

PACKAGE_DIR="$APP_ROOT/$NAME"

if [ ! -d "$PACKAGE_DIR" ] || [ -L "$PACKAGE_DIR" ]; then
    echo "Error: paquete BP no encontrado." >&2
    exit 1
fi

if [ -n "$VERSION" ]; then
    TARGET="$PACKAGE_DIR/$VERSION"

    if [ ! -d "$TARGET" ] || [ -L "$TARGET" ]; then
        echo "Error: versión no encontrada." >&2
        exit 1
    fi
else
    TARGET=$PACKAGE_DIR
fi

case "$TARGET" in
    "$APP_ROOT"/*) ;;
    *)
        echo "Error: ruta de eliminación no permitida." >&2
        exit 2
        ;;
esac

if [ "$LANGUAGE" = en ]; then
    printf 'Remove: %s\n' "$TARGET"
    printf 'This only removes the Bacus-Pkg app directory.\n'
    printf 'It does not uninstall system packages or external dependencies.\n'
    printf 'Continue? Type YES: '
    EXPECTED=YES
else
    printf 'Eliminar: %s\n' "$TARGET"
    printf 'Esto solo elimina el directorio de la aplicación Bacus-Pkg.\n'
    printf 'No desinstala paquetes del sistema ni dependencias externas.\n'
    printf '¿Continuar? Escribí SI: '
    EXPECTED=SI
fi

IFS= read -r ANSWER || exit 2

[ "$ANSWER" = "$EXPECTED" ] || {
    echo "Cancelado; no se eliminó nada."
    exit 0
}

# Re-check immediately before deletion.
[ -d "$TARGET" ] && [ ! -L "$TARGET" ] || {
    echo "Error: el destino cambió o ya no existe." >&2
    exit 1
}

rm -rf "$TARGET"

if [ -n "$VERSION" ] && [ -d "$PACKAGE_DIR" ]; then
    # Remove an empty package directory only.
    rmdir "$PACKAGE_DIR" 2>/dev/null || :
fi

echo "Operación completada."
exit 0
