
#!/bin/sh
# BACUSP - Interactive Update Center
# Compatible con /bin/sh; sin dependencias de ncurses.

set -eu
umask 077

BACUSP_HOME=${BACUSP_HOME:-"${HOME:-/tmp}/.bacusp"}
LANGUAGE=${BACUSP_LANG:-es}

case "${1:-}" in
    --lang)
        [ "$#" -ge 2 ] || {
            echo "Uso: update.sh --lang es|en" >&2
            exit 2
        }
        LANGUAGE=$2
        shift 2
        ;;
esac

[ "$#" -eq 0 ] || {
    echo "Uso: bacusp update [--lang es|en]" >&2
    exit 2
}

case "$LANGUAGE" in
    en|EN) LANGUAGE=en ;;
    *) LANGUAGE=es ;;
esac

msg() {
    if [ "$LANGUAGE" = en ]; then
        case "$1" in
            title) echo "BACUSP UPDATE CENTER" ;;
            subtitle) echo "Choose the update categories:" ;;
            os) echo "Operating system packages" ;;
            drivers) echo "Drivers and firmware (through system packages)" ;;
            bacus) echo "Bacus-Pkg source checkout" ;;
            apps) echo "Applications (native package manager)" ;;
            prompt) echo "Enter numbers separated by spaces, e.g. 1 3:" ;;
            confirm) echo "Continue with these actions? Type YES:" ;;
            cancelled) echo "Cancelled. No updates were applied." ;;
            nochoice) echo "No valid category selected." ;;
            unsupported) echo "No supported package manager was detected." ;;
            caution) echo "Review the package manager's proposed changes before accepting." ;;
            noapps) echo "Bacus .bp repository updates are not configured." ;;
            nodrivers) echo "No separate safe driver updater is configured." ;;
            cleanrepo) echo "Bacus-Pkg source tree has local changes; refusing automatic update." ;;
            norepo) echo "This installation has no Git repository; self-update is unavailable." ;;
            fetch) echo "Checking for Bacus-Pkg updates..." ;;
            noupdates) echo "No Bacus-Pkg commits to apply, or remote comparison unavailable." ;;
            done) echo "Update operation finished." ;;
            root) echo "Administrator privileges may be required." ;;
        esac
    else
        case "$1" in
            title) echo "CENTRO DE ACTUALIZACIONES BACUSP" ;;
            subtitle) echo "Elegí las categorías:" ;;
            os) echo "Paquetes del sistema operativo" ;;
            drivers) echo "Controladores y firmware (mediante paquetes del sistema)" ;;
            bacus) echo "Código de Bacus-Pkg" ;;
            apps) echo "Aplicaciones (gestor nativo de paquetes)" ;;
            prompt) echo "Ingresá números separados por espacios, por ejemplo 1 3:" ;;
            confirm) echo "¿Continuar con estas acciones? Escribí SI:" ;;
            cancelled) echo "Cancelado. No se aplicaron actualizaciones." ;;
            nochoice) echo "No seleccionaste una categoría válida." ;;
            unsupported) echo "No se detectó un gestor de paquetes compatible." ;;
            caution) echo "Revisá los cambios propuestos por el gestor antes de aceptarlos." ;;
            noapps) echo "El repositorio de aplicaciones .bp no está configurado." ;;
            nodrivers) echo "No hay un actualizador independiente y seguro de controladores." ;;
            cleanrepo) echo "Bacus-Pkg tiene cambios locales; se cancela su actualización automática." ;;
            norepo) echo "Esta instalación no tiene repositorio Git; no se puede autoactualizar." ;;
            fetch) echo "Buscando actualizaciones de Bacus-Pkg..." ;;
            noupdates) echo "No hay commits para aplicar o no se pudo comparar el remoto." ;;
            done) echo "Proceso de actualización finalizado." ;;
            root) echo "Puede que se necesiten permisos de administrador." ;;
        esac
    fi
}

printf '\n%s\n' "$(msg title)"
printf '%s\n\n' "$(msg subtitle)"
printf '  1) %s\n' "$(msg os)"
printf '  2) %s\n' "$(msg drivers)"
printf '  3) %s\n' "$(msg bacus)"
printf '  4) %s\n\n' "$(msg apps)"
printf '%s ' "$(msg prompt)"
IFS= read -r CHOICES || exit 2

SELECT_OS=0
SELECT_DRIVERS=0
SELECT_BACUS=0
SELECT_APPS=0

for choice in $CHOICES; do
    case "$choice" in
        1) SELECT_OS=1 ;;
        2) SELECT_DRIVERS=1 ;;
        3) SELECT_BACUS=1 ;;
        4) SELECT_APPS=1 ;;
        *) ;;
    esac
done

if [ "$SELECT_OS" -eq 0 ] &&
   [ "$SELECT_DRIVERS" -eq 0 ] &&
   [ "$SELECT_BACUS" -eq 0 ] &&
   [ "$SELECT_APPS" -eq 0 ]; then
    msg nochoice
    exit 2
fi

printf '\n%s\n' "----------------------------------------"
[ "$SELECT_OS" -eq 0 ] || printf ' - %s\n' "$(msg os)"
[ "$SELECT_DRIVERS" -eq 0 ] || printf ' - %s\n' "$(msg drivers)"
[ "$SELECT_BACUS" -eq 0 ] || printf ' - %s\n' "$(msg bacus)"
[ "$SELECT_APPS" -eq 0 ] || printf ' - %s\n' "$(msg apps)"
printf '%s\n' "----------------------------------------"
printf '%s ' "$(msg confirm)"
IFS= read -r ANSWER || exit 2

if [ "$LANGUAGE" = en ]; then
    [ "$ANSWER" = YES ] || {
        msg cancelled
        exit 0
    }
else
    [ "$ANSWER" = SI ] || {
        msg cancelled
        exit 0
    }
fi

is_root() {
    [ "$(id -u)" -eq 0 ]
}

run_admin() {
    if is_root; then
        "$@"
    elif command -v sudo >/dev/null 2>&1; then
        sudo "$@"
    else
        msg root
        return 1
    fi
}

OS_NAME=$(uname -s 2>/dev/null || echo unknown)
IS_TERMUX=0
[ -n "${PREFIX:-}" ] && [ -x "${PREFIX}/bin/pkg" ] && IS_TERMUX=1

# Determine the available native package manager.
PM=""
if [ "$IS_TERMUX" -eq 1 ]; then
    PM=termux
elif command -v apt-get >/dev/null 2>&1; then
    PM=apt
elif command -v dnf >/dev/null 2>&1; then
    PM=dnf
elif command -v zypper >/dev/null 2>&1; then
    PM=zypper
elif command -v pacman >/dev/null 2>&1; then
    PM=pacman
elif command -v apk >/dev/null 2>&1; then
    PM=apk
elif command -v brew >/dev/null 2>&1; then
    PM=brew
fi

# The OS and application categories can overlap in native package managers.
# Run the native system update only once even if both were selected.
NATIVE_UPDATE=0
[ "$SELECT_OS" -eq 0 ] || NATIVE_UPDATE=1
[ "$SELECT_APPS" -eq 0 ] || NATIVE_UPDATE=1
[ "$SELECT_DRIVERS" -eq 0 ] || NATIVE_UPDATE=1

if [ "$NATIVE_UPDATE" -eq 1 ]; then
    if [ -z "$PM" ]; then
        msg unsupported
    else
        msg caution
        case "$PM" in
            termux)
                "${PREFIX}/bin/pkg" update
                "${PREFIX}/bin/pkg" upgrade
                ;;
            apt)
                run_admin apt-get update
                run_admin apt-get upgrade
                ;;
            dnf)
                run_admin dnf upgrade
                ;;
            zypper)
                run_admin zypper refresh
                run_admin zypper update
                ;;
            pacman)
                # Arch Linux requires a full system upgrade; avoid partial upgrades.
                run_admin pacman -Syu
                ;;
            apk)
                run_admin apk update
                run_admin apk upgrade
                ;;
            brew)
                brew update
                brew upgrade
                ;;
        esac
    fi
fi

# Drivers: no arbitrary vendor scripts are executed. On many Linux systems,
# kernel and firmware packages are delivered through the native package manager.
if [ "$SELECT_DRIVERS" -eq 1 ]; then
    msg nodrivers
fi

# A separate .bp application repository/update database is not yet configured.
if [ "$SELECT_APPS" -eq 1 ]; then
    msg noapps
fi

# Safely update the Bacus-Pkg source tree only if it is a clean Git checkout.
if [ "$SELECT_BACUS" -eq 1 ]; then
    MODULE_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
    REPO_DIR=$(CDPATH= cd -- "$MODULE_DIR/.." && pwd -P)

    if [ ! -d "$REPO_DIR/.git" ] || ! command -v git >/dev/null 2>&1; then
        msg norepo
    elif [ -n "$(git -C "$REPO_DIR" status --porcelain 2>/dev/null)" ]; then
        msg cleanrepo
    else
        msg fetch
        if git -C "$REPO_DIR" fetch --quiet; then
            if git -C "$REPO_DIR" rev-parse --abbrev-ref '@{upstream}' >/dev/null 2>&1; then
                BEHIND=$(git -C "$REPO_DIR" rev-list --count 'HEAD..@{upstream}' 2>/dev/null || echo 0)
                if [ "$BEHIND" -gt 0 ]; then
                    git -C "$REPO_DIR" merge --ff-only '@{upstream}'
                else
                    msg noupdates
                fi
            else
                msg noupdates
            fi
        else
            msg noupdates
        fi
    fi
fi

msg done
