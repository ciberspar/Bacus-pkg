
#!/bin/sh
# BACUSP - Safe Cache Cleaner
# Limpia únicamente la caché propia de Bacus-Pkg.
# ES/EN - POSIX shell

set -eu

BACUSP_HOME=${BACUSP_HOME:-"${HOME:?HOME no está definido}/.bacusp"}
CACHE_ROOT="$BACUSP_HOME/cache"

usage() {
    printf '%s\n' \
        "Bacus-Pkg: limpieza segura / safe cleanup" \
        "Uso / Usage: bacusp clean [--yes]" \
        "Solo elimina el contenido de la caché de Bacus-Pkg."
}

case "${1:-}" in
    "")
        ;;
    --help|-h)
        usage
        exit 0
        ;;
    --yes|-y)
        ;;
    *)
        usage >&2
        exit 2
        ;;
esac

if [ "$#" -gt 1 ]; then
    usage >&2
    exit 2
fi

# No seguir enlaces simbólicos ni aceptar rutas inesperadas.
if [ -L "$BACUSP_HOME" ] || [ -L "$CACHE_ROOT" ]; then
    printf '%s\n' "ERROR: ruta de caché simbólica rechazada." >&2
    exit 1
fi

if [ ! -d "$CACHE_ROOT" ]; then
    printf '%s\n' "No existe la caché de Bacus-Pkg; nada que limpiar."
    exit 0
fi

case "$CACHE_ROOT" in
    "$HOME"/.bacusp/cache)
        ;;
    *)
        printf '%s\n' "ERROR: ruta de caché no autorizada." >&2
        exit 1
        ;;
esac

if [ "${1:-}" != "--yes" ] && [ "${1:-}" != "-y" ]; then
    printf '¿Limpiar la caché de Bacus-Pkg? / Clean Bacus-Pkg cache? [s/N] '
    IFS= read -r answer || answer=""
    case "$answer" in
        s|S|si|SI|sí|Sí|y|Y|yes|YES)
            ;;
        *)
            printf '%s\n' "Cancelado / Cancelled."
            exit 0
            ;;
    esac
fi

# Borrar entradas directas, incluidos los nombres ocultos.
find "$CACHE_ROOT" -mindepth 1 -maxdepth 1 -exec rm -rf -- {} +

printf '%s\n' "Caché de Bacus-Pkg limpiada / Bacus-Pkg cache cleaned."
