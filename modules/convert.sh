
#!/bin/sh
# BACUSP Convert - BP v1
# Called by bin/bacusp
set -eu
umask 077

error() { printf 'ERROR: %s\n' "$*" >&2; }
ORIGEN=${1:-}
DESTINO=${2:-}

[ -n "$ORIGEN" ] || {
    error "Usage: bacusp convert SOURCE [DESTINATION.bp]"
    exit 2
}
[ -e "$ORIGEN" ] || {
    error "Source not found: $ORIGEN"
    exit 2
}

case "$ORIGEN" in
    /*) ;;
    *) ORIGEN="$(pwd)/$ORIGEN" ;;
esac

if [ -z "$DESTINO" ]; then
    BASE=$(basename "$ORIGEN")
    DESTINO="${BASE%.*}.bp"
fi
case "$DESTINO" in
    *.bp) ;;
    *) error "Destination must end in .bp"; exit 2 ;;
esac
[ ! -e "$DESTINO" ] || {
    error "Destination already exists."
    exit 2
}

PARENT=$(dirname "$DESTINO")
[ -d "$PARENT" ] || {
    error "Destination directory does not exist: $PARENT"
    exit 2
}
command -v tar >/dev/null 2>&1 || {
    error "tar is required"; exit 2
}
command -v gzip >/dev/null 2>&1 || {
    error "gzip is required"; exit 2
}

WORK=$(mktemp -d "${TMPDIR:-/tmp}/bacusp-convert.XXXXXX") || exit 2
OUT=
cleanup() {
    rm -rf "$WORK"
    [ -z "$OUT" ] || rm -f "$OUT"
}
trap cleanup 0
trap 'exit 2' HUP INT TERM

mkdir -p "$WORK/payload" || exit 2
SOURCE=$(basename "$ORIGEN")
FORMAT=unknown
STATUS=source-only
TARGET=unknown

case "$SOURCE" in
    *.deb)
        FORMAT=deb
        TARGET=linux
        if command -v dpkg-deb >/dev/null 2>&1; then
            if dpkg-deb -x "$ORIGEN" "$WORK/payload"; then
                STATUS=extracted-unverified
            else
                error "Could not extract .deb"
                exit 2
            fi
        fi
        ;;
    *.msi)
        FORMAT=msi
        TARGET=windows
        if command -v msiextract >/dev/null 2>&1; then
            if msiextract -C "$WORK/payload" "$ORIGEN"; then
                STATUS=extracted-unverified
            else
                error "Could not extract .msi"
                exit 2
            fi
        fi
        ;;
    *.rpm)
        FORMAT=rpm
        TARGET=linux
        ;;
    *.pkg.tar.zst|*.pkg.tar.xz|*.pkg.tar.gz)
        FORMAT=arch-package
        TARGET=linux
        ;;
    *.apk)
        FORMAT=apk
        TARGET=android-or-alpine
        ;;
    *.AppImage|*.exe)
        FORMAT=portable-or-executable
        ;;
    *.zip|*.tar|*.tar.gz|*.tgz|*.tar.xz|*.txz|*.tar.zst)
        FORMAT=archive
        if command -v bsdtar >/dev/null 2>&1; then
            if bsdtar -xf "$ORIGEN" -C "$WORK/payload"; then
                STATUS=extracted-unverified
            else
                error "Archive extraction failed"
                exit 2
            fi
        fi
        ;;
esac

if [ -d "$ORIGEN" ]; then
    FORMAT=directory
    STATUS=extracted-unverified
    cp -R "$ORIGEN"/. "$WORK/payload/" || {
        error "Could not copy directory"
        exit 2
    }
elif [ "$STATUS" = source-only ]; then
    mkdir -p "$WORK/payload/original"
    cp "$ORIGEN" "$WORK/payload/original/$SOURCE" || exit 2
fi

# Fail closed on symlinks and special files in the extracted payload.
if find "$WORK/payload" ! -type d ! -type f -print |
    grep . >/dev/null 2>&1; then
    error "Symlinks or special files detected; refusing package creation."
    exit 2
fi

NAME=$(printf '%s' "${SOURCE%.*}" |
    tr -cd 'A-Za-z0-9._+-')
[ -n "$NAME" ] || NAME=imported-package

PLATFORM=$(uname -s 2>/dev/null || printf unknown)
ARCH=$(uname -m 2>/dev/null || printf unknown)

{
    printf 'format\tbp\n'
    printf 'format_version\t1\n'
    printf 'package_name\t%s\n' "$NAME"
    printf 'version\t0\n'
    printf 'source_name\t%s\n' "$SOURCE"
    printf 'source_format\t%s\n' "$FORMAT"
    printf 'conversion_host\t%s\n' "$PLATFORM"
    printf 'conversion_arch\t%s\n' "$ARCH"
    printf 'target_family\t%s\n' "$TARGET"
    printf 'compatibility_status\t%s\n' "$STATUS"
    printf 'payload_directory\tpayload\n'
} > "$WORK/manifest.tsv"

cat > "$WORK/COMPATIBILITY.txt" <<EOF
Bacus-Pkg BP v1
Source: $SOURCE
Source format: $FORMAT
Target family: $TARGET
Status: $STATUS

Conversion does not guarantee that native binaries are portable.
Original installer scripts were not intentionally executed.
Review the package before installation.
EOF

OUT=$(mktemp "$PARENT/.bacusp-output.XXXXXX") || exit 2
if ! tar -czf "$OUT" -C "$WORK" manifest.tsv COMPATIBILITY.txt payload; then
    error "Could not create BP archive"
    exit 2
fi
[ -s "$OUT" ] || {
    error "Generated archive is empty"
    exit 2
}
mv "$OUT" "$DESTINO" || {
    error "Could not finalize package"
    exit 2
}
OUT=
printf 'Created: %s\n' "$DESTINO"
printf 'Source format: %s\nCompatibility: %s\n' "$FORMAT" "$STATUS"
