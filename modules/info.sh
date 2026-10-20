#!/bin/sh
# Módulo de información del sistema
echo "  _                    _ "
echo " | |__   __ _  ___ _ _| |"
echo " | '_ \ / _\` |/ __| ' \_|"
echo " |_.__/ \__,_|\___|_||_(_)"
echo "   --- chiquiOS / Bacusp ---"
echo ""
echo "📱 OS/Entorno : $(command -v pkg >/dev/null && echo 'iOS (a-shell)' || uname -s)"
echo "💻 Arquitectura: $(uname -m)"
echo "🐚 Shell       : $SHELL"
echo "📂 Carpeta     : $(pwd)"
