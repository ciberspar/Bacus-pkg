
#!/bin/sh
# Bacus-Pkg - BP v1 converter
# Usage:
#   bacusp convert SOURCE [DESTINATION.bp]
#   bacusp convert -portable SOURCE [DESTINATION.bp]

set -eu
umask 077

err() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 2
}

PORTABLE=0

if [ "${1:-}" = "-portable" ]; then
    PORTABLE=1
    shift
fi

SOURCE=${1:-}
[ -n "$SOURCE" ] || err "Uso: bacusp convert [-portable] SOURCE [DESTINATION.bp]"
shift

DESTINATION=${1:-}
shift || true
[ "$#" -eq 0 ] || err "Demasiados argumentos."

[ -f "$SOURCE" ] || err "El archivo de origen no existe o no es un archivo regular."
[ ! -L "$SOURCE" ] || err "No se admiten enlaces simbólicos como origen."

python3 - "$SOURCE" "$DESTINATION" "$PORTABLE" <<'PY'
import os
import sys
import re
import stat
import hashlib
import struct
import tempfile
from pathlib import Path

source_arg, destination_arg, portable_arg = sys.argv[1:]
source = Path(source_arg).absolute()

if not source.is_file() or source.is_symlink():
    sys.exit("ERROR: El origen debe ser un archivo regular, no un enlace simbólico.")

if portable_arg not in ("0", "1"):
    sys.exit("ERROR: Opción portable no válida.")

portable = portable_arg == "1"
stem = source.stem or source.name
safe_name = re.sub(r"[^A-Za-z0-9._+-]", "-", stem).strip(".-+")
if not safe_name:
    safe_name = "imported-artifact"

if destination_arg:
    destination = Path(destination_arg).absolute()
    if destination.suffix.lower() != ".bp":
        sys.exit("ERROR: El destino debe terminar en .bp.")
else:
    suffix = "-portable.bp" if portable else ".bp"
    destination = source.with_name(safe_name + suffix)

if destination == source:
    sys.exit("ERROR: El origen y el destino no pueden ser el mismo archivo.")

if destination.exists() or destination.is_symlink():
    sys.exit("ERROR: El destino ya existe; no se sobrescribirá.")

if not destination.parent.is_dir():
    sys.exit("ERROR: La carpeta de destino no existe.")

MAGIC = b"BACUSBP1"
VERSION = 0x00010000
HEADER = struct.Struct("<8sIIIQQQ")
ENTRY = struct.Struct("<IB3sQQQ32s")

# Copy the source to a temporary file while calculating its hash.
digest = hashlib.sha256()
size = 0
payload_tmp = None
output_tmp = None

def encode_value(value):
    safe = b"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789._+-/"
    out = []
    for byte in value.encode("utf-8"):
        if byte in safe:
            out.append(chr(byte))
        else:
            out.append("%%%02X" % byte)
    return "".join(out)

def write_all(file_obj, data):
    file_obj.write(data)

try:
    with source.open("rb") as src:
        payload_tmp = tempfile.TemporaryFile(mode="w+b")
        while True:
            block = src.read(1024 * 1024)
            if not block:
                break
            payload_tmp.write(block)
            digest.update(block)
            size += len(block)

    source_format = source.suffix.lower().lstrip(".") or "unknown"
    package_kind = "portable" if portable else "standard"

    manifest_values = [
        ("package_name", safe_name),
        ("version", "1.0.0"),
        ("description", "Imported file wrapped by Bacus-Pkg"),
        ("target_os", "unknown"),
        ("target_arch", "unknown"),
        ("payload_format", "raw-v1"),
        ("entrypoint", ""),
        ("file_count", "1"),
        ("package_kind", package_kind),
        ("source_format", source_format),
    ]

    manifest = "".join(
        key + "=" + encode_value(value) + "\n"
        for key, value in manifest_values
    ).encode("utf-8")

    # The original file is stored as one opaque payload entry.
    internal_path = ("data/" + source.name).replace("\\", "/")
    if "\x00" in internal_path or internal_path.startswith("/"):
        sys.exit("ERROR: Nombre de archivo no válido.")

    path_bytes = internal_path.encode("utf-8")
    if len(path_bytes) > 4096 or any(part in ("", ".", "..") for part in internal_path.split("/")):
        sys.exit("ERROR: Ruta interna no válida.")

    table = ENTRY.pack(
        len(path_bytes),
        1,                 # regular file
        b"\x00\x00\x00",
        0,                 # payload offset
        size,              # stored size
        size,              # original size
        digest.digest(),
    ) + path_bytes

    fd, output_name = tempfile.mkstemp(
        prefix=".bacusp-",
        suffix=".tmp",
        dir=str(destination.parent),
    )
    output_tmp = Path(output_name)

    with os.fdopen(fd, "wb") as out:
        out.write(HEADER.pack(
            MAGIC,
            HEADER.size,
            VERSION,
            0,
            len(manifest),
            len(table),
            size,
        ))
        write_all(out, manifest)
        write_all(out, table)

        payload_tmp.seek(0)
        while True:
            block = payload_tmp.read(1024 * 1024)
            if not block:
                break
            out.write(block)

        out.flush()
        os.fsync(out.fileno())

    # Atomic no-overwrite publication.
    os.link(output_tmp, destination)
    output_tmp.unlink()
    output_tmp = None

    print("Bacus-Pkg: conversión completada.")
    print("Package:", destination)
    print("Kind:", package_kind)
    print("Source format:", source_format)
    print("Original bytes:", size)
    print("SHA-256:", digest.hexdigest())
    print("Nota: el archivo original se conserva dentro del paquete; no se convierte en una aplicación nativa.")

except FileExistsError:
    sys.exit("ERROR: El destino ya existe; no se sobrescribió.")
except OSError as exc:
    sys.exit("ERROR: No se pudo crear el paquete: " + str(exc))
finally:
    if payload_tmp is not None:
        payload_tmp.close()
    if output_tmp is not None:
        try:
            output_tmp.unlink()
        except OSError:
            pass
PY
