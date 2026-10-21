# 🤝 Guía de Contribución para Bacusp

¡Gracias por querer colaborar en `bacus-pkg`!

## 📜 Reglas de Diseño (Pure Standalone)
1. **Cero Dependencias Exógenas:** Todo módulo debe ser escrito en código POSIX Shell estándar (`#!/bin/sh`).
2. **Modularidad:** Cada función nueva debe ir en su propio script dentro de `modules/`.
3. **Bilingüe:** Mantené los mensajes y ayuda con soporte tanto en Español como en Inglés.
4. **Eficiencia:** Usá un impacto mínimo de CPU y RAM pensados para sistemas embebidos y móviles (`a-shell`).

## 🛠️ Cómo agregar un módulo nuevo
1. Creá tu archivo `.sh` dentro de la carpeta `modules/` (ej: `modules/mi-modulo.sh`).
2. Vinculalo al enrutador principal en `bin/bacusp`.
3. Hacé un Pull Request explicando los cambios.
