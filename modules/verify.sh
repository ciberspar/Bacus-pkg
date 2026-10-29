
#!/bin/sh
# BACUSP - BP v1 Verifier
# Bilingual-ready package integrity checker

set -eu
umask 077

if [ "$#" -ne 1 ]; then
    printf '%s\n' \
        "Uso: bacusp verify PAQUETE.bp" \
        "Usage: bacusp verify PACKAGE.bp" >&2
    exit 2
fi

PACKAGE=$1

if [ ! -f "$PACKAGE" ] || [ -L "$PACKAGE" ]; then
    printf '%s\n' "ERROR: se requiere un archivo regular, no un enlace." >&2
    exit 2
fi

command -v python3 >/dev/null 2>&1 || {
    printf '%s\n' "ERROR: se necesita Python 3." >&2
    exit 2
}

exec python3 - "$PACKAGE" <<'PY'
import os
import sys
import re
import struct
import hashlib

MAGIC = b"BACUSBP1"
HEADER = struct.Struct("<8sIIIQQQ")
ENTRY = struct.Struct("<IB3sQQQ32s")
VERSION = 0x00010000
CHUNK = 1024 * 1024

def fail(message):
    print("ERROR:", message, file=sys.stderr)
    raise SystemExit(2)

def exact(stream, size, label):
    data = stream.read(size)
    if len(data) != size:
        fail("datos incompletos: " + label)
    return data

def decode_value(value, label):
    result = bytearray()
    i = 0
    while i < len(value):
        if value[i] == "%":
            if i + 2 >= len(value):
                fail("escape porcentual incompleto: " + label)
            pair = value[i + 1:i + 3]
            if not re.fullmatch(r"[0-9A-Fa-f]{2}", pair):
                fail("escape porcentual inválido: " + label)
            result.append(int(pair, 16))
            i += 3
        else:
            code = ord(value[i])
            if code > 127 or value[i] in "\r\n":
                fail("carácter no permitido: " + label)
            result.append(code)
            i += 1
    try:
        return result.decode("utf-8", errors="strict")
    except UnicodeDecodeError:
        fail("valor UTF-8 inválido: " + label)

def safe_path(path):
    if not path or "\x00" in path or "\\" in path:
        return False
    if path.startswith("/") or re.match(r"^[A-Za-z]:", path):
        return False
    return not any(part in ("", ".", "..") for part in path.split("/"))

def main():
    filename = sys.argv[1]
    total_size = os.path.getsize(filename)

    with open(filename, "rb") as stream:
        header = exact(stream, HEADER.size, "cabecera")
        magic, hsize, version, flags, msize, tsize, psize = HEADER.unpack(header)

        if magic != MAGIC:
            fail("no es un paquete BP v1")
        if hsize != HEADER.size or version != VERSION:
            fail("versión o tamaño de cabecera incompatible")
        if flags != 0:
            fail("flags no admitidos")
        if HEADER.size + msize + tsize + psize != total_size:
            fail("el tamaño total no coincide con la cabecera")

        limit = int(os.environ.get(
            "BACUSP_MAX_MANIFEST_BYTES", str(16 * 1024 * 1024)
        ))
        if limit < 1 or msize > limit:
            fail("manifiesto demasiado grande o límite inválido")

        raw_manifest = exact(stream, msize, "manifiesto")
        if (
            not raw_manifest.endswith(b"\n")
            or b"\r" in raw_manifest
            or b"\x00" in raw_manifest
        ):
            fail("formato de manifiesto inválido")

        try:
            lines = raw_manifest.decode("utf-8").splitlines()
        except UnicodeDecodeError:
            fail("manifiesto no válido en UTF-8")

        manifest = {}
        for line in lines:
            if not line or "=" not in line:
                fail("línea de manifiesto inválida")
            key, value = line.split("=", 1)
            if not re.fullmatch(r"[a-z][a-z0-9_]*", key):
                fail("clave inválida: " + key)
            if key in manifest:
                fail("clave duplicada: " + key)
            manifest[key] = decode_value(value, key)

        required = (
            "package_name", "version", "description", "target_os",
            "target_arch", "payload_format", "entrypoint", "file_count"
        )
        for key in required:
            if key not in manifest:
                fail("falta el campo: " + key)

        if not re.fullmatch(
            r"[A-Za-z0-9._+-]+", manifest["package_name"]
        ):
            fail("nombre de paquete inválido")
        if not manifest["version"]:
            fail("versión vacía")
        if not manifest["target_os"] or not manifest["target_arch"]:
            fail("target_os o target_arch vacío")
        if manifest["payload_format"] != "raw-v1":
            fail("payload_format no compatible")

        try:
            count = int(manifest["file_count"], 10)
        except ValueError:
            fail("file_count inválido")

        if count < 0 or count > tsize // (ENTRY.size + 1):
            fail("cantidad de entradas inválida")

        entries = []
        seen = set()
        previous = None
        table_remaining = tsize
        expected_offset = 0

        for _ in range(count):
            if table_remaining < ENTRY.size:
                fail("tabla truncada")

            fixed = exact(stream, ENTRY.size, "entrada de tabla")
            table_remaining -= ENTRY.size
            plen, kind, reserved, offset, stored, original, digest = ENTRY.unpack(fixed)

            if plen == 0 or plen > table_remaining:
                fail("longitud de ruta inválida")

            raw_path = exact(stream, plen, "ruta")
            table_remaining -= plen

            try:
                path = raw_path.decode("utf-8")
            except UnicodeDecodeError:
                fail("ruta no válida en UTF-8")

            if not safe_path(path):
                fail("ruta insegura: " + repr(path))
            if raw_path in seen:
                fail("ruta duplicada: " + path)
            if previous is not None and raw_path <= previous:
                fail("las rutas deben estar ordenadas por bytes")

            seen.add(raw_path)
            previous = raw_path

            if reserved != b"\x00\x00\x00" or kind not in (0, 1):
                fail("tipo o bytes reservados inválidos")

            if kind == 1:
                if offset or stored or original or digest != bytes(32):
                    fail("metadatos inválidos para directorio: " + path)
            else:
                if stored != original or offset != expected_offset:
                    fail("tamaño u offset inválido: " + path)
                if stored > psize - expected_offset:
                    fail("archivo fuera del payload: " + path)
                expected_offset += stored

            entries.append((path, kind, offset, stored, digest))

        if table_remaining != 0:
            fail("sobran bytes en la tabla")
        if expected_offset != psize:
            fail("el payload contiene bytes no referenciados")

        by_path = {path: kind for path, kind, *_ in entries}
        entrypoint = manifest["entrypoint"]

        if entrypoint:
            if not safe_path(entrypoint):
                fail("entrypoint inseguro")
            if by_path.get(entrypoint) != 0:
                fail("entrypoint no apunta a un archivo regular")

        payload_start = HEADER.size + msize + tsize

        for path, kind, offset, stored, expected_digest in entries:
            if kind == 1:
                continue

            stream.seek(payload_start + offset)
            remaining = stored
            digest = hashlib.sha256()

            while remaining:
                block = stream.read(min(CHUNK, remaining))
                if not block:
                    fail("payload truncado: " + path)
                digest.update(block)
                remaining -= len(block)

            if digest.digest() != expected_digest:
                fail("SHA-256 incorrecto: " + path)

    print("OK: paquete BP válido")
    print("Nombre:", manifest["package_name"])
    print("Versión:", manifest["version"])
    print("Entradas:", len(entries))
    print("Payload:", psize, "bytes")
    print("Tamaño total:", total_size, "bytes")
    print("Integridad SHA-256: verificada")
    print("Aviso: la integridad no garantiza que el contenido sea inocuo.")
    return 0

try:
    sys.exit(main())
except (OSError, OverflowError, struct.error, ValueError) as exc:
    fail(str(exc))
PY
