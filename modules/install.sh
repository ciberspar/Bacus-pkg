
#!/bin/sh
# Bacus-Pkg BP v2 - Safe user-space installer
set -eu
umask 077

PKG=${1:-}
[ -n "$PKG" ] || {
    echo "Uso: bacusp install ARCHIVO.bp" >&2
    exit 2
}
[ -f "$PKG" ] && [ -r "$PKG" ] || {
    echo "ERROR: paquete no legible" >&2
    exit 2
}

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd -P)
VERIFY="$SCRIPT_DIR/verify.sh"
[ -f "$VERIFY" ] || {
    echo "ERROR: falta modules/verify.sh" >&2
    exit 2
}

sh "$VERIFY" "$PKG" >/dev/null || {
    echo "ERROR: paquete no válido; instalación cancelada" >&2
    exit 3
}

HOME_DIR=${HOME:-}
[ -n "$HOME_DIR" ] || {
    echo "ERROR: HOME no está configurado" >&2
    exit 2
}

ROOT=${BACUSP_HOME:-"$HOME_DIR/.bacusp"}
APPS="$ROOT/apps"
DB="$ROOT/installed.db"
WORK=$(mktemp -d "${TMPDIR:-/tmp}/bp-install.XXXXXX")
trap 'rm -rf "$WORK"' 0
trap 'exit 2' HUP INT TERM

tar -xzf "$PKG" -C "$WORK"

field() {
    awk -F '\t' -v key="$1" \
        '$1 == key { print substr($0, length($1)+2); exit }' \
        "$WORK/manifest.tsv"
}

NAME=$(field package_name)
VERSION=$(field version)
STATUS=$(field compatibility_status)
TARGET=$(field target_family)
HOST=$(uname -s 2>/dev/null || printf unknown)

case "$NAME" in
    ''|*[!A-Za-z0-9._+-]*)
        echo "ERROR: nombre inválido" >&2
        exit 2
        ;;
esac
case "$VERSION" in
    ''|*[!A-Za-z0-9._+-]*)
        echo "ERROR: versión inválida" >&2
        exit 2
        ;;
esac

[ "$STATUS" = extracted-unverified ] || {
    echo "ERROR: el paquete contiene el original, no una aplicación extraída" >&2
    exit 3
}

case "$TARGET:$HOST" in
    portable:*)
        ;;
    linux:Linux)
        ;;
    *)
        echo "ERROR: compatibilidad no confirmada: $TARGET en $HOST" >&2
        exit 3
        ;;
esac

DEST="$APPS/$NAME/$VERSION"
[ ! -e "$DEST" ] || {
    echo "ERROR: esa versión ya está instalada" >&2
    exit 2
}

mkdir -p "$APPS/$NAME" "$ROOT/sandboxes/$NAME/documents" \
    "$ROOT/sandboxes/$NAME/downloads" "$ROOT/sandboxes/$NAME/config"

STAGE="$APPS/$NAME/.install-$$"
mkdir "$STAGE"
cp -R "$WORK/payload"/. "$STAGE"/ || {
    rm -rf "$STAGE"
    echo "ERROR: copia fallida" >&2
    exit 2
}

mv "$STAGE" "$DEST" || {
    rm -rf "$STAGE"
    echo "ERROR: no se pudo completar la instalación" >&2
    exit 2
}

mkdir -p "$ROOT"
touch "$DB"
if ! printf '%s\t%s\t%s\t%s\n' \
    "$NAME" "$VERSION" "$TARGET" "$DEST" >> "$DB"; then
    rm -rf "$DEST"
    echo "ERROR: no se pudo registrar la instalación" >&2
    exit 2
fi

printf 'Instalado en el espacio de usuario: %s\n' "$DEST"
printf 'Datos de la aplicación: %s/sandboxes/%s\n' "$ROOT" "$NAME"
echo "Nota: instalar archivos no garantiza que la aplicación sea ejecutable."
