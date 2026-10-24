
#!/bin/sh
# BACUSP Install - BP v1
# Called by bin/bacusp
set -eu
umask 077

error() { printf 'ERROR: %s\n' "$*" >&2; }
PACKAGE=${1:-}

[ -n "$PACKAGE" ] || {
    error "Usage: bacusp install PACKAGE.bp"
    exit 2
}
[ -f "$PACKAGE" ] && [ -r "$PACKAGE" ] || {
    error "Package not found or unreadable: $PACKAGE"
    exit 2
}
case "$PACKAGE" in
    *.bp) ;;
    *) error "Install accepts .bp packages only"; exit 2 ;;
esac

command -v tar >/dev/null 2>&1 || {
    error "tar is required"; exit 2
}
command -v gzip >/dev/null 2>&1 || {
    error "gzip is required"; exit 2
}

HOME_DIR=${HOME:-}
[ -n "$HOME_DIR" ] || {
    error "HOME is not set"; exit 2
}
BACUSP_HOME=${BACUSP_HOME:-"$HOME_DIR/.bacusp"}
APPS="$BACUSP_HOME/apps"
DB="$BACUSP_HOME/installed.db"

WORK=$(mktemp -d "${TMPDIR:-/tmp}/bacusp-install.XXXXXX") || exit 2
cleanup() { rm -rf "$WORK"; }
trap cleanup 0
trap 'exit 2' HUP INT TERM

# Reject unsafe archive paths before extraction.
if ! gzip -t "$PACKAGE"; then
    error "Invalid gzip archive"
    exit 2
fi
if ! tar -tzf "$PACKAGE" > "$WORK/list"; then
    error "Invalid BP archive"
    exit 2
fi

while IFS= read -r entry; do
    case "$entry" in
        /*|..|../*|*/../*|*/..)
            error "Unsafe archive path: $entry"
            exit 2
            ;;
    esac
done < "$WORK/list"

tar -xzf "$PACKAGE" -C "$WORK" || {
    error "Could not extract package"
    exit 2
}
MANIFEST="$WORK/manifest.tsv"
PAYLOAD="$WORK/payload"

[ -f "$MANIFEST" ] && [ -d "$PAYLOAD" ] || {
    error "Missing manifest.tsv or payload/"
    exit 2
}

get_field() {
    awk -F '\t' -v key="$1" '
        $1 == key { print substr($0, length($1) + 2); exit }
    ' "$MANIFEST"
}

[ "$(get_field format)" = bp ] &&
[ "$(get_field format_version)" = 1 ] || {
    error "Unsupported BP format/version"
    exit 2
}

NAME=$(get_field package_name)
VERSION=$(get_field version)
STATUS=$(get_field compatibility_status)
TARGET=$(get_field target_family)

case "$NAME" in
    ''|*[!A-Za-z0-9._+-]*)
        error "Invalid package name"; exit 2 ;;
esac
case "$VERSION" in
    ''|*[!A-Za-z0-9._+-]*)
        error "Invalid package version"; exit 2 ;;
esac

[ "$STATUS" = extracted-unverified ] || {
    error "This BP only contains an original installer/source; it is not installable yet."
    exit 3
}

# Do not allow symlinks or special files in this initial installer.
if find "$PAYLOAD" ! -type d ! -type f -print |
    grep . >/dev/null 2>&1; then
    error "Payload contains symlinks or special files; refusing installation."
    exit 2
fi

PLATFORM=$(uname -s 2>/dev/null || printf unknown)
case "$TARGET:$PLATFORM" in
    linux:Linux|unknown:Linux|unknown:Darwin|unknown:FreeBSD)
        ;;
    linux:*|windows:*|android-or-alpine:*)
        error "Target '$TARGET' is not confirmed compatible with '$PLATFORM'."
        exit 3
        ;;
esac

DEST="$APPS/$NAME/$VERSION"
[ ! -e "$DEST" ] || {
    error "This package version is already installed: $DEST"
    exit 2
}

mkdir -p "$APPS/$NAME" "$BACUSP_HOME/sandboxes/$NAME"/documents \
    "$BACUSP_HOME/sandboxes/$NAME"/downloads \
    "$BACUSP_HOME/sandboxes/$NAME"/config

STAGE="$APPS/$NAME/.install-$$"
mkdir "$STAGE" || exit 2
if ! cp -R "$PAYLOAD"/. "$STAGE"/; then
    rm -rf "$STAGE"
    error "Could not copy payload"
    exit 2
fi

if ! mv "$STAGE" "$DEST"; then
    rm -rf "$STAGE"
    error "Could not finalize installation"
    exit 2
fi

mkdir -p "$BACUSP_HOME"
touch "$DB"
if ! printf '%s\t%s\t%s\t%s\n' \
    "$NAME" "$VERSION" "$TARGET" "$DEST" >> "$DB"; then
    rm -rf "$DEST"
    error "Could not register installation"
    exit 2
fi

printf 'Installed: %s %s\n' "$NAME" "$VERSION"
printf 'Files: %s\n' "$DEST"
printf 'Data: %s\n' "$BACUSP_HOME/sandboxes/$NAME"
printf '%s\n' "Note: files are installed in Bacus's user directory; native OS integration is not configured."
