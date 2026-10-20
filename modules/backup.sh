#!/bin/sh
# ======================================================
#  Módulo Backup - Bacusp 💾
# ======================================================

FECHA=$(date +%Y%m%d_%H%M%S)
DESTINO="$HOME/Documents/bacus_backup_$FECHA.tar.gz"

echo "📦 Creando copia de seguridad de tus proyectos..."
tar -czf "$DESTINO" -C "$HOME/Documents" . 2>/dev/null

echo "✅ Backup guardado exitosamente en:"
echo "   📄 $DESTINO"
