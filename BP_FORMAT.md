Bacus Package Format (BP)

Specification: BP v1.0
Status: Initial specification
File extension: .bp
Format type: Custom binary container
Maintainer: Bacus-Pkg Project

1. Purpose

Bacus Package (BP) is a custom binary package format designed for the Bacus-Pkg package manager.

A BP file contains package metadata, compatibility information, file records, and application data in a structured binary container.

The .bp extension does not imply that a package is executable or compatible with every operating system.

2. Design principles

* A BP file is a single binary file.
* The format has its own signature and version.
* Fields use explicitly defined byte order and sizes.
* Package contents must be validated before installation.
* Package metadata must support internationalization.
* Packages must declare their target operating systems and CPU architectures.
* Unsupported formats must be rejected safely.
* No package may execute code automatically during inspection or installation.

3. Binary layout

All integer fields use little-endian byte order.

The initial BP v1 format uses the following layout:

Field	Size	Description
Magic	8 bytes	BACUSBP1 in ASCII
Header size	4 bytes	Header length in bytes
Format version	4 bytes	Major/minor version encoding
Flags	4 bytes	Reserved; must be zero in v1
Manifest size	8 bytes	Length of manifest data
File table size	8 bytes	Length of file table
Payload size	8 bytes	Total length of payload data
Manifest	Variable	Package metadata
File table	Variable	File entries and offsets
Payload	Variable	File contents

The fixed header is 44 bytes.

All lengths and offsets must be checked for integer overflow, truncation, overlap, and out-of-bounds access before reading data.

Unknown flags must be rejected in BP v1.

4. Version encoding

The 32-bit format version is encoded as:

* Upper 16 bits: major version.
* Lower 16 bits: minor version.

For BP v1.0, the value is 0x00010000.

A reader must reject unsupported major versions. A reader may reject unsupported minor versions if it cannot safely interpret them.

5. Manifest

The manifest is UTF-8 text using the following rules:

* One key=value field per line.
* Keys are case-sensitive ASCII identifiers.
* Duplicate keys are forbidden.
* Line endings are LF.
* Values containing newlines or control characters must use a documented escaping scheme or be rejected.
* Unknown keys may be ignored unless marked as required by a future specification.

Required fields:

* package_name
* version
* description
* target_os
* target_arch
* payload_format
* entrypoint
* file_count

The manifest describes a package. It does not prove that the application is compatible, trustworthy, or safe.

6. File table

Each file entry records:

* Relative path.
* File type.
* Payload offset.
* Stored size.
* Original size.
* Content checksum.

BP v1 supports regular files and directories.

Symbolic links, device files, sockets, and other special file types are forbidden in BP v1.

Paths must be relative, normalized, and confined to the package installation directory. Absolute paths, parent-directory traversal, duplicate paths, and conflicting file/directory entries must be rejected.

7. Payload

The payload contains the actual file bytes.

BP v1 initially supports uncompressed payload data.

The payload must not contain unaccounted bytes or ranges outside its declared boundaries.

A future version may define compression, encryption, or additional storage methods. Readers must not guess unsupported encodings.

8. Checksums and authenticity

Every regular file must have a SHA-256 checksum recorded in the file table.

The verifier must calculate the checksum from the actual payload bytes and compare it with the recorded value.

Checksums detect accidental corruption and content mismatches. They do not prove who created a package.

Authenticity verification requires a future, explicitly specified digital-signature mechanism and a trusted key policy.

9. Compatibility

The manifest must declare the intended operating system and CPU architecture.

Examples of architecture identifiers:

* x86
* x86_64
* arm
* aarch64
* riscv64
* any

Examples of operating-system identifiers:

* linux
* windows
* macos
* freebsd
* kolibrios
* any

The identifier any must only be used when the relevant component is genuinely platform-independent.

A package manager must not assume that converting an existing installer into BP makes its application portable.

10. Installation safety

Before installing a BP package, Bacus-Pkg must:

1. Validate the fixed header and supported version.
2. Validate every declared length and offset.
3. Reject malformed, overlapping, or out-of-range sections.
4. Validate every file path.
5. Verify all file checksums.
6. Check the target operating system and architecture.
7. Refuse unsupported or unverified installation methods.
8. Prevent writes outside the intended installation directory.
9. Avoid automatic execution of package contents.
10. Report errors without partially installing an invalid package.

Installation must use a temporary staging directory and publish files only after validation succeeds.

11. Resource limits

Implementations must enforce configurable limits for:

* Total package size.
* Manifest size.
* File table size.
* Number of files.
* Individual file size.
* Total extracted or installed size.
* Path length.

Limits must be checked before allocating large amounts of memory or writing files.

12. Internationalization

The binary structure and manifest keys use stable, language-independent identifiers.

User-facing descriptions and documentation may be supplied in Spanish and English.

Recommended documentation files:

* README.es.md
* README.en.md

Translations must not change the meaning of technical fields.

13. Reference implementation

The specification does not itself implement the format.

A conforming implementation must provide:

* A BP binary writer.
* A BP binary reader.
* A structural verifier.
* A checksum verifier.
* Safe package extraction or installation.
* Tests for valid files, truncated files, corrupt checksums, invalid paths, oversized lengths, and unsupported versions.

14. Versioning policy

BP v1 is the initial format definition.

Changes that alter the binary layout or the interpretation of existing fields require a new major format version unless explicitly permitted by this specification.

15. License and status

This document defines the initial proposed BP v1 format for the Bacus-Pkg project.

The format should be considered experimental until the reference implementation and security tests are complete.