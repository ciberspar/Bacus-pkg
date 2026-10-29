
#!/bin/sh
#
# BACUSP - Update compatibility entry point
# Project: Bacus-Pkg
# Languages: Spanish / English
#

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
UPGRADE="$SCRIPT_DIR/upgrade.sh"

if [ ! -f "$UPGRADE" ]; then
    printf '%s\n' \
        "Error: falta modules/upgrade.sh" \
        "Error: modules/upgrade.sh is missing" >&2
    exit 1
fi

exec sh "$UPGRADE" "$@"
