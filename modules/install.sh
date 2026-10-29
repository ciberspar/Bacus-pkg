
#!/bin/sh
#
# BACUSP - Universal Package Installer
# Project: Bacus-Pkg
# BP v1 + native package adapters
# POSIX shell / Python 3
# Languages: Spanish / English
#

set -eu
umask 077

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
VERIFY="$SCRIPT_DIR/verify.sh"

BACUSP_HOME=${BACUSP_HOME:-"${HOME:-/tmp}/.bacusp"}
APP_ROOT="$BACUSP_HOME/apps"
CACHE_ROOT="$BACUSP_HOME/cache"

usage() {
    cat <<'EOF'
Bacus-Pkg - Instalador universal / Universal installer

Uso / Usage:
  bacusp install ARCHIVO.bp
  bacusp install ARCHIVO.deb
  bacusp install ARCHIVO.rpm
  bacusp install ARCHIVO.apk
  bacusp install ARCHIVO.pkg.tar.zst
  bacusp install NOMBRE

Los nombres requieren un gestor de paquetes compatible.
Package names require a compatible package manager.
EOF
}

error() {
    printf 'Error: %s\n' "$*" >&2
}

if [ "$#" -ne 1 ]; then
    usage
    exit 2
fi

INPUT=$1

case "$INPUT" in
    ""|-*)
        error "nombre o ruta inválidos / invalid name or path"
        exit 2
        ;;
esac

if ! command -v python3 >/dev/null 2>&1; then
    error "se necesita Python 3 / Python 3 is required"
    exit 1
fi

# --------------------------------------------------
# 1. Install BP v1 packages
# --------------------------------------------------

case "$INPUT" in
    *.bp)
        if [ ! -f "$INPUT" ] || [ -L "$INPUT" ]; then
            error "se requiere un archivo .bp regular, no un enlace"
            exit 1
        fi

        if [ ! -f "$VERIFY" ]; then
            error "falta modules/verify.sh"
            exit 1
        fi

        # Verify the package before extracting anything.
        if ! sh "$VERIFY" "$INPUT"; then
            error "el paquete BP no pasó la verificación"
            exit 1
        fi

        mkdir -p "$APP_ROOT"
        chmod 700 "$BACUSP_HOME" "$APP_ROOT" 2>/dev/null || :

        exec python3 - "$INPUT" "$APP_ROOT" <<'PY'
import os
import sys
import re
import struct
import hashlib
import tempfile
import shutil
import platform
from urllib.parse import unquote_to_bytes

HEADER = struct.Struct("<8sIIIQQQ")
ENTRY = struct.Struct("<IB3sQQQ32s")
MAGIC = b"BACUSBP1"
FORMAT_VERSION = 0x00010000
CHUNK = 1024 * 1024

def fail(message):
    raise SystemExit("Error: " + message)

def exact(stream, size):
    data = stream.read(size)
    if len(data) != size:
        fail("paquete truncado")
    return data

def safe_component(value, label):
    if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9._+-]*", value):
        fail(label + " contiene caracteres no permitidos")
    if value in (".", ".."):
        fail(label + " inválido")
    return value

def safe_path(raw):
    try:
        path = raw.decode("utf-8")
    except UnicodeDecodeError:
        fail("ruta no válida en UTF-8")

    if (
        not path
        or path.startswith("/")
        or "\\" in path
        or "\x00" in path
        or re.match(r"^[A-Za-z]:", path)
    ):
        fail("ruta insegura")

    if any(part in ("", ".", "..") for part in path.split("/")):
        fail("ruta insegura: " + path)

    return path

def parse_manifest(data):
    if not data.endswith(b"\n") or b"\r" in data or b"\x00" in data:
        fail("formato de manifiesto inválido")

    try:
        lines = data.decode("utf-8").splitlines()
    except UnicodeDecodeError:
        fail("manifiesto no válido en UTF-8")

    result = {}

    for line in lines:
        if not line or "=" not in line:
            fail("línea de manifiesto inválida")

        key, value = line.split("=", 1)

        if not re.fullmatch(r"[a-z][a-z0-9_]*", key):
            fail("clave de manifiesto inválida")

        if key in result:
            fail("clave duplicada: " + key)

        try:
            decoded = unquote_to_bytes(value).decode("utf-8")
        except (UnicodeDecodeError, ValueError):
            fail("valor de manifiesto inválido")

        # Reject malformed percent escapes.
        if re.search(r"%(?![0-9A-Fa-f]{2})", value):
            fail("escape porcentual inválido")

        result[key] = decoded

    required = (
        "package_name", "version", "description",
        "target_os", "target_arch", "payload_format",
        "entrypoint", "file_count"
    )

    for key in required:
        if key not in result:
            fail("falta el campo " + key)

    if result["payload_format"] != "raw-v1":
        fail("formato de payload no compatible")

    try:
        count = int(result["file_count"], 10)
    except ValueError:
        fail("file_count inválido")

    if count < 0:
        fail("file_count negativo")

    return result, count

def check_target(manifest):
    target_os = manifest["target_os"].lower()
    target_arch = manifest["target_arch"].lower()
    current_os = sys.platform.lower()
    machine = platform.machine().lower()

    allowed_os = ("any", "unix", "linux", "debian", "chiquios")

    if target_os not in allowed_os:
        fail("sistema objetivo no compatible: " + target_os)

    if target_os == "linux" and not current_os.startswith("linux"):
        fail("este paquete requiere Linux")

    if target_os == "debian" and not (
        current_os.startswith("linux")
        and os.path.exists("/etc/debian_version")
    ):
        fail("este paquete requiere Debian o un sistema derivado compatible")

    aliases = {
        "any": ("any",),
        "amd64": ("x86_64", "amd64"),
        "x86_64": ("x86_64", "amd64"),
        "i386": ("i386", "i486", "i586", "i686", "x86"),
        "i486": ("i386", "i486", "i586", "i686", "x86"),
        "i586": ("i386", "i486", "i586", "i686", "x86"),
        "i686": ("i386", "i486", "i586", "i686", "x86"),
        "x86": ("i386", "i486", "i586", "i686", "x86"),
        "arm64": ("aarch64", "arm64"),
        "aarch64": ("aarch64", "arm64"),
        "armhf": ("armv7l", "armhf"),
        "armv7l": ("armv7l", "armhf"),
        "riscv64": ("riscv64",),
        "ppc64el": ("ppc64le", "ppc64el"),
        "ppc64le": ("ppc64le", "ppc64el"),
    }

    if target_arch != "any":
        compatible = aliases.get(target_arch, (target_arch,))
        if machine not in compatible:
            fail(
                "arquitectura incompatible: paquete "
                + target_arch + ", sistema "
                + (machine or "desconocido")
            )

def main():
    package = os.path.abspath(sys.argv[1])
    app_root = os.path.realpath(sys.argv[2])

    if not os.path.isfile(package) or os.path.islink(package):
        fail("archivo de paquete inválido")

    stage = None

    try:
        with open(package, "rb") as stream:
            header = exact(stream, HEADER.size)
            magic, hsize, fmt, flags, msize, tsize, psize = HEADER.unpack(header)

            if magic != MAGIC or hsize != HEADER.size:
                fail("cabecera BP inválida")

            if fmt != FORMAT_VERSION or flags != 0:
                fail("versión BP no compatible")

            total = os.fstat(stream.fileno()).st_size

            if HEADER.size + msize + tsize + psize != total:
                fail("tamaños de sección incorrectos")

            max_manifest = 16 * 1024 * 1024
            if msize > max_manifest:
                fail("manifiesto demasiado grande")

            manifest, count = parse_manifest(exact(stream, msize))

            name = safe_component(manifest["package_name"], "package_name")
            version = safe_component(manifest["version"], "version")

            check_target(manifest)

            destination = os.path.join(app_root, name, version)

            if os.path.lexists(destination):
                fail("el paquete o la versión ya existen: " + destination)

            records = []
            table_used = 0
            previous = None
            next_offset = 0
            seen = set()

            # Bound the number of records by the table's actual size.
            if count > tsize // (ENTRY.size + 1):
                fail("cantidad de entradas inválida")

            stage = tempfile.mkdtemp(prefix=".bp-stage-", dir=app_root)

            for _ in range(count):
                raw_entry = exact(stream, ENTRY.size)
                table_used += ENTRY.size

                plen, kind, reserved, offset, stored, original, digest = ENTRY.unpack(raw_entry)

                if plen == 0 or reserved != bytes(3) or kind not in (0, 1):
                    fail("entrada inválida en la tabla")

                if plen > tsize - table_used:
                    fail("longitud de ruta fuera de la tabla")

                raw_path = exact(stream, plen)
                table_used += plen
                path = safe_path(raw_path)

                if raw_path in seen:
                    fail("ruta duplicada: " + path)

                if previous is not None and raw_path <= previous:
                    fail("rutas desordenadas")

                seen.add(raw_path)
                previous = raw_path

                if kind == 1:
                    if offset or stored or original or digest != bytes(32):
                        fail("metadatos de directorio inválidos")
                else:
                    if offset != next_offset or stored != original:
                        fail("offset o tamaño inválido: " + path)

                    if stored > psize - next_offset:
                        fail("archivo fuera del payload: " + path)

                    next_offset += stored

                records.append((path, kind, offset, stored, digest))

            if table_used != tsize or next_offset != psize:
                fail("tabla o payload inconsistente")

            # Reject file/directory path conflicts before extraction.
            kinds = {path: kind for path, kind, *_ in records}

            for path, kind, *_ in records:
                parts = path.split("/")
                for index in range(1, len(parts)):
                    parent = "/".join(parts[:index])
                    if kinds.get(parent) == 0:
                        fail("un archivo no puede ser directorio padre: " + parent)

            entrypoint = manifest["entrypoint"]
            if entrypoint:
                safe_path(entrypoint.encode("utf-8"))
                if kinds.get(entrypoint) != 0:
                    fail("entrypoint no apunta a un archivo del paquete")

            payload_start = HEADER.size + msize + tsize

            for path, kind, offset, stored, expected_digest in records:
                target = os.path.abspath(os.path.join(stage, *path.split("/")))

                if os.path.commonpath((stage, target)) != stage:
                    fail("ruta fuera del directorio temporal")

                if kind == 1:
                    os.makedirs(target, mode=0o755, exist_ok=True)
                    continue

                os.makedirs(os.path.dirname(target), mode=0o755, exist_ok=True)

                stream.seek(payload_start + offset)
                remaining = stored
                digest = hashlib.sha256()

                with open(target, "xb") as output:
                    while remaining:
                        block = stream.read(min(CHUNK, remaining))
                        if not block:
                            fail("payload truncado: " + path)

                        digest.update(block)
                        output.write(block)
                        remaining -= len(block)

                if digest.digest() != expected_digest:
                    fail("SHA-256 incorrecto: " + path)

                os.chmod(target, 0o755 if entrypoint == path else 0o644)

            os.makedirs(os.path.dirname(destination), mode=0o755, exist_ok=True)
            os.rename(stage, destination)
            stage = None

            print("Instalación BP completada / BP installation completed.")
            print("Paquete / Package:", name)
            print("Versión / Version:", version)
            print("Entradas / Entries:", count)
            print("Directorio / Directory:", destination)
            print("Aviso: la integridad no garantiza que el contenido sea inocuo.")

    finally:
        if stage and os.path.isdir(stage):
            shutil.rmtree(stage, ignore_errors=True)

try:
    main()
except (OSError, OverflowError, struct.error, ValueError) as exc:
    fail(str(exc))
PY
        ;;
esac

# --------------------------------------------------
# 2. Native package installation
# These formats may modify the operating system.
# --------------------------------------------------

is_root() {
    [ "$(id -u)" -eq 0 ]
}

run_native() {
    if is_root; then
        "$@"
    elif command -v sudo >/dev/null 2>&1; then
        sudo "$@"
    else
        error "se necesitan permisos de administrador / administrator permissions required"
        exit 1
    fi
}

case "$INPUT" in
    *.deb)
        [ -f "$INPUT" ] && [ ! -L "$INPUT" ] || {
            error "archivo .deb no encontrado o inválido"
            exit 1
        }

        printf '%s\n' "Se instalará un paquete nativo del sistema."
        printf '%s\n' "A native system package will be installed."
        printf '¿Continuar? Escribí SI / Continue? Type YES: '
        IFS= read -r ANSWER || exit 2

        case "$ANSWER" in
            SI|YES) ;;
            *) echo "Cancelado / Cancelled."; exit 0 ;;
        esac

        if command -v apt-get >/dev/null 2>&1; then
            run_native apt-get install -y "./$INPUT"
        elif command -v dpkg >/dev/null 2>&1; then
            echo "Aviso: dpkg no resuelve automáticamente todas las dependencias."
            run_native dpkg -i "$INPUT"
        else
            error "se necesita apt-get o dpkg"
            exit 1
        fi
        exit 0
        ;;

    *.rpm)
        [ -f "$INPUT" ] && [ ! -L "$INPUT" ] || {
            error "archivo .rpm no encontrado o inválido"
            exit 1
        }

        printf '%s\n' "Se instalará un paquete nativo del sistema."
        printf '¿Continuar? Escribí SI / Continue? Type YES: '
        IFS= read -r ANSWER || exit 2
        case "$ANSWER" in SI|YES) ;; *) exit 0 ;; esac

        if command -v dnf >/dev/null 2>&1; then
            run_native dnf install -y "$INPUT"
        elif command -v zypper >/dev/null 2>&1; then
            run_native zypper --non-interactive install "$INPUT"
        elif command -v yum >/dev/null 2>&1; then
            run_native yum install -y "$INPUT"
        else
            error "se necesita dnf, zypper o yum"
            exit 1
        fi
        exit 0
        ;;

    *.apk)
        [ -f "$INPUT" ] && [ ! -L "$INPUT" ] || {
            error "archivo .apk no encontrado o inválido"
            exit 1
        }

        printf '%s\n' "Se instalará un paquete nativo del sistema."
        printf '¿Continuar? Escribí SI / Continue? Type YES: '
        IFS= read -r ANSWER || exit 2
        case "$ANSWER" in SI|YES) ;; *) exit 0 ;; esac

        command -v apk >/dev/null 2>&1 || {
            error "no se encontró el gestor apk de Alpine Linux"
            exit 1
        }
        run_native apk add -- "$INPUT"
        exit 0
        ;;

    *.pkg.tar.zst|*.pkg.tar.xz|*.pkg.tar.gz)
        [ -f "$INPUT" ] && [ ! -L "$INPUT" ] || {
            error "paquete de Arch no encontrado o inválido"
            exit 1
        }

        printf '%s\n' "Se instalará un paquete nativo del sistema."
        printf '¿Continuar? Escribí SI / Continue? Type YES: '
        IFS= read -r ANSWER || exit 2
        case "$ANSWER" in SI|YES) ;; *) exit 0 ;; esac

        command -v pacman >/dev/null 2>&1 || {
            error "se necesita pacman"
            exit 1
        }
        run_native pacman -U -- "$INPUT"
        exit 0
        ;;
esac

# --------------------------------------------------
# 3. Install by package name using system manager
# --------------------------------------------------

case "$INPUT" in
    */*|*://*)
        error "indica un nombre de paquete o archivo local"
        exit 2
        ;;
esac

# Termux
if [ -n "${PREFIX:-}" ] && [ -x "${PREFIX}/bin/pkg" ]; then
    exec "${PREFIX}/bin/pkg" install "$INPUT"
fi

if command -v apt-get >/dev/null 2>&1; then
    exec sh -c '
        if [ "$(id -u)" -eq 0 ]; then
            exec apt-get install -y -- "$1"
        elif command -v sudo >/dev/null 2>&1; then
            exec sudo apt-get install -y -- "$1"
        else
            echo "Error: se necesita root o sudo." >&2
            exit 1
        fi
    ' sh "$INPUT"
fi

if command -v dnf >/dev/null 2>&1; then
    exec sh -c '
        if [ "$(id -u)" -eq 0 ]; then
            exec dnf install -y "$1"
        elif command -v sudo >/dev/null 2>&1; then
            exec sudo dnf install -y "$1"
        else
            echo "Error: se necesita root o sudo." >&2
            exit 1
        fi
    ' sh "$INPUT"
fi

if command -v zypper >/dev/null 2>&1; then
    exec sh -c '
        if [ "$(id -u)" -eq 0 ]; then
            exec zypper install "$1"
        elif command -v sudo >/dev/null 2>&1; then
            exec sudo zypper install "$1"
        else
            echo "Error: se necesita root o sudo." >&2
            exit 1
        fi
    ' sh "$INPUT"
fi

if command -v apk >/dev/null 2>&1; then
    exec sh -c '
        if [ "$(id -u)" -eq 0 ]; then
            exec apk add "$1"
        elif command -v sudo >/dev/null 2>&1; then
            exec sudo apk add "$1"
        else
            echo "Error: se necesita root o sudo." >&2
            exit 1
        fi
    ' sh "$INPUT"
fi

if command -v pacman >/dev/null 2>&1; then
    exec sh -c '
        if [ "$(id -u)" -eq 0 ]; then
            exec pacman -S --needed "$1"
        elif command -v sudo >/dev/null 2>&1; then
            exec sudo pacman -S --needed "$1"
        else
            echo "Error: se necesita root o sudo." >&2
            exit 1
        fi
    ' sh "$INPUT"
fi

error "no se detectó un gestor de paquetes compatible"
printf '%s\n' \
    "Bacus-Pkg puede instalar paquetes BP, pero este sistema" \
    "necesita un adaptador nativo específico."
exit 3
