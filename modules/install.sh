#!/bin/sh
# BACUSP - Universal Package Installer
# BP v1 + Debian import + extensible external formats
# POSIX shell / Python 3
set -eu
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
VERIFY="$SCRIPT_DIR/verify.sh"
BACUSP_HOME=${BACUSP_HOME:-"$HOME/.bacusp"}
APP_ROOT="$BACUSP_HOME/apps"
CACHE_ROOT="$BACUSP_HOME/cache"
usage() {
    echo "Bacus-Pkg / Instalador universal"
    echo
    echo "Uso / Usage:"
    echo "  bacusp install ARCHIVO.bp"
    echo "  bacusp install ARCHIVO.deb"
    echo "  bacusp install ARCHIVO.rpm"
    echo "  bacusp install ARCHIVO.apk"
    echo "  bacusp install ARCHIVO.pkg.tar.zst"
    echo "  bacusp install NOMBRE"
    echo
    echo "Los nombres requieren un repositorio configurado."
    echo "Package names require a configured repository."
}
if [ "$#" -lt 1 ]; then
    usage
    exit 2
fi
INPUT=$1
mkdir -p "$APP_ROOT" "$CACHE_ROOT"
if ! command -v python3 >/dev/null 2>&1; then
    echo "Error: se necesita Python 3."
    exit 1
fi
# --------------------------------------------------
# 1. Install native BP v1 packages
# --------------------------------------------------
case "$INPUT" in
    *.bp)
        if [ ! -f "$INPUT" ]; then
            echo "Error: no se encuentra: $INPUT"
            exit 1
        fi
        if [ ! -f "$VERIFY" ]; then
            echo "Error: falta modules/verify.sh"
            exit 1
        fi
        sh "$VERIFY" "$INPUT"
        exec python3 - "$INPUT" "$APP_ROOT" <<'PY'
import os
import sys
import struct
import hashlib
import tempfile
import shutil
import re
from urllib.parse import unquote_to_bytes
package = os.path.abspath(sys.argv[1])
app_root = os.path.abspath(sys.argv[2])
HEADER = struct.Struct("<8sIIIQQQ")
ENTRY = struct.Struct("<IB3sQQQ32s")
MAGIC = b"BACUSBP1"
VERSION_FORMAT = 0x00010000
def fail(message):
    raise SystemExit("Error: " + message)
def safe_component(value, label):
    if not value or value in (".", ".."):
        fail(label + " inválido")
    if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9._+-]*", value):
        fail(label + " contiene caracteres no permitidos")
    return value
def exact(f, n):
    data = f.read(n)
    if len(data) != n:
        fail("paquete truncado")
    return data
def parse_manifest(data):
    try:
        lines = data.decode("utf-8").splitlines()
    except UnicodeDecodeError:
        fail("manifest UTF-8 inválido")
    result = {}
    for line in lines:
        if not line or "=" not in line:
            fail("línea de manifest inválida")
        key, value = line.split("=", 1)
        if not re.fullmatch(r"[a-z][a-z0-9_]*", key):
            fail("clave de manifest inválida")
        if key in result:
            fail("clave duplicada: " + key)
        try:
            value = unquote_to_bytes(value).decode("utf-8")
        except (UnicodeDecodeError, ValueError):
            fail("valor de manifest inválido")
        result[key] = value
    required = (
        "package_name", "version", "description",
        "target_os", "target_arch", "payload_format",
        "entrypoint", "file_count"
    )
    for key in required:
        if key not in result:
            fail("falta " + key)
    if result["payload_format"] != "raw-v1":
        fail("payload no compatible")
    try:
        count = int(result["file_count"])
    except ValueError:
        fail("file_count inválido")
    if count < 0:
        fail("file_count negativo")
    return result, count
def safe_path(raw):
    try:
        path = raw.decode("utf-8")
    except UnicodeDecodeError:
        fail("ruta no UTF-8")
    if not path or path.startswith("/") or "\\" in path or "\x00" in path:
        fail("ruta insegura")
    if any(part in ("", ".", "..") for part in path.split("/")):
        fail("ruta insegura: " + path)
    return path
stage = None
try:
    with open(package, "rb") as f:
        header = exact(f, HEADER.size)
        magic, hsize, fmt, flags, msize, tsize, psize = HEADER.unpack(header)
        if magic != MAGIC or hsize != HEADER.size:
            fail("cabecera BP inválida")
        if fmt != VERSION_FORMAT or flags != 0:
            fail("versión BP no compatible")
        total = os.fstat(f.fileno()).st_size
        if HEADER.size + msize + tsize + psize != total:
            fail("tamaños de sección incorrectos")
        manifest, count = parse_manifest(exact(f, msize))
        name = safe_component(manifest["package_name"], "package_name")
        version = safe_component(manifest["version"], "version")
        # Do not install a package that explicitly targets a different OS.
        current_os = sys.platform.lower()
        target_os = manifest["target_os"].lower()
        if target_os not in ("any", "unix", "linux", "debian", "chiquios"):
            fail("sistema objetivo no compatible: " + target_os)
        if target_os == "linux" and not current_os.startswith("linux"):
            fail("este paquete requiere Linux")
        destination = os.path.join(app_root, name, version)
        if os.path.exists(destination):
            fail("ya instalado: " + destination)
        stage = tempfile.mkdtemp(prefix=".bp-stage-", dir=app_root)
        records = []
        table_used = 0
        previous = None
        next_offset = 0
        for _ in range(count):
            raw_entry = exact(f, ENTRY.size)
            plen, kind, reserved, offset, stored, original, digest = ENTRY.unpack(raw_entry)
            table_used += ENTRY.size
            if plen == 0 or reserved != bytes(3) or kind not in (0, 1):
                fail("entrada inválida en la tabla")
            raw_path = exact(f, plen)
            table_used += plen
            path = safe_path(raw_path)
            if previous is not None and raw_path <= previous:
                fail("rutas duplicadas o desordenadas")
            previous = raw_path
            if kind == 1:
                if offset or stored or original or digest != bytes(32):
                    fail("directorio inválido")
            else:
                if offset != next_offset or stored != original:
                    fail("offset o tamaño inválido")
                next_offset += stored
            records.append((path, kind, offset, stored, digest))
        if table_used != tsize or next_offset != psize:
            fail("tabla o payload inconsistente")
        payload_start = HEADER.size + msize + tsize
        for path, kind, offset, stored, digest in records:
            target = os.path.abspath(os.path.join(stage, *path.split("/")))
            if os.path.commonpath((stage, target)) != stage:
                fail("ruta fuera del directorio temporal")
            if kind == 1:
                os.makedirs(target, exist_ok=True)
                continue
            os.makedirs(os.path.dirname(target), exist_ok=True)
            f.seek(payload_start + offset)
            remaining = stored
            sha = hashlib.sha256()
            with open(target, "xb") as out:
                while remaining:
                    block = f.read(min(1024 * 1024, remaining))
                    if not block:
                        fail("payload truncado")
                    sha.update(block)
                    out.write(block)
                    remaining -= len(block)
            if sha.digest() != digest:
                fail("SHA-256 incorrecto: " + path)
        entrypoint = manifest["entrypoint"]
        if entrypoint:
            ep = safe_path(entrypoint.encode("utf-8"))
            if not os.path.isfile(os.path.join(stage, *ep.split("/"))):
                fail("entrypoint inexistente")
        os.makedirs(os.path.dirname(destination), exist_ok=True)
        os.rename(stage, destination)
        stage = None
        print("Instalación BP completada.")
        print("Paquete:", name)
        print("Versión:", version)
        print("Archivos:", count)
        print("Directorio:", destination)
finally:
    if stage and os.path.isdir(stage):
        shutil.rmtree(stage, ignore_errors=True)
PY
        ;;
esac
# --------------------------------------------------
# 2. Real native package installation
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
        echo "Error: se necesitan permisos de administrador."
        echo "Ejecuta el comando como root o instala sudo."
        exit 1
    fi
}
# Install a local package using the native package manager.
case "$INPUT" in
    *.deb)
        [ -f "$INPUT" ] || {
            echo "Error: archivo .deb no encontrado."
            exit 1
        }
        if command -v apt-get >/dev/null 2>&1; then
            run_native apt-get install -y "./$INPUT"
        elif command -v dpkg >/dev/null 2>&1; then
            echo "Aviso: dpkg no resuelve automáticamente todas las dependencias."
            run_native dpkg -i "$INPUT"
            echo "Si faltan dependencias, ejecuta: sudo apt-get -f install"
        else
            echo "Error: se necesita apt-get o dpkg."
            exit 1
        fi
        exit
        ;;
    *.rpm)
        [ -f "$INPUT" ] || {
            echo "Error: archivo .rpm no encontrado."
            exit 1
        }
        if command -v dnf >/dev/null 2>&1; then
            run_native dnf install -y "$INPUT"
        elif command -v zypper >/dev/null 2>&1; then
            run_native zypper --non-interactive install "$INPUT"
        elif command -v yum >/dev/null 2>&1; then
            run_native yum install -y "$INPUT"
        else
            echo "Error: se necesita dnf, zypper o yum."
            exit 1
        fi
        exit
        ;;
    *.apk)
        [ -f "$INPUT" ] || {
            echo "Error: archivo .apk no encontrado."
            exit 1
        }
        if command -v apk >/dev/null 2>&1; then
            run_native apk add -- "$INPUT"
        else
            echo "Error: el gestor apk de Alpine Linux no está disponible."
            exit 1
        fi
        exit
        ;;
    *.pkg.tar.zst|*.pkg.tar.xz|*.pkg.tar.gz)
        [ -f "$INPUT" ] || {
            echo "Error: paquete de Arch no encontrado."
            exit 1
        }
        if command -v pacman >/dev/null 2>&1; then
            run_native pacman -U -- "$INPUT"
        else
            echo "Error: se necesita pacman."
            exit 1
        fi
        exit
        ;;
esac
# --------------------------------------------------
# 3. Install a package by name from configured repos
# --------------------------------------------------
case "$INPUT" in
    ""|-*)
        echo "Error: nombre de paquete inválido."
        exit 2
        ;;
esac
case "$INPUT" in
    */*|*://*)
        echo "Error: indica un nombre de paquete o un archivo local."
        echo "Las URL necesitan un adaptador con verificación de integridad."
        exit 2
        ;;
esac
# Termux
if [ -n "${PREFIX:-}" ] &&
   [ -x "${PREFIX}/bin/pkg" ]; then
    exec "${PREFIX}/bin/pkg" install "$INPUT"
fi
# Debian / Ubuntu and derivatives
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
# Fedora / RHEL
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
# openSUSE
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
# Alpine Linux
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
# Arch Linux
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
echo "No se detectó un gestor de paquetes compatible."
echo "Bacus-Pkg puede instalar paquetes BP, pero este sistema"
echo "necesita un adaptador nativo específico."
exit 3