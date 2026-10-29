
#!/bin/sh
# BACUSP v7.5 - Installed BP Packages
# Project: Bacus-Pkg
# Author: ciberspar
# Languages: Spanish / English

set -eu

BACUSP_HOME=${BACUSP_HOME:-"${HOME:-/tmp}/.bacusp"}
APP_ROOT="$BACUSP_HOME/apps"
LANGUAGE=${BACUSP_LANG:-es}

case "$LANGUAGE" in
    en|EN) LANGUAGE=en ;;
    *) LANGUAGE=es ;;
esac

if [ "$LANGUAGE" = en ]; then
    TITLE="Installed BP packages"
    EMPTY="No BP packages are installed."
    NAME="Package"
    VERSION="Version"
    PATH_LABEL="Path"
else
    TITLE="Paquetes BP instalados"
    EMPTY="No hay paquetes BP instalados."
    NAME="Paquete"
    VERSION="Versión"
    PATH_LABEL="Ruta"
fi

printf '%s\n' "$TITLE"
printf '%s\n' '----------------------------------------'

if [ ! -d "$APP_ROOT" ]; then
    printf '%s\n' "$EMPTY"
    exit 0
fi

FOUND=0

for package_dir in "$APP_ROOT"/*; do
    [ -d "$package_dir" ] || continue
    package_name=${package_dir##*/}

    for version_dir in "$package_dir"/*; do
        [ -d "$version_dir" ] || continue
        version=${version_dir##*/}
        FOUND=1

        printf '%s: %s\n' "$NAME" "$package_name"
        printf '%s: %s\n' "$VERSION" "$version"
        printf '%s: %s\n\n' "$PATH_LABEL" "$version_dir"
    done
done

if [ "$FOUND" -eq 0 ]; then
    printf '%s\n' "$EMPTY"
fi

exit 0
