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
# 2. Import external package formats
# --------------------------------------------------
case "$INPUT" in
    *.deb)
        if [ ! -f "$INPUT" ]; then
            echo "Error: no se encuentra: $INPUT"
            exit 1
        fi
        if ! command -v dpkg-deb >/dev/null 2>&1; then
            echo "Error: instala dpkg-deb para importar paquetes Debian."
            echo "En Debian/Ubuntu: sudo apt install dpkg"
            exit 1
        fi
        echo "Paquete Debian detectado."
        echo "La importación a BP requiere el adaptador convert de Bacus-Pkg."
        echo "No se instalará directamente en el sistema."
        echo "Usa: bacusp convert \"$INPUT\" ./paquete.bp"
        exit 3
        ;;
    *.rpm)
        echo "Formato RPM detectado."
        echo "Falta implementar el adaptador RPM."
        echo "No se ejecutará ni instalará el paquete automáticamente."
        exit 3
        ;;
    *.apk)
        echo "Formato APK de Alpine detectado."
        echo "Falta implementar el adaptador APK de Alpine."
        exit 3
        ;;
    *.pkg.tar.zst|*.pkg.tar.xz|*.pkg.tar.gz)
        echo "Paquete de Arch Linux detectado."
        echo "Falta implementar el adaptador de paquetes Arch."
        exit 3
        ;;
    *.tar|*.tar.gz|*.tgz|*.tar.xz|*.tar.zst|*.zip)
        echo "Archivo comprimido detectado."
        echo "Un archivo comprimido no es automáticamente un paquete instalable."
        echo "Convierte su contenido a BP usando un adaptador seguro."
        exit 3
        ;;
    http://*|https://*)
        echo "URL detectada."
        echo "La instalación desde URL requiere un repositorio configurado"
        echo "o un adaptador con verificación de integridad y procedencia."
        exit 3
        ;;
esac
# --------------------------------------------------
# 3. Repository package names
# --------------------------------------------------
case "$INPUT" in
    -*)
        echo "Error: argumento no válido."
        exit 2
        ;;
esac
echo "No se encontró un adaptador para: $INPUT"
echo "Si es un nombre de paquete, configura primero un repositorio."
echo "Bacus-Pkg aún no tiene un índice universal de todos los repositorios."
exit 3