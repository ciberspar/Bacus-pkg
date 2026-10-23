
#!/bin/sh
set -eu

bp_verify() {
    package=$1

    [ -f "$package" ] || {
        echo "Error: paquete inexistente." >&2
        return 1
    }

    command -v tar >/dev/null 2>&1 || return 1
    command -v gzip >/dev/null 2>&1 || return 1

    tmp=$(mktemp -d "${TMPDIR:-/tmp}/bp-check.XXXXXX")
    trap 'rm -rf "$tmp"' EXIT HUP INT TERM

    gzip -t "$package" || {
        echo "Error: archivo comprimido inválido." >&2
        return 1
    }

    tar -tzf "$package" > "$tmp/list.txt" || return 1

    if grep -E '(^/|(^|/)\.\.(/|$))' "$tmp/list.txt"; then
        echo "Error: rutas peligrosas en el paquete." >&2
        return 1
    fi

    grep -Fx 'manifest.txt' "$tmp/list.txt" >/dev/null || {
        echo "Error: falta manifest.txt." >&2
        return 1
    }

    tar -xOzf "$package" manifest.txt > "$tmp/manifest.txt" || return 1

    grep -Fx 'format=bp-1' "$tmp/manifest.txt" >/dev/null || {
        echo "Error: versión de formato no compatible." >&2
        return 1
    }

    grep -E '^name=[a-zA-Z0-9_.+-]+$' "$tmp/manifest.txt" >/dev/null || return 1
    grep -E '^version=[a-zA-Z0-9_.+-]+$' "$tmp/manifest.txt" >/dev/null || return 1

    echo "Estructura BP básica válida."
}
