Bacus Package Format (BP)

Specification: BP v1.0
Status: Initial specification
File extension: .bp
Format type: Custom binary container
Maintainer: Bacus-Pkg Project

1. Purpose

Bacus Package (BP) is a custom binary package format designed for the Bacus-Pkg package manager.

A BP file is a single binary file containing package metadata, compatibility information, a binary file table, and application data.

BP is designed to support packages for multiple operating systems and CPU architectures. Actual compatibility depends on the contents of each package and the capabilities of the destination system.

The .bp extension does not imply that a package is executable, trusted, or compatible with every operating system.

2. Design principles

* BP has its own binary signature and version.
* BP is not a renamed TAR, ZIP, DEB, RPM, EXE, or MSI file.
* All integer fields have explicitly defined widths and byte order.
* Package sizes are dynamic and depend on actual contents.
* No universal maximum package size is defined by the format.
* All package contents must be validated before installation.
* Package metadata uses stable, language-independent field names.
* Packages must declare their target operating systems and architectures.
* Unsupported encodings and versions must be rejected safely.
* Inspecting or converting a package must not execute its contents.
* Conversion does not guarantee native compatibility.

3. Binary layout

All integer fields are unsigned and use little-endian byte order.

A BP v1.0 file contains the following sections in exactly this order:

1. Fixed header.
2. Manifest.
3. File table.
4. Payload.

No additional bytes are permitted before the header or after the declared payload.

3.1 Fixed header

The fixed header is exactly 44 bytes.

Field	Size	Description
Magic	8 bytes	ASCII bytes BACUSBP1
Header size	4 bytes	Must equal 44
Format version	4 bytes	BP v1.0 is 0x00010000
Flags	4 bytes	Must be zero in v1
Manifest size	8 bytes	Number of manifest bytes
File table size	8 bytes	Number of file table bytes
Payload size	8 bytes	Number of payload bytes

The header size does not include the manifest, file table, or payload.

The manifest begins immediately after byte 44. The file table begins immediately after the manifest. The payload begins immediately after the file table.

All section boundaries must be calculated from the header and validated before reading section data.

A reader must reject invalid magic, unsupported versions, invalid header size, nonzero reserved flags, truncated files, arithmetic overflow, or sections that extend beyond the actual file length.

4. Version encoding

The 32-bit version field is encoded as follows:

* Upper 16 bits: major version.
* Lower 16 bits: minor version.

BP v1.0 uses the value 0x00010000.

Readers must reject unsupported major versions. Readers must not assume that a newer minor version is compatible unless its rules are explicitly supported.

Changes to the binary layout that cannot be interpreted by existing BP v1 readers require a new major version.

5. Manifest

The manifest is UTF-8 text stored directly in the binary file.

It follows these rules:

* One key=value field per line.
* Lines end with LF (0x0A).
* Keys are case-sensitive ASCII identifiers.
* Duplicate keys are forbidden.
* The manifest must end with LF.
* NUL bytes and invalid UTF-8 are forbidden.
* Values must not contain literal newlines or control characters.
* Values must use percent encoding when they need to represent reserved characters.
* Percent encoding uses %HH, where HH is two hexadecimal digits.
* Keys must not be percent encoded.
* Unknown fields may be ignored unless a future specification marks them as required.

5.1 Required fields

The following fields are mandatory:

* package_name
* version
* description
* target_os
* target_arch
* payload_format
* entrypoint
* file_count

5.2 Field definitions

package_name is a nonempty package identifier containing only ASCII letters, digits, periods, underscores, plus signs, and hyphens.

version is the package’s own version string. It is independent of the BP format version.

description is a short, human-readable package description.

target_os identifies the intended operating system.

target_arch identifies the intended CPU architecture.

payload_format must equal raw-v1 in BP v1.0.

entrypoint identifies the relative path of the intended program entry point. It may be empty for data-only packages. A nonempty entry point must refer to a regular file present in the file table.

file_count is the decimal number of file table entries, including directory entries.

Decimal integers must use ASCII digits only, with no sign or whitespace. Leading zeros are forbidden except for the value 0.

5.3 Example manifest

The following is an example of manifest content, not a complete BP file:

package_name=example-app
version=1.0.0
description=Example%20application
target_os=linux
target_arch=x86_64
payload_format=raw-v1
entrypoint=bin%2Fexample
file_count=2

The actual manifest is encoded as UTF-8 bytes without indentation.

6. File table

The file table consists of exactly file_count entries.

Each entry describes one directory or regular file. The file table must contain no trailing bytes.

Entries must be sorted by their raw UTF-8 path bytes in ascending bytewise order. Duplicate paths are forbidden.

6.1 Binary entry layout

Each entry has a fixed portion of 64 bytes followed by the path bytes.

Field	Size	Description
Path length	4 bytes	Length of the UTF-8 path in bytes
File type	1 byte	0 = regular file, 1 = directory
Reserved	3 bytes	Must all be zero
Payload offset	8 bytes	Offset from the beginning of the payload
Stored size	8 bytes	Number of payload bytes
Original size	8 bytes	Original uncompressed file size
SHA-256	32 bytes	Content checksum
Path	Variable	UTF-8 relative path, without a terminating NUL

The fixed portion is exactly 64 bytes. The path follows immediately and occupies exactly Path length bytes.

All integer fields use unsigned little-endian encoding.

6.2 Path rules

Paths must:

* Be valid UTF-8.
* Be nonempty and relative.
* Use / as the separator.
* Not begin or end with /.
* Not contain empty path components.
* Not contain . or .. components.
* Not contain NUL bytes.
* Not contain backslashes.
* Not contain absolute drive paths or platform-specific root prefixes.
* Not collide with another entry after path normalization on the destination platform.

Directory entries must appear before any child entries in bytewise sort order only when their paths naturally sort that way; readers must not rely on entry order to create directories.

Symbolic links, hard links, device files, sockets, and other special file types are forbidden in BP v1.0.

6.3 Regular file entries

For regular files:

* File type must equal 0.
* Stored size must equal Original size.
* SHA-256 must equal the SHA-256 digest of the file’s payload bytes.
* The payload offset and stored size must remain entirely within the payload section.
* A zero-length file has zero sizes and the SHA-256 digest of an empty byte sequence.

The payload ranges for nonempty files must not overlap. In BP v1.0, payload file data is stored contiguously in file table order, without gaps or trailing unreferenced bytes.

Zero-length files do not consume payload bytes.

6.4 Directory entries

For directories:

* File type must equal 1.
* Payload offset must equal 0.
* Stored size must equal 0.
* Original size must equal 0.
* The SHA-256 field must contain 32 zero bytes.

6.5 Entry count and boundaries

The sum of all entry lengths, including each 64-byte fixed portion and its path bytes, must equal file_table_size exactly.

The number of parsed entries must equal the manifest’s file_count.

Readers must reject malformed entries, invalid paths, duplicate paths, unsupported file types, nonzero reserved bytes, invalid offsets, overlapping payload ranges, and entries exceeding section boundaries.

7. Payload

The payload contains the actual file data.

BP v1.0 uses raw, uncompressed file data. No compression or encryption is defined.

Each regular file’s payload offset is relative to the first byte of the payload section.

File bytes appear in file table order, with no padding between files and no unreferenced payload bytes.

The sum of all regular file stored sizes must equal payload_size.

A package containing only directories or empty files may have a payload size of zero.

Readers must reject payload data that is missing, truncated, overlapping, or inconsistent with the file table.

8. Checksums and authenticity

Each regular file has a SHA-256 checksum stored in its file table entry.

Readers must calculate the checksum of the actual payload bytes and compare it with the stored value before installation.

Directory entries use 32 zero bytes instead of a checksum.

SHA-256 checks detect accidental corruption and mismatched content. They do not prove package authenticity or identify its publisher.

BP v1.0 does not define a digital-signature mechanism.

A future version may define package signatures, trusted publishers, key rotation, and revocation. Implementations must not claim that a package is trusted merely because its checksums match.

9. Compatibility

The manifest declares the target operating system and CPU architecture.

9.1 Operating system identifiers

Examples include:

* linux
* windows
* macos
* freebsd
* kolibrios
* any

9.2 Architecture identifiers

Examples include:

* x86
* x86_64
* arm
* aarch64
* riscv64
* any

Identifiers are case-sensitive and must be written exactly as defined by the package ecosystem.

The value any must only be used when the package’s contents genuinely support any relevant target. It must not be used merely because compatibility is unknown.

The manifest describes intended compatibility. It does not prove that the application works on the target.

Converting a DEB, RPM, MSI, EXE, APK, AppImage, or other package into BP does not automatically translate its executable code, dependencies, installation scripts, drivers, or operating-system interfaces.

10. Installation safety

A conforming installer must validate a package before publishing any installed files.

It must:

1. Validate the magic, header size, version, flags, and all section lengths.
2. Verify that declared sections fit within the actual file.
3. Detect arithmetic overflow before calculating offsets or sizes.
4. Parse the complete manifest and reject missing or duplicate required fields.
5. Validate all file table entries and paths.
6. Verify payload ranges and reject overlapping or unreferenced data.
7. Verify every regular file checksum.
8. Check target operating system and architecture.
9. Reject unsupported payload formats and installation methods.
10. Prevent writes outside the intended installation directory.
11. Avoid following symbolic links created by an untrusted package or another process.
12. Use a staging directory and publish files only after validation succeeds.
13. Avoid automatically executing package contents.
14. Report failures without leaving a partially installed package.

Package conversion, inspection, and verification must not execute imported installer files.

BP v1.0 defines a container, not a security sandbox. Actual isolation depends on the operating system and the mechanisms provided by the installer.

11. Dynamic package size

BP v1.0 does not define a universal maximum package size.

Package size is determined by the actual lengths of the header, manifest, file table, and payload.

The format uses unsigned 64-bit fields for section lengths and payload offsets. The writer must calculate lengths and offsets from the actual encoded data and must not pad the file to reach a predetermined total size.

A format with 64-bit size fields can represent very large values, but not every implementation or device can process or store every representable package.

Implementations may enforce configurable operational limits based on available memory, storage, filesystem capabilities, and platform constraints. These limits do not change the format itself.

Before allocating memory, reading sections, or writing files, implementations must validate sizes, detect overflow, and check available resources where possible.

A reader must reject packages that it cannot safely validate or process.

12. Resource limits

Implementations must define configurable limits for:

* Maximum manifest size.
* Maximum file table size.
* Maximum number of entries.
* Maximum path length.
* Maximum individual file size.
* Maximum total payload size supported by the implementation.
* Maximum processing time where practical.

These are implementation safety controls, not universal format limits.

An implementation must reject a package exceeding its configured limits before performing the operation that would exceed them.

13. Internationalization

The binary structure, manifest keys, operating system identifiers, architecture identifiers, and error codes must use stable technical identifiers independent of the user interface language.

User-facing descriptions, help messages, and documentation may be provided in Spanish and English.

Recommended documentation files include:

* README.es.md
* README.en.md

Translations must preserve the meaning of technical fields and security warnings.

14. Conversion rules

A converter may import files from other formats, but it must distinguish between extracting files and achieving compatibility.

The converter must not execute the source package.

If the source format cannot be safely parsed or extracted, the converter must fail with a clear error rather than silently presenting an opaque installer as a working native BP package.

A source installer may only be embedded as an opaque file in a future, explicitly defined package type. Such a package must not claim that its contents have been converted into native application files.

The converter must generate the manifest, file table, payload, and checksums consistently with this specification.

15. Reference implementation

A conforming implementation must provide:

* A binary BP writer.
* A binary BP reader.
* A structural verifier.
* A SHA-256 verifier.
* A safe package installer.
* A converter that produces valid BP files.
* Tests for valid packages, truncated files, corrupt checksums, invalid paths, duplicate entries, oversized lengths, integer overflow, unsupported versions, and malformed manifests.

The writer and reader must agree exactly on field sizes, byte order, path encoding, file order, section boundaries, and version handling.

16. Testing requirements

The reference implementation must test at least:

1. A package containing one regular file.
2. A package containing nested directories.
3. A zero-length file.
4. A package containing only directories.
5. A package with a long valid path.
6. A truncated header.
7. An invalid magic signature.
8. An unsupported version.
9. An invalid manifest.
10. A duplicate path.
11. A path containing parent-directory traversal.
12. An invalid payload offset.
13. An overlapping payload range.
14. A mismatched checksum.
15. A payload whose declared size differs from the actual file.
16. A package exceeding configured operational limits.
17. A package that is compatible with a different OS or architecture.
18. A package with trailing unreferenced bytes.

Invalid packages must be rejected without executing their contents or writing outside the staging directory.

17. Versioning policy

BP v1.0 is the initial binary format specification.

Changes that alter the binary layout or the meaning of existing fields require a new major format version unless explicitly permitted by this specification.

Writers must produce files conforming to the version they declare.

Readers must reject unsupported versions rather than guessing how to parse them.

18. License and status

This document defines the initial proposed BP v1.0 format for the Bacus-Pkg project.

The format is experimental until the reference implementation passes the required tests.

The existence of this specification does not imply that all operating systems, applications, architectures, or installer formats are supported.

19. Implementation status

The specification and its implementation are separate.

A feature must not be advertised as implemented until the corresponding code and tests exist.

The first implementation milestone is to generate and verify valid BP v1.0 files with the exact binary layout defined above.