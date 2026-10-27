
#!/bin/sh
# Bacus-Pkg BP v2 - Converter
set -eu
umask 077

err() { printf 'ERROR: %s\n' "$*" >&2; exit 2; }
ORIG=${1:-}
DEST=${2:-}

[ -n "$ORIG" ] || err "Uso: bacusp convert ORIGEN DESTINO.bp"
[ -e "$ORIG" ] || err "No existe: $ORIG"

case "$ORIG" in /*) ;; *) ORIG="$(pwd)/$ORIG" ;; esac

if [ -z "$DEST" ]; then
    BASE=$(basename "$ORIG")
    DEST="${BASE%.*}.bp"
fi

case "$DEST" in *.bp) ;; *) err "El destino debe terminar en .bp" ;; esac
[ ! -e "$DEST" ] || err "El destino ya existe"

PARENT=$(dirname "$DEST")
[ -d "$PARENT" ] || err "No existe el directorio de destino"

command -v tar >/dev/null 2>&1 || err "Se necesita tar"
command -v gzip >/dev/null 2>&1 || err "Se necesita gzip"

HASH_TOOL=
if command -v sha256sum >/dev/null 2>&1; then
    HASH_TOOL=sha256sum
elif command -v shasum >/dev/null 2>&1; then
    HASH_TOOL=shasum
else
    err "Se necesita sha256sum o shasum para crear un BP verificable"
fi

WORK=$(mktemp -d "${TMPDIR:-/tmp}/bp-convert.XXXXXX") ||
    err "No se pudo crear el directorio temporal"

OUT=
cleanup() {
    rm -rf "$WORK"
    [ -z "$OUT" ] || rm -f "$OUT"
}
trap cleanup 0
trap 'exit 2' HUP INT TERM

mkdir -p "$WORK/payload"
SOURCE=$(basename "$ORIG")
FORMAT=directory
STATUS=extracted-unverified
TARGET=portable
EXTRACTED=no

safe_tar_list() {
    LIST=$1
    while IFS= read -r entry; do
        case "$entry" in
            /*|..|../*|*/../*|*/..)
                err "Ruta peligrosa en el archivo: $entry"
                ;;
        esac
    done < "$LIST"
}

if [ -d "$ORIG" ]; then
    cp -R "$ORIG"/. "$WORK/payload"/ ||
        err "No se pudo copiar el directorio"
    EXTRACTED=yes
else
    case "$SOURCE" in
        *.deb)
            FORMAT=deb
            TARGET=linux
            if command -v dpkg-deb >/dev/null 2>&1; then
                dpkg-deb -x "$ORIG" "$WORK/payload" ||
                    err "No se pudo extraer el DEB"
                EXTRACTED=yes
            fi
            ;;
        *.rpm)
            FORMAT=rpm
            TARGET=linux
            if command -v rpm2cpio >/dev/null 2>&1 &&
               command -v cpio >/dev/null 2>&1; then
                (cd "$WORK/payload" &&
                    rpm2cpio "$ORIG" | cpio -idm --no-absolute-filenames) ||
                    err "No se pudo extraer el RPM"
                EXTRACTED=yes
            fi
            ;;
        *.zip)
            FORMAT=zip
            TARGET=portable
            if command -v bsdtar >/dev/null 2>&1; then
                bsdtar -tf "$ORIG" > "$WORK/list" ||
                    err "ZIP inválido"
                safe_tar_list "$WORK/list"
                bsdtar -xf "$ORIG" -C "$WORK/payload" ||
                    err "No se pudo extraer ZIP"
                EXTRACTED=yes
            elif command -v unzip >/dev/null 2>&1; then
                unzip -Z1 "$ORIG" > "$WORK/list" ||
                    err "ZIP inválido"
                safe_tar_list "$WORK/list"
                unzip -q "$ORIG" -d "$WORK/payload" ||
                    err "No se pudo extraer ZIP"
                EXTRACTED=yes
            fi
            ;;
        *.tar|*.tar.gz|*.tgz|*.tar.xz|*.txz|*.tar.zst)
            FORMAT=tar-archive
            TARGET=portable
            tar -tf "$ORIG" > "$WORK/list" ||
                err "Archivo TAR inválido"
            safe_tar_list "$WORK/list"
            tar -xf "$ORIG" -C "$WORK/payload" ||
                err "No se pudo extraer TAR"
            EXTRACTED=yes
            ;;
        *.msi)
            FORMAT=msi
            TARGET=windows
            if command -v msiextract >/dev/null 2>&1; then
                msiextract -C "$WORK/payload" "$ORIG" ||
                    err "No se pudo extraer MSI"
                EXTRACTED=yes
            fi
            ;;
        *.exe)
            FORMAT=exe
            TARGET=windows
            ;;
        *.apk)
            FORMAT=apk-ambiguous
            TARGET=unknown
            ;;
        *.AppImage)
            FORMAT=appimage
            TARGET=linux
            ;;
        *)
            FORMAT=unknown
            TARGET=unknown
            ;;
    esac

    if [ "$EXTRACTED" != yes ]; then
        mkdir -p "$WORK/payload/original"
        cp "$ORIG" "$WORK/payload/original/$SOURCE" ||
            err "No se pudo copiar el archivo original"
        STATUS=source-only
    fi
fi

# No admitimos enlaces ni archivos especiales en BP v2.
if find "$WORK/payload" ! -type d ! -type f -print |
    grep . >/dev/null 2>&1; then
    err "El contenido tiene enlaces o archivos especiales"
fi

NAME=$(printf '%s' "${SOURCE%.*}" | tr -cd 'A-Za-z0-9._+-')
[ -n "$NAME" ] || NAME=imported-package

VERSION=0.1.0
OS=$(uname -s 2>/dev/null || printf unknown)
ARCH=$(uname -m 2>/dev/null || printf unknown)

{
    printf 'format\tbp\n'
    printf 'format_version\t2\n'
    printf 'package_name\t%s\n' "$NAME"
    printf 'version\t%s\n' "$VERSION"
    printf 'source_name\t%s\n' "$SOURCE"
    printf 'source_format\t%s\n' "$FORMAT"
    printf 'conversion_host\t%s\n' "$OS"
    printf 'conversion_arch\t%s\n' "$ARCH"
    printf 'target_family\t%s\n' "$TARGET"
    printf 'compatibility_status\t%s\n' "$STATUS"
    printf 'payload_directory\tpayload\n'
} > "$WORK/manifest.tsv"

cat > "$WORK/COMPATIBILITY.txt" <<EOF
Bacus-Pkg BP v2
Source: $SOURCE
Format: $FORMAT
Target family: $TARGET
Status: $STATUS

BP is a package container, not a binary translator.
Native compatibility must be checked on the destination system.
Original installers are never executed during conversion.
EOF

(
    cd "$WORK"
    if [ "$HASH_TOOL" = sha256sum ]; then
        find payload -type f -exec sha256sum '{}' \; > checksums.sha256
    else
        find payload -type f -exec shasum -a 256 '{}' \; > checksums.sha256
    fi
) || err "No se pudieron generar los hashes"

OUT=$(mktemp "$PARENT/.bp-output.XXXXXX") ||
    err "No se pudo crear el archivo de salida"

tar -czf "$OUT" -C "$WORK" \
    manifest.tsv COMPATIBILITY.txt checksums.sha256 payload ||
    err "No se pudo crear el paquete"

gzip -t "$OUT" || err "El paquete generado está dañado"
mv "$OUT" "$DEST" || err "No se pudo guardar el paquete"
OUT=

printf 'Creado: %s\n' "$DEST"
printf 'Formato: BP v2\nOrigen: %s\nEstado: %s\n' "$FORMAT" "$STATUS"
