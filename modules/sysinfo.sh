#!/bin/sh
# ======================================================
#  Módulo SysInfo - Bacusp 📊
# ======================================================

echo "📊 Estado del Sistema (chiquiOS)"
echo "--------------------------------------------------"
echo "📅 Fecha y hora : $(date)"
echo "🌐 Conexión IP  : $(curl -s https://api.ipify.org || echo 'Sin conexión')"
echo "📂 Directorio   : $HOME"
echo "💾 Espacio libre: $(df -h . | tail -n 1 | awk '{print $4}')"
echo "--------------------------------------------------"
