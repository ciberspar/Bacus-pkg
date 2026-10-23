
#!/bin/sh
# Bacus-Pkg: formato BP inicial
set -eu

bp_create() {
    source_dir=$1
    output=$2
    name=$3
    version=$4

    [ -d "$source_dir" ] || {
        echo "Error: no existe el directorio de origen." >&2
        return 1
    }

    command -v tar >/dev/null 2>&1 || {
        echo "Error: se necesita tar." >&2
        return 1
    }

    command -v gzip >/dev/null 2>&1 || {
        echo "Error: se necesita gzip." >&2
        return 1
    }

    case "$name:$version" in
        *[!a-zA-Z0-9_.+-:]*|"")
            echo "Error: nombre o versión no válidos." >&2
            return 1
            ;;
    esac

    [ ! -e "$output" ] || {
        echo "Error: el archivo de salida ya existe." >&2
        return 1
    }

    parent=$(dirname "$output")
    mkdir -p "$parent"

    tmp=$(mktemp -d "${TMPDIR:-/tmp}/bacus-bp.XXXXXX")
    trap 'rm -rf "$tmp"' EXIT HUP INT TERM

    mkdir -p "$tmp/payload"
    cp -R "$source_dir"/. "$tmp/payload/"

    {
        printf 'format=bp-1\n'
        printf 'name=%s\n' "$name"
        printf 'version=%s\n' "$version"
        printf 'payload=payload\n'
        printf 'runtime=unknown\n'
    } > "$tmp/manifest.txt"

    tar -czf "$output" -C "$tmp" manifest.txt payload
    echo "BP creado: $output"
}
