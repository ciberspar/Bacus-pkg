
#!/bin/sh
set -eu

bp_convert() {
    input=$1
    output=$2

    [ -f "$input" ] || {
        echo "Error: no se encuentra el archivo." >&2
        return 1
    }

    case "$input" in
        *.deb)
            echo "Paquete Debian detectado."
            echo "La extracción y conversión de metadatos Debian requiere"
            echo "un adaptador específico; no se instalará el paquete nativo."
            echo "Conversión cancelada para evitar una falsa compatibilidad." >&2
            return 2
            ;;
        *.bp)
            echo "El archivo ya tiene extensión BP; verificá su estructura."
            bp_verify "$input"
            ;;
        *)
            echo "Formato todavía no soportado: $input" >&2
            return 2
            ;;
    esac
}
