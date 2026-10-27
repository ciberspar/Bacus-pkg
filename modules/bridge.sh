
#!/bin/sh
# Bacus-Pkg Bridge v2.0
# Platform and package compatibility analyzer
set -eu
umask 077

VERSION="2.0"

err() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 2
}

usage() {
    printf '%s\n' \
        "Bacus-Pkg Bridge v$VERSION" \
        "Uso: bacusp bridge ARCHIVO [PLATAFORMA]" \
        "Ejemplo: bacusp bridge aplicacion.deb Linux" \
        "Ejemplo: bacusp bridge aplicacion.bp Linux"
}

SRC=${1:-}
TARGET=${2:-$(uname -s 2>/dev/null || echo unknown)}

[ -n "$SRC" ] || {
    usage >&2
    exit 2
}

[ -e "$SRC" ] || err "el archivo o directorio no existe"

FORMAT=unknown
TYPE=unknown
ARCH=unknown
ACTION=inspect
STATUS="Compatibilidad no demostrada"
DETAIL=""

BASE=${SRC##*/}
LOWER=$(printf '%s' "$BASE" | tr '[:upper:]' '[:lower:]')

if [ -d "$SRC" ]; then
    TYPE=directory
    FORMAT=directory
elif [ -f "$SRC" ]; then
    case "$LOWER" in
        *.bp) FORMAT=bp ;;
        *.deb) FORMAT=deb ;;
        *.rpm) FORMAT=rpm ;;
        *.msi) FORMAT=msi ;;
        *.exe) FORMAT=exe ;;
        *.appimage) FORMAT=appimage ;;
        *.zip) FORMAT=zip ;;
        *.tar) FORMAT=tar ;;
        *.tar.gz|*.tgz) FORMAT=tar.gz ;;
        *.tar.xz|*.txz) FORMAT=tar.xz ;;
        *.tar.zst|*.tzst) FORMAT=tar.zst ;;
        *.apk)
            FORMAT=apk
            ;;
        *.pkg.tar|*.pkg.tar.gz|*.pkg.tar.xz|*.pkg.tar.zst)
            FORMAT=arch-package
            ;;
    esac

    if command -v file >/dev/null 2>&1; then
        DESC=$(file -b "$SRC" 2>/dev/null || echo unknown)

        case "$DESC" in
            *ELF*)
                TYPE=elf
                ;;
            *PE32*|*PE32+*)
                TYPE=windows-executable
                ;;
            *Mach-O*)
                TYPE=mach-o
                ;;
            *script*|*text*)
                TYPE=script-or-source
                ;;
            *Zip*|*archive*|*gzip*|*XZ*|*Zstandard*)
                TYPE=archive
                ;;
            *)
                TYPE=data
                ;;
        esac

        case "$DESC" in
            *x86-64*|*x86_64*)
                ARCH=amd64
                ;;
            *80386*|*i386*)
                ARCH=i386
                ;;
            *ARM\ aarch64*|*aarch64*)
                ARCH=arm64
                ;;
            *ARM*)
                ARCH=arm
                ;;
            *PowerPC*64*)
                ARCH=ppc64
                ;;
            *RISC-V*)
                ARCH=riscv
                ;;
        esac
    else
        TYPE=unknown
    fi
else
    err "el origen no es un archivo regular ni un directorio"
fi

HOST_ARCH=$(uname -m 2>/dev/null || echo unknown)

case "$HOST_ARCH" in
    x86_64|amd64) HOST_ARCH=amd64 ;;
    i?86) HOST_ARCH=i386 ;;
    aarch64|arm64) HOST_ARCH=arm64 ;;
    arm*) HOST_ARCH=arm ;;
    ppc64le) HOST_ARCH=ppc64le ;;
    riscv64) HOST_ARCH=riscv64 ;;
esac

case "$FORMAT" in
    bp)
        ACTION=verify
        STATUS="Debe verificarse con Bacus-Pkg antes de instalar"
        DETAIL="El formato .bp no garantiza por sí solo que el paquete sea compatible con el destino."
        ;;
    deb)
        ACTION=native-or-convert
        STATUS="Paquete Debian; requiere dpkg/apt o un conversor compatible"
        DETAIL="La conversión debe conservar archivos, metadatos, permisos y dependencias."
        ;;
    rpm)
        ACTION=native-or-convert
        STATUS="Paquete RPM; requiere un gestor RPM o un adaptador"
        DETAIL="La compatibilidad depende de la distribución y de las dependencias."
        ;;
    apk)
        ACTION=identify
        STATUS="Formato APK ambiguo; hay que identificar el contenido"
        DETAIL="APK puede ser un paquete de Alpine Linux o un paquete de Android."
        ;;
    arch-package)
        ACTION=native-or-convert
        STATUS="Paquete de Arch Linux; requiere pacman o un adaptador"
        ;;
    msi|exe)
        ACTION=adapter
        STATUS="Formato de Windows; no es instalable directamente en cualquier sistema"
        DETAIL="Puede requerir Windows, Wine u otra capa compatible."
        ;;
    appimage)
        ACTION=inspect
        STATUS="Aplicación Linux portable; hay que comprobar arquitectura y bibliotecas"
        ;;
    zip|tar|tar.gz|tar.xz|tar.zst)
        ACTION=convert-or-inspect
        STATUS="Archivo contenedor; necesita extracción segura y análisis de su contenido"
        DETAIL="Un archivo comprimido no es necesariamente un instalador."
        ;;
    directory)
        ACTION=convert-or-inspect
        STATUS="Directorio importable; hay que identificar archivos, permisos y punto de entrada"
        ;;
esac

case "$TYPE:$TARGET" in
    elf:Linux)
        STATUS="$STATUS; ejecutable ELF detectado para un destino Linux"
        ;;
    windows-executable:Windows*|windows-executable:MINGW*|windows-executable:CYGWIN*)
        STATUS="$STATUS; ejecutable PE detectado"
        ;;
    mach-o:Darwin)
        STATUS="$STATUS; ejecutable Mach-O detectado para macOS"
        ;;
    script-or-source:*)
        DETAIL="${DETAIL:+$DETAIL }Hay que comprobar el intérprete, los permisos y las dependencias."
        ;;
esac

printf '%s\n' "Bacus-Pkg Bridge v$VERSION"
printf 'Archivo: %s\n' "$SRC"
printf 'Formato: %s\n' "$FORMAT"
printf 'Tipo detectado: %s\n' "$TYPE"
printf 'Arquitectura detectada: %s\n' "$ARCH"
printf 'Arquitectura del sistema actual: %s\n' "$HOST_ARCH"
printf 'Destino solicitado: %s\n' "$TARGET"
printf 'Acción recomendada: %s\n' "$ACTION"
printf 'Resultado: %s\n' "$STATUS"

if [ -n "$DETAIL" ]; then
    printf 'Detalle: %s\n' "$DETAIL"
fi

printf '%s\n' \
    "Seguridad: el analizador no ejecuta ni instala el archivo." \
    "Nota: la detección por extensión o por tipo de archivo no demuestra compatibilidad."
