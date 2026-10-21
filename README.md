# 🐢 BACUSP (bacus-pkg) v5.1 Pure Standalone

> Un ecosistema de gestión de paquetes modular, ultraliviano y bilingüe (ES/EN), diseñado bajo la filosofía *Pure Standalone* para funcionar de forma autónoma en POSIX shells, Linux, macOS, iOS (`a-shell`), Termux y más.

---

## 🏛️ Arquitectura del Proyecto

`bacusp` está estructurado para mantener una huella de almacenamiento mínima (en el orden de los kilobytes), delegando cada tarea a módulos independientes y contando con un demonio centinela y autocompletado en `bin/`:

```text
bacus-pkg/
├── bin/
│   ├── bacusp             # Enrutador y motor principal del CLI
│   ├── bacusp-daemon      # Centinela Watch Dogs en segundo plano (Silencioso)
│   └── bacusp-completion  # Motor de autocompletado inteligente (Tab)
├── modules/               # Módulos de funciones independientes (.sh)
│   ├── aliases.sh         # Gestión de alias y atajos
│   ├── audit.sh           # Auditoría de seguridad de paquetes
│   ├── backup.sh          # Copias de seguridad del sistema
│   ├── bridge.sh          # Puente de compilación remota vía GitHub
│   ├── clean.sh           # Limpieza de archivos temporales y caché
│   ├── deps.sh            # Resolución de dependencias pre-compilación
│   ├── doctor.sh          # Autodiagnóstico del sistema y rutas
│   ├── export.sh          # Exportación del entorno a tar.gz
│   ├── fetch.sh           # Sysinfo ASCII y especificaciones
│   ├── friends.sh         # Red social y de repositorios amigos
│   ├── info.sh            # Diagnóstico profundo de paquetes
│   ├── optimize.sh        # Compresión y optimización de binarios
│   ├── purge.sh           # Limpieza profunda (binario + configs)
│   ├── repo.sh            # Gestión de repositorios personalizados
│   ├── search.sh          # Búsqueda en el índice de GitHub
│   └── upgrade.sh         # Actualización del núcleo y el SO
├── install.sh             # Instalador automático y configurador de entorno
└── README.md              # Documentación oficial
