#!/bin/sh
# BACUSP Convert - Initial BP package builder
# Internal module managed by bin/bacusp
set -u
ORIGEN=${1:-}
DESTINO=${2:-}
error() {
    printf 'ERROR: %s\n' "$*" >&2
}
if [ -z "$ORIGEN" ] || [ -z "$DESTINO" ]; then
    error "Usage: bacusp convert SOURCE DESTINATION.bp"
    exit 2
fi
if [ ! -e "$ORIGEN" ]; then
    error "Source does not exist: $ORIGEN"
    exit 2
fi
case "$DESTINO" in
    *.bp) ;;
    *)
        error "Destination must end in .bp"
        exit 2
        ;;
esac
if [ -d "$ORIGEN" ] && [ ! -r "$ORIGEN" ]; then
    error "Source directory is not readable."
    exit 2
fi
if [ -f "$ORIGEN" ] && [ ! -r "$ORIGEN" ]; then
    error "Source file is not readable."
    exit 2
fi
if [ -e "$DESTINO" ]; then
    error "Destination already exists; refusing to overwrite it."
    exit 2
fi
if ! command -v tar >/dev/null 2>&1; then
    error "tar is required to create a .bp archive."
    exit 2
fi
if ! command -v gzip >/dev/null 2>&1; then
    error "gzip is required to create a .bp archive."
    exit 2
fi
PARENT=$(dirname "$DESTINO")
NAME=$(basename "$DESTINO")
if [ ! -d "$PARENT" ]; then
    error "Destination directory does not exist: $PARENT"
    exit 2
fi
WORK=$(mktemp -d "${TMPDIR:-/tmp}/bacusp-convert.XXXXXX") || {
    error "Could not create temporary directory."
    exit 2
}
cleanup() {
    rm -rf "$WORK"
}
trap cleanup 0
trap 'exit 2' HUP INT TERM
mkdir -p "$WORK/payload" || exit 2
# Copy source without executing it.
if [ -d "$ORIGEN" ]; then
    cp -R "$ORIGEN"/. "$WORK/payload/" || {
        error "Could not copy source directory."
        exit 2
    }
else
    cp "$ORIGEN" "$WORK/payload/" || {
        error "Could not copy source file."
        exit 2
    }
fi
PLATFORM=$(uname -s 2>/dev/null || printf unknown)
ARCH=$(uname -m 2>/dev/null || printf unknown)
cat > "$WORK/manifest.txt" <<EOF
format=bp
format_version=1
package_name=$NAME
source_name=$(basename "$ORIGEN")
source_platform=$PLATFORM
source_architecture=$ARCH
payload_directory=payload
compatibility_status=unverified
EOF
cat > "$WORK/COMPATIBILITY.txt" <<'EOF'
This package contains the original source or package payload.
The .bp container format does not make native binaries portable.
Each target platform requires a compatible implementation or runtime.
No cross-platform compatibility has been verified by this conversion.
No payload was executed during conversion.
EOF
# Build a temporary archive in the destination directory so the final
# rename stays on the same filesystem.
TMP_OUT=$(mktemp "$PARENT/.bacusp-package.XXXXXX") || {
    error "Could not create temporary output."
    exit 2
}
if ! tar -cf - -C "$WORK" manifest.txt COMPATIBILITY.txt payload |
    gzip -c > "$TMP_OUT"; then
    rm -f "$TMP_OUT"
    error "Archive creation failed."
    exit 2
fi
if [ ! -s "$TMP_OUT" ]; then
    rm -f "$TMP_OUT"
    error "The generated archive is empty."
    exit 2
fi
if ! mv "$TMP_OUT" "$DESTINO"; then
    rm -f "$TMP_OUT"
    error "Could not finalize destination."
    exit 2
fi
printf 'Created: %s\n' "$DESTINO"
printf '%s\n' "Format: BP v1"
printf '%s\n' "Compatibility: unverified; no native binaries were converted."
exit 0