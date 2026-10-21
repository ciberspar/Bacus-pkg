#!/bin/sh
# ======================================================
#  BACUSP MODULE: SPEEDTEST ⚡
#  Medición de latencia de espejos y repositorios
# ======================================================

cmd_speedtest() {
    echo "⚡ Probando latencia de los espejos oficiales..."
    
    TARGET_URL="https://raw.githubusercontent.com"
    
    if command -v curl >/dev/null 2>&1; then
        TIME=$(curl -o /dev/null -s -w '%{time_total}\n' "$TARGET_URL")
        echo "🌐 GitHub Raw API Latencia: ${TIME}s"
    elif command -v wget >/dev/null 2>&1; then
        echo "🌐 Probando conexión con wget..."
        wget -q --spider "$TARGET_URL" && echo "✅ Conexión con espejo principal OK"
    else
        echo "❌ Se requiere 'curl' o 'wget' para la prueba de velocidad."
    fi
}
