
#!/bin/sh
# Bacus-Pkg BP v2 - Verifier
set -eu
umask 077

PKG=${1:-}
[ -n "$PKG" ] || {
    echo "Uso: bacusp verify ARCHIVO.bp" >&2
    exit 2
}
[ -f "$PKG" ] && [ -r "$PKG" ] || {
    echo "ERROR: paquete no legible" >&2
    exit 2
}

command -v tar >/dev/null 2>&1 || exit 2
command -v gzip >/dev/null 2>&1 || exit 2

if command -v sha256sum >/dev/null 2>&1; then
    HASH_TOOL=sha256sum
elif command -v shasum >/dev/null 2>&1; then
    HASH_TOOL=shasum
else
    echo "ERROR: falta sha256sum o shasum" >&2
    exit 2
fi

WORK=$(mktemp -d "${TMPDIR:-/tmp}/bp-verify.XXXXXX")
trap 'rm -rf "$WORK"' 0
trap 'exit 2' HUP INT TERM

gzip -t "$PKG" || {
    echo "ERROR: archivo comprimido inválido" >&2
    exit 2
}

tar -tzf "$PKG" > "$WORK/list" || {
    echo "ERROR: archivo BP ilegible" >&2
    exit 2
}

while IFS= read -r entry; do
    case "$entry" in
        /*|..|../*|*/../*|*/..)
            echo "ERROR: ruta insegura: $entry" >&2
            exit 2
            ;;
    esac
done < "$WORK/list"

tar -xzf "$PKG" -C "$WORK" ||
    { echo "ERROR: extracción fallida" >&2; exit 2; }

MANIFEST="$WORK/manifest.tsv"
[ -f "$MANIFEST" ] &&
[ -f "$WORK/checksums.sha256" ] &&
[ -d "$WORK/payload" ] || {
    echo "ERROR: faltan archivos obligatorios del paquete" >&2
    exit 2
}

field() {
    awk -F '\t' -v key="$1" \
        '$1 == key { print substr($0, length($1)+2); exit }' "$MANIFEST"
}

[ "$(field format)" = bp ] &&
[ "$(field format_version)" = 2 ] || {
    echo "ERROR: versión BP no compatible" >&2
    exit 2
}

(
    cd "$WORK"
    if [ "$HASH_TOOL" = sha256sum ]; then
        sha256sum -c checksums.sha256
    else
        shasum -a 256 -c checksums.sha256
    fi
) || {
    echo "ERROR: los hashes no coinciden" >&2
    exit 3
}

printf 'Paquete válido: %s\n' "$(field package_name)"
printf 'Versión: %s\n' "$(field version)"
printf 'Formato: BP v2\n'
printf 'Plataforma declarada: %s\n' "$(field target_family)"
printf 'Estado: %s\n' "$(field compatibility_status)"
echo "Integridad: OK"
