#!/bin/sh
# BACUSP Bridge - Compatibility Analyzer
# Internal module managed by bin/bacusp
set -u
PAQUETE_TARGET=${1:-}
ENTORNO_ACTUAL=${2:-unknown}
error() {
    printf 'ERROR: %s\n' "$*" >&2
}
if [ -z "$PAQUETE_TARGET" ]; then
    error "Usage: bacusp bridge PACKAGE [PLATFORM]"
    exit 2
fi
if [ ! -e "$PAQUETE_TARGET" ]; then
    error "Package or source path not found: $PAQUETE_TARGET"
    exit 2
fi
case "$ENTORNO_ACTUAL" in
    debian|ubuntu|arch|fedora|opensuse|alpine|linux-unknown|linux)
        FAMILIA=linux ;;
    darwin|macos)
        FAMILIA=macos ;;
    freebsd|openbsd|netbsd|bsd)
        FAMILIA=bsd ;;
    haiku)
        FAMILIA=haiku ;;
    windows|mingw|msys)
        FAMILIA=windows ;;
    termux)
        FAMILIA=termux ;;
    hurd)
        FAMILIA=hurd ;;
    *)
        FAMILIA=unknown ;;
esac
printf '%s\n' "BACUSP Bridge - Compatibility Analysis"
printf 'Input: %s\n' "$PAQUETE_TARGET"
printf 'Target: %s (%s)\n' "$ENTORNO_ACTUAL" "$FAMILIA"
if [ -d "$PAQUETE_TARGET" ]; then
    TIPO=source-directory
elif command -v file >/dev/null 2>&1; then
    DESCRIPCION=$(file -b "$PAQUETE_TARGET" 2>/dev/null || printf unknown)
    printf 'Detected file type: %s\n' "$DESCRIPCION"
    case "$DESCRIPCION" in
        *ELF*)
            TIPO=native-binary
            ;;
        *PE32*|*MS-DOS*executable*)
            TIPO=windows-binary
            ;;
        *script*|*text*)
            TIPO=script-or-source
            ;;
        *)
            TIPO=unknown
            ;;
    esac
else
    TIPO=unknown
fi
printf 'Classification: %s\n' "$TIPO"
printf '%s\n' "Available build tools:"
for tool in cc gcc clang make cmake meson python3; do
    if command -v "$tool" >/dev/null 2>&1; then
        printf '  available: %s\n' "$tool"
    else
        printf '  missing:   %s\n' "$tool"
    fi
done
case "$TIPO:$FAMILIA" in
    native-binary:windows|native-binary:haiku|native-binary:bsd|native-binary:macos)
        printf '%s\n' \
            "Status: native binary compatibility is NOT established."
        printf '%s\n' \
            "A compatible build or verified runtime is required."
        exit 3
        ;;
    windows-binary:linux|windows-binary:bsd|windows-binary:haiku)
        printf '%s\n' \
            "Status: Windows binary detected; native compatibility is not established."
        exit 3
        ;;
    source-directory:*)
        printf '%s\n' \
            "Status: source directory detected; build configuration must be inspected."
        ;;
    script-or-source:*)
        printf '%s\n' \
            "Status: inspect interpreter, dependencies and platform-specific commands."
        ;;
    *)
        printf '%s\n' \
            "Status: insufficient information to confirm compatibility."
        ;;
esac
exit 0