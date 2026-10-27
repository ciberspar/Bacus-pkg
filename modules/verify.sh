#!/bin/sh

Bacus-Pkg BP v1.0 Binary Verifier

set -eu
umask 077

err() {
printf ‘ERROR: %s\n’ “$*” >&2
exit 2
}

PACKAGE=${1:-}
[ -n “$PACKAGE” ] || err “Usage: bacusp verify PACKAGE.bp”
[ -f “$PACKAGE” ] || err “Package not found: $PACKAGE”

case “$PACKAGE” in
/*) ;;
*) PACKAGE=”$(pwd)/$PACKAGE” ;;
esac

command -v python3 >/dev/null 2>&1 ||
err “Python 3 is required to verify BP v1.0”

python3 - “$PACKAGE” <<‘PY’
import hashlib
import os
import re
import struct
import sys

path = sys.argv[1]

def fail(message):
print(“ERROR:”, message, file=sys.stderr)
raise SystemExit(2)

def read_exact(stream, size, label):
data = stream.read(size)
if len(data) != size:
fail(“Truncated “ + label)
return data

def decode_value(value):
# Decode the percent encoding defined by BP_FORMAT.md.
out = bytearray()
i = 0
while i < len(value):
if value[i] == “%”:
if i + 2 >= len(value):
fail(“Invalid percent encoding in manifest”)
pair = value[i + 1:i + 3]
if not re.fullmatch(r”[0-9A-Fa-f]{2}”, pair):
fail(“Invalid percent encoding in manifest”)
out.append(int(pair, 16))
i += 3
else:
try:
out.extend(value[i].encode(“ascii”))
except UnicodeEncodeError:
fail(“Non-ASCII manifest encoding”)
i += 1
try:
return out.decode(“utf-8”, “strict”)
except UnicodeDecodeError:
fail(“Invalid UTF-8 in manifest value”)

def parse_manifest(data):
if not data or not data.endswith(b”\n”):
fail(“Manifest must end with LF”)
if b”\x00” in data or b”\r” in data:
fail(“Invalid control character in manifest”)
try:
text = data.decode(“utf-8”, “strict”)
except UnicodeDecodeError:
fail(“Manifest is not valid UTF-8”)

fields = {}
for line in text[:-1].split("\n"):
    if "=" not in line:
        fail("Invalid manifest line")
    key, value = line.split("=", 1)
    if not re.fullmatch(r"[A-Za-z][A-Za-z0-9_]*", key):
        fail("Invalid manifest key")
    if key in fields:
        fail("Duplicate manifest key: " + key)
    fields[key] = decode_value(value)
required = (
    "package_name", "version", "description",
    "target_os", "target_arch", "payload_format",
    "entrypoint", "file_count"
)
for key in required:
    if key not in fields:
        fail("Missing manifest field: " + key)
if not re.fullmatch(
    r"[A-Za-z0-9._+-]+", fields["package_name"]
):
    fail("Invalid package name")
if not fields["version"]:
    fail("Empty package version")
if fields["payload_format"] != "raw-v1":
    fail("Unsupported payload format")
if not re.fullmatch(r"(0|[1-9][0-9]*)", fields["file_count"]):
    fail("Invalid file_count")
return fields

try:
actual_size = os.path.getsize(path)
with open(path, “rb”) as stream:
header = read_exact(stream, 44, “header”)

    magic, header_size, version, flags, manifest_size, table_size, payload_size = (
        struct.unpack("<8sIIIQQQ", header)
    )
    if magic != b"BACUSBP1":
        fail("Invalid BP magic signature")
    if header_size != 44:
        fail("Invalid header size")
    if version != 0x00010000:
        fail("Unsupported BP version")
    if flags != 0:
        fail("Unsupported BP flags")
    total = 44 + manifest_size + table_size + payload_size
    if total != actual_size:
        fail("Declared sections do not match actual file size")
    # Check section sizes against the file before reading.
    manifest_bytes = read_exact(
        stream, manifest_size, "manifest"
    )
    manifest = parse_manifest(manifest_bytes)
    table_start = stream.tell()
    table_end = table_start + table_size
    payload_start = table_end
    if table_end > actual_size or payload_start > actual_size:
        fail("Invalid section boundaries")
    count = int(manifest["file_count"])
    if count > table_size // 65:
        # Every entry needs 64 fixed bytes and at least one path byte.
        fail("File count exceeds possible table entries")
    entries = []
    previous_path = None
    expected_payload_offset = 0
    for _ in range(count):
        fixed = read_exact(stream, 64, "file table entry")
        path_len, kind, reserved, offset, stored, original, digest = (
            struct.unpack("<IB3sQQQ32s", fixed)
        )
        if path_len == 0:
            fail("Empty file path")
        if reserved != b"\x00\x00\x00":
            fail("Nonzero reserved bytes")
        if kind not in (0, 1):
            fail("Unsupported file type")
        # Ensure the path fits within the declared table.
        if stream.tell() + path_len > table_end:
            fail("Path exceeds file table")
        raw_path = read_exact(stream, path_len, "file path")
        try:
            rel = raw_path.decode("utf-8", "strict")
        except UnicodeDecodeError:
            fail("Invalid UTF-8 file path")
        if "\x00" in rel or "\\" in rel:
            fail("Invalid character in file path")
        if rel.startswith("/") or rel.endswith("/"):
            fail("Absolute or malformed path")
        if re.match(r"^[A-Za-z]:", rel):
            fail("Drive path is forbidden")
        parts = rel.split("/")
        if any(part in ("", ".", "..") for part in parts):
            fail("Unsafe path: " + rel)
        if previous_path is not None and raw_path <= previous_path:
            fail("File paths are duplicated or not sorted")
        previous_path = raw_path
        if kind == 1:
            if offset != 0 or stored != 0 or original != 0:
                fail("Invalid directory entry")
            if digest != bytes(32):
                fail("Invalid directory checksum field")
        else:
            if stored != original:
                fail("Stored and original sizes differ")
            if offset != expected_payload_offset:
                fail("Payload entries are not contiguous")
            if stored > payload_size - expected_payload_offset:
                fail("File exceeds payload boundaries")
            expected_payload_offset += stored
        entries.append((rel, kind, offset, stored, digest))
    if stream.tell() != table_end:
        fail("File table size does not match its entries")
    if expected_payload_offset != payload_size:
        fail("Payload size does not match file entries")
    # Verify file contents incrementally without extracting anything.
    for rel, kind, offset, stored, digest in entries:
        if kind == 1:
            continue
        stream.seek(payload_start + offset)
        hasher = hashlib.sha256()
        remaining = stored
        while remaining:
            chunk = stream.read(min(1024 * 1024, remaining))
            if not chunk:
                fail("Truncated payload: " + rel)
            hasher.update(chunk)
            remaining -= len(chunk)
        if hasher.digest() != digest:
            fail("SHA-256 mismatch: " + rel)
    print("OK: Valid BP v1.0 binary structure")
    print("Package:", manifest["package_name"])
    print("Version:", manifest["version"])
    print("Files:", count)
    print("Payload bytes:", payload_size)
    print("Total bytes:", actual_size)
    print("SHA-256: all regular files verified")
    print("Note: integrity does not prove publisher authenticity")

except (OSError, struct.error, OverflowError) as exc:
fail(“Cannot safely read package: “ + str(exc))
PY