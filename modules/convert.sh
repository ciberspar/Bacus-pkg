#!/bin/sh

Bacus-Pkg BP v1.0 Binary Converter

set -eu
umask 077
LC_ALL=C
export LC_ALL

err() {
printf ‘ERROR: %s\n’ “$*” >&2
exit 2
}

ORIG=${1:-}
DEST=${2:-}

[ -n “$ORIG” ] || err “Usage: bacusp convert SOURCE DESTINATION.bp”
[ -e “$ORIG” ] || err “Source does not exist: $ORIG”

case “$ORIG” in
/*) ;;
*) ORIG=”$(pwd)/$ORIG” ;;
esac

if [ -z “$DEST” ]; then
BASE=$(basename “$ORIG”)
DEST=”${BASE%.*}.bp”
fi

case “$DEST” in
*.bp) ;;
*) err “Destination must end in .bp” ;;
esac

[ ! -e “$DEST” ] || err “Destination already exists”

PARENT=$(dirname “$DEST”)
[ -d “$PARENT” ] || err “Destination directory does not exist”

for tool in python3 find cp; do
command -v “$tool” >/dev/null 2>&1 ||
err “Required tool missing: $tool”
done

WORK=$(mktemp -d “${TMPDIR:-/tmp}/bp-v1.XXXXXX”) ||
err “Cannot create temporary directory”

OUT=
cleanup() {
rm -rf “$WORK”
[ -z “$OUT” ] || rm -f “$OUT”
}
trap cleanup 0
trap ‘exit 2’ HUP INT TERM

mkdir “$WORK/payload”

SOURCE=$(basename “$ORIG”)
FORMAT=directory

if [ -d “$ORIG” ]; then
cp -R “$ORIG”/. “$WORK/payload”/ ||
err “Cannot copy source directory”
else
case “$SOURCE” in
.deb)
command -v dpkg-deb >/dev/null 2>&1 ||
err “Install dpkg-deb to import DEB files”
dpkg-deb –extract “$ORIG” “$WORK/payload” ||
err “Cannot safely import DEB”
FORMAT=deb-extracted
;;
.zip)
err “ZIP import is disabled until safe extraction is implemented”
;;
.tar|.tar.gz|.tgz|.tar.xz|*.txz)
err “TAR import is disabled until safe extraction is implemented”
;;
*)
err “Unsupported source. Supply a directory or supported DEB file.”
;;
esac
fi

python3 - “$WORK/payload” “$DEST” “$SOURCE” “$FORMAT” <<‘PY’
import hashlib
import os
import pathlib
import struct
import sys
import tempfile

root = pathlib.Path(sys.argv[1])
dest = pathlib.Path(sys.argv[2])
source = sys.argv[3]
source_format = sys.argv[4]

def fail(message):
raise SystemExit(“ERROR: “ + message)

def checked_path(path):
rel = path.relative_to(root).as_posix()
raw = rel.encode(“utf-8”, “strict”)
if not raw or “\x00” in rel or “\” in rel:
fail(“Invalid package path”)
parts = rel.split(”/”)
if any(p in (””, “.”, “..”) for p in parts):
fail(“Unsafe package path: “ + rel)
return rel, raw

entries = []
for current, dirs, files in os.walk(root, followlinks=False):
for name in list(dirs) + list(files):
path = pathlib.Path(current) / name
if path.is_symlink():
fail(“Symbolic links are not supported: “ + str(path))
if not path.is_dir() and not path.is_file():
fail(“Special files are not supported: “ + str(path))
rel, raw = checked_path(path)
entries.append((raw, rel, path, path.is_dir()))

entries.sort(key=lambda e: e[0])
if len({e[0] for e in entries}) != len(entries):
fail(“Duplicate paths”)

name = pathlib.Path(source).name
if “.” in name:
name = name.rsplit(”.”, 1)[0]
safe_name = “”.join(
c for c in name if c.isascii() and
(c.isalnum() or c in “._+-”)
) or “imported-package”

payload_parts = []
table_parts = []
offset = 0

for raw, rel, path, is_dir in entries:
if is_dir:
kind = 1
data = b””
digest = bytes(32)
else:
kind = 0
try:
data = path.read_bytes()
except OSError as exc:
fail(“Cannot read file: “ + rel + “: “ + str(exc))
digest = hashlib.sha256(data).digest()

stored = len(data)
original = stored
file_offset = 0 if is_dir else offset
table_parts.append(
    struct.pack(
        "<IB3sQQQ32s",
        len(raw), kind, bytes(3),
        file_offset, stored, original, digest
    ) + raw
)
if not is_dir and data:
    payload_parts.append(data)
    offset += stored

payload = b””.join(payload_parts)
table = b””.join(table_parts)

manifest_values = [
(“package_name”, safe_name),
(“version”, “0.1.0”),
(“description”, “Imported package”),
(“target_os”, “any”),
(“target_arch”, “any”),
(“payload_format”, “raw-v1”),
(“entrypoint”, “”),
(“file_count”, str(len(entries))),
(“source_format”, source_format),
]

def encode_value(value):
safe = b”ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789._+-/”
out = []
for b in value.encode(“utf-8”):
if b in safe and b not in (ord(”%”), ord(”=”)):
out.append(chr(b))
else:
out.append(”%%%02X” % b)
return “”.join(out)

manifest = “”.join(
key + “=” + encode_value(value) + “\n”
for key, value in manifest_values
).encode(“utf-8”)

header = struct.pack(
“<8sIIIQQQ”,
b”BACUSBP1”,
44,
0x00010000,
0,
len(manifest),
len(table),
len(payload),
)

if len(header) != 44:
fail(“Internal header size error”)

if dest.exists():
fail(“Destination already exists”)

dest_parent = dest.parent.resolve()
fd, temporary = tempfile.mkstemp(
prefix=”.bp-output-”, suffix=”.tmp”, dir=str(dest_parent)
)

try:
with os.fdopen(fd, “wb”) as out:
out.write(header)
out.write(manifest)
out.write(table)
out.write(payload)
out.flush()
os.fsync(out.fileno())

# Validate the finished file's exact length before publishing it.
expected = 44 + len(manifest) + len(table) + len(payload)
if os.path.getsize(temporary) != expected:
    fail("Output size verification failed")
# Never overwrite an existing destination.
try:
    os.link(temporary, dest)
except FileExistsError:
    fail("Destination already exists")
except OSError as exc:
    fail("Cannot publish output safely: " + str(exc))

finally:
try:
os.unlink(temporary)
except FileNotFoundError:
pass

print(“Created:”, dest)
print(“Format: BP v1.0 binary”)
print(“Source format:”, source_format)
print(“Files:”, len(entries))
print(“Payload bytes:”, len(payload))
print(“Total bytes:”, os.path.getsize(dest))
PY