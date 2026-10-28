
#!/bin/sh
# BACUSP - BP v1 Converter
# Uso:
#   bacusp convert ORIGEN
#   bacusp convert ORIGEN DESTINO.bp
#   bacusp convert --portable ORIGEN [DESTINO.bp]

set -eu
umask 077

err() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 2
}

PORTABLE=0

case "${1:-}" in
    --portable|-portable)
        PORTABLE=1
        shift
        ;;
esac

SOURCE=${1:-}
[ -n "$SOURCE" ] || err "Uso: bacusp convert [--portable] ORIGEN [DESTINO.bp]"
shift || true

DESTINATION=${1:-}
shift || true
[ "$#" -eq 0 ] || err "Demasiados argumentos."

[ -f "$SOURCE" ] || err "El origen no existe o no es un archivo regular."
[ ! -L "$SOURCE" ] || err "No se admiten enlaces simbólicos."

command -v python3 >/dev/null 2>&1 ||
    err "Se necesita Python 3."

exec python3 - "$SOURCE" "$DESTINATION" "$PORTABLE" <<'PY'
import os
import sys
import re
import hashlib
import struct
import tempfile
from pathlib import Path

source_arg, destination_arg, portable_arg = sys.argv[1:]
source = Path(source_arg).absolute()

if portable_arg not in ("0", "1"):
    sys.exit("ERROR: opción portable inválida.")

if source.is_symlink() or not source.is_file():
    sys.exit("ERROR: el origen debe ser un archivo regular.")

portable = portable_arg == "1"
safe_name = re.sub(
    r"[^A-Za-z0-9._+-]", "-", source.stem or source.name
).strip(".-+")

if not safe_name:
    safe_name = "imported-artifact"

if destination_arg:
    destination = Path(destination_arg).absolute()
    if destination.suffix.lower() != ".bp":
        sys.exit("ERROR: el destino debe terminar en .bp.")
else:
    suffix = "-portable.bp" if portable else ".bp"
    destination = source.with_name(safe_name + suffix)

if destination == source:
    sys.exit("ERROR: origen y destino no pueden ser el mismo archivo.")

if destination.exists() or destination.is_symlink():
    sys.exit("ERROR: el destino ya existe; no se sobrescribirá.")

if not destination.parent.is_dir():
    sys.exit("ERROR: la carpeta de destino no existe.")

MAGIC = b"BACUSBP1"
VERSION = 0x00010000
HEADER = struct.Struct("<8sIIIQQQ")
ENTRY = struct.Struct("<IB3sQQQ32s")

def encode_value(value):
    allowed = b"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789._+-/"
    out = []
    for byte in value.encode("utf-8"):
        if byte in allowed:
            out.append(chr(byte))
        else:
            out.append("%%%02X" % byte)
    return "".join(out)

digest = hashlib.sha256()
size = 0
payload_tmp = None
output_tmp = None

try:
    payload_tmp = tempfile.TemporaryFile(mode="w+b")

    with source.open("rb") as src:
        while True:
            block = src.read(1024 * 1024)
            if not block:
                break
            payload_tmp.write(block)
            digest.update(block)
            size += len(block)

    source_format = source.suffix.lower().lstrip(".") or "unknown"

    manifest_values = [
        ("package_name", safe_name),
        ("version", "1.0.0"),
        ("description", "File wrapped by Bacus-Pkg"),
        ("target_os", "unknown"),
        ("target_arch", "unknown"),
        ("payload_format", "raw-v1"),
        ("entrypoint", ""),
        ("file_count", "1"),
        ("package_kind", "portable" if portable else "standard"),
        ("source_format", source_format),
    ]

    manifest = "".join(
        key + "=" + encode_value(value) + "\n"
        for key, value in manifest_values
    ).encode("utf-8")

    # El archivo se almacena como una entrada opaca.
    internal_path = "data/" + source.name
    path_bytes = internal_path.encode("utf-8")

    if (
        len(path_bytes) > 4096
        or any(p in ("", ".", "..") for p in internal_path.split("/"))
        or "\x00" in internal_path
        or "\\" in internal_path
    ):
        sys.exit("ERROR: ruta interna inválida.")

    # BP v1: 0 = archivo regular; 1 = directorio.
    table = ENTRY.pack(
        len(path_bytes),
        0,
        b"\x00\x00\x00",
        0,
        size,
        size,
        digest.digest(),
    ) + path_bytes

    fd, temp_name = tempfile.mkstemp(
        prefix=".bacusp-",
        suffix=".tmp",
        dir=str(destination.parent),
    )
    output_tmp = Path(temp_name)

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
        out.write(manifest)
        out.write(table)

        payload_tmp.seek(0)
        while True:
            block = payload_tmp.read(1024 * 1024)
            if not block:
                break
            out.write(block)

        out.flush()
        os.fsync(out.fileno())

    # Publicación sin sobrescribir un destino existente.
    os.link(output_tmp, destination)
    output_tmp.unlink()
    output_tmp = None

    print("Bacus-Pkg: conversión completada.")
    print("Paquete:", destination)
    print("Formato de origen:", source_format)
    print("Tipo:", "portable" if portable else "standard")
    print("Bytes:", size)
    print("SHA-256:", digest.hexdigest())
    print("Aviso: se empaquetó el archivo original; no se transformó su formato.")

except FileExistsError:
    sys.exit("ERROR: el destino ya existe.")
except OSError as exc:
    sys.exit("ERROR: no se pudo crear el paquete: " + str(exc))
finally:
    if payload_tmp is not None:
        payload_tmp.close()
    if output_tmp is not None:
        try:
            output_tmp.unlink()
        except OSError:
            pass
PY
