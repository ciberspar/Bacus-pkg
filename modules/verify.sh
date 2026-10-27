
#!/bin/sh
# Bacus-Pkg BP v1.0 - Binary Package Verifier
set -eu
umask 077

err() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 2
}

[ "$#" -eq 1 ] || err "Uso: verify PAQUETE.bp"

PACKAGE=$1

[ -f "$PACKAGE" ] || err "El archivo no existe o no es un archivo regular: $PACKAGE"
command -v python3 >/dev/null 2>&1 || err "Se necesita Python 3"

exec python3 - "$PACKAGE" <<'PY'
import hashlib
import os
import re
import struct
import sys
from urllib.parse import unquote_to_bytes

MAGIC = b"BACUSBP1"
HEADER_SIZE = 44
VERSION = 0x00010000
ENTRY = struct.Struct("<IB3sQQQ32s")
CHUNK = 1024 * 1024


def fail(message):
    print("ERROR: " + message, file=sys.stderr)
    raise SystemExit(2)


def read_exact(stream, size, label):
    data = stream.read(size)
    if len(data) != size:
        fail("Datos incompletos al leer " + label)
    return data


def decode_value(value, label):
    raw = bytearray()
    i = 0

    while i < len(value):
        ch = value[i]
        if ch == "%":
            if i + 2 >= len(value):
                fail("Escape porcentual incompleto en " + label)
            pair = value[i + 1:i + 3]
            if not re.fullmatch(r"[0-9A-Fa-f]{2}", pair):
                fail("Escape porcentual inválido en " + label)
            raw.append(int(pair, 16))
            i += 3
        else:
            code = ord(ch)
            if code > 127:
                fail("El manifiesto debe codificar bytes no ASCII con %HH")
            if ch in "\r\n":
                fail("Salto de línea inválido en " + label)
            raw.append(code)
            i += 1

    try:
        return raw.decode("utf-8", errors="strict")
    except UnicodeDecodeError:
        fail("Valor UTF-8 inválido en " + label)


def safe_path(path):
    if not path:
        return False
    if "\x00" in path or "\\" in path:
        return False
    if path.startswith("/"):
        return False
    if re.match(r"^[A-Za-z]:", path):
        return False

    parts = path.split("/")
    if any(part in ("", ".", "..") for part in parts):
        return False

    return True


def main():
    filename = sys.argv[1]
    total_size = os.path.getsize(filename)

    with open(filename, "rb") as stream:
        header = read_exact(stream, HEADER_SIZE, "la cabecera")

        magic, header_size, version, flags, manifest_size, table_size, payload_size = (
            struct.unpack("<8sIIIQQQ", header)
        )

        if magic != MAGIC:
            fail("Magic incorrecto; no es un paquete BP v1")
        if header_size != HEADER_SIZE:
            fail("Tamaño de cabecera incompatible")
        if version != VERSION:
            fail("Versión BP no compatible")
        if flags != 0:
            fail("El paquete contiene flags no admitidos")

        expected_size = HEADER_SIZE + manifest_size + table_size + payload_size
        if expected_size != total_size:
            fail("El tamaño total no coincide con la cabecera")

        # El manifiesto es metadato, no el contenido completo del paquete.
        manifest_limit = int(os.environ.get("BACUSP_MAX_MANIFEST_BYTES", str(16 * 1024 * 1024)))
        if manifest_limit < 1:
            fail("BACUSP_MAX_MANIFEST_BYTES debe ser positivo")
        if manifest_size > manifest_limit:
            fail("Manifiesto demasiado grande; ajusta BACUSP_MAX_MANIFEST_BYTES si es legítimo")

        manifest_bytes = read_exact(stream, manifest_size, "el manifiesto")

        if not manifest_bytes.endswith(b"\n"):
            fail("El manifiesto debe terminar con LF")
        if b"\r" in manifest_bytes or b"\x00" in manifest_bytes:
            fail("El manifiesto contiene CR o NUL")

        try:
            manifest_text = manifest_bytes.decode("utf-8", errors="strict")
        except UnicodeDecodeError:
            fail("El manifiesto no es UTF-8 válido")

        manifest = {}
        for line in manifest_text[:-1].split("\n"):
            if not line or "=" not in line:
                fail("Línea de manifiesto inválida")
            key, value = line.split("=", 1)

            if not re.fullmatch(r"[a-z][a-z0-9_]*", key):
                fail("Clave de manifiesto inválida: " + key)
            if key in manifest:
                fail("Clave duplicada en el manifiesto: " + key)

            manifest[key] = decode_value(value, key)

        required = (
            "package_name",
            "version",
            "description",
            "target_os",
            "target_arch",
            "payload_format",
            "entrypoint",
            "file_count",
        )
        for key in required:
            if key not in manifest:
                fail("Falta el campo obligatorio: " + key)

        if not re.fullmatch(r"[A-Za-z0-9._+-]+", manifest["package_name"]):
            fail("Nombre de paquete inválido")
        if not manifest["version"]:
            fail("La versión del paquete está vacía")
        if not manifest["target_os"] or not manifest["target_arch"]:
            fail("target_os y target_arch no pueden estar vacíos")
        if manifest["payload_format"] != "raw-v1":
            fail("Formato de payload no compatible")

        try:
            declared_count = int(manifest["file_count"], 10)
        except ValueError:
            fail("file_count no es un entero")

        if declared_count < 0:
            fail("file_count no puede ser negativo")

        # Cada entrada necesita al menos su estructura fija y un path.
        if declared_count > table_size // (ENTRY.size + 1):
            fail("La tabla no puede contener la cantidad declarada de archivos")

        entries = []
        seen_paths = set()
        previous_path = None
        table_remaining = table_size
        expected_offset = 0

        for _ in range(declared_count):
            if table_remaining < ENTRY.size:
                fail("Tabla de archivos truncada")

            fixed = read_exact(stream, ENTRY.size, "una entrada de la tabla")
            table_remaining -= ENTRY.size

            path_len, file_type, reserved, offset, stored_size, original_size, digest = (
                ENTRY.unpack(fixed)
            )

            if path_len == 0 or path_len > table_remaining:
                fail("Longitud de ruta inválida")

            path_bytes = read_exact(stream, path_len, "una ruta")
            table_remaining -= path_len

            try:
                path = path_bytes.decode("utf-8", errors="strict")
            except UnicodeDecodeError:
                fail("Una ruta no contiene UTF-8 válido")

            if not safe_path(path):
                fail("Ruta insegura: " + repr(path))
            if path_bytes in seen_paths:
                fail("Ruta duplicada: " + path)
            if previous_path is not None and path_bytes <= previous_path:
                fail("Las rutas no están ordenadas estrictamente por bytes")
            previous_path = path_bytes
            seen_paths.add(path_bytes)

            if reserved != b"\x00\x00\x00":
                fail("Bytes reservados distintos de cero en: " + path)
            if file_type not in (0, 1):
                fail("Tipo de archivo desconocido en: " + path)

            if file_type == 1:
                if offset != 0 or stored_size != 0 or original_size != 0:
                    fail("Metadatos inválidos para directorio: " + path)
                if digest != b"\x00" * 32:
                    fail("El hash de un directorio debe ser cero: " + path)
            else:
                if stored_size != original_size:
                    fail("raw-v1 no permite tamaños comprimidos: " + path)
                if offset != expected_offset:
                    fail("Los offsets del payload no son contiguos: " + path)
                if stored_size > payload_size - expected_offset:
                    fail("Archivo fuera del payload: " + path)
                expected_offset += stored_size

            entries.append({
                "path": path,
                "type": file_type,
                "offset": offset,
                "stored_size": stored_size,
                "original_size": original_size,
                "digest": digest,
            })

        if table_remaining != 0:
            fail("Sobran bytes en la tabla de archivos")
        if expected_offset != payload_size:
            fail("El payload contiene bytes no referenciados")
        if stream.tell() != HEADER_SIZE + manifest_size + table_size:
            fail("Posición de lectura inesperada antes del payload")

        by_path = {entry["path"]: entry for entry in entries}
        entrypoint = manifest["entrypoint"]

        if entrypoint:
            if not safe_path(entrypoint):
                fail("entrypoint contiene una ruta insegura")
            target = by_path.get(entrypoint)
            if target is None or target["type"] != 0:
                fail("entrypoint no apunta a un archivo regular del paquete")

        # Comprueba cada SHA-256 leyendo el payload por bloques.
        for entry in entries:
            if entry["type"] == 1:
                continue

            stream.seek(
                HEADER_SIZE + manifest_size + table_size + entry["offset"]
            )
            remaining = entry["stored_size"]
            digest = hashlib.sha256()

            while remaining:
                chunk = stream.read(min(CHUNK, remaining))
                if not chunk:
                    fail("Payload truncado en: " + entry["path"])
                digest.update(chunk)
                remaining -= len(chunk)

            if digest.digest() != entry["digest"]:
                fail("SHA-256 incorrecto: " + entry["path"])

    print("OK: paquete BP válido")
    print("Nombre: " + manifest["package_name"])
    print("Versión: " + manifest["version"])
    print("Archivos y directorios: " + str(len(entries)))
    print("Payload: " + str(payload_size) + " bytes")
    print("Tamaño total: " + str(total_size) + " bytes")
    print("SHA-256 de los archivos: verificado")
    return 0


try:
    sys.exit(main())
except (OSError, OverflowError, struct.error, ValueError) as exc:
    fail(str(exc))
PY
