🐢 Bacus-Pkg

Un gestor de paquetes multiplataforma con su propio formato de paquetes .bp.

A cross-platform package manager with its own .bp package format.

Español · English

⸻

Español

¿Qué es Bacus-Pkg?

Bacus-Pkg es un proyecto de gestor de paquetes diseñado para organizar, crear, inspeccionar y convertir paquetes mediante un formato propio llamado .bp.

El proyecto busca ofrecer una forma flexible de empaquetar aplicaciones, código fuente, documentos, recursos y archivos necesarios para distribuir un proyecto.

✨ Características del proyecto

* Formato .bp: formato de paquete propio en desarrollo.
* bacusp install: comando previsto para instalar paquetes .bp.
* bacusp convert: herramienta para convertir o empaquetar archivos compatibles en un .bp.
* bacusp bridge: analizador para estudiar la compatibilidad de paquetes con distintas plataformas.
* Multiplataforma: objetivo de compatibilidad con Linux, Windows, Unix, Termux y otros entornos.
* Proyectos con varios lenguajes: posibilidad de incluir Python, C, C++, JavaScript, HTML, CSS y otros archivos.
* Bilingüe: documentación y comandos orientados a usuarios de español e inglés.

Algunas características están en desarrollo. La compatibilidad real depende de la implementación, el formato de origen y el sistema de destino.

📦 ¿Qué es un archivo .bp?

Un .bp es el formato de paquete propio que Bacus-Pkg pretende utilizar para reunir archivos de un proyecto en una sola unidad.

Un paquete puede incluir, por ejemplo:

Perritos.bp
├── Código de la aplicación
├── Imágenes y sonidos
├── Documentación
├── Recursos
└── Metadatos del paquete

Esta estructura es una representación conceptual del contenido; no significa que el archivo binario se almacene como una carpeta normal.

🛠️ Comandos previstos

bacusp install Perritos.bp
bacusp convert archivo-origen destino.bp
bacusp bridge Perritos.bp

* install: instala un paquete compatible.
* convert: recibe un archivo de origen y genera un .bp cuando el conversor admite ese tipo de entrada.
* bridge: analiza la compatibilidad con una plataforma.

La sintaxis y las funciones disponibles pueden variar según la versión implementada.

🌍 Objetivo

Bacus-Pkg busca facilitar la distribución de aplicaciones y recursos en un formato común, con herramientas que ayuden a analizar la compatibilidad entre sistemas operativos.

Importante: convertir un archivo a .bp no convierte automáticamente su código a otro lenguaje ni garantiza que funcione en todas las plataformas. La instalación y ejecución requieren compatibilidad con el contenido del paquete y el sistema de destino.

🚧 Estado del proyecto

Bacus-Pkg está en desarrollo. El formato .bp, el conversor, el instalador y el analizador de compatibilidad deben probarse conjuntamente antes de considerarse una solución estable.

🤝 Contribuciones

Las sugerencias, pruebas, informes de errores y contribuciones son bienvenidos.

📄 Licencia

Consultá el archivo LICENSE del repositorio para conocer las condiciones de uso, modificación y distribución.

⸻

English

What is Bacus-Pkg?

Bacus-Pkg is a package manager project designed to organize, create, inspect, and convert packages using its own .bp format.

The project aims to provide a flexible way to package applications, source code, documents, resources, and other files required to distribute a project.

✨ Project features

* .bp format: a custom package format under development.
* bacusp install: planned command for installing .bp packages.
* bacusp convert: tool for converting or packaging supported input files into .bp.
* bacusp bridge: compatibility analyzer for different platforms.
* Cross-platform goals: Linux, Windows, Unix, Termux, and other environments.
* Multi-language projects: support for projects containing Python, C, C++, JavaScript, HTML, CSS, and other files.
* Bilingual approach: documentation and commands intended for Spanish- and English-speaking users.

Some features are under development. Actual compatibility depends on the implementation, source format, and target system.

📦 What is a .bp file?

A .bp file is Bacus-Pkg’s custom package format, intended to bundle project files into a single unit.

For example, a package may contain application code, images, sounds, documentation, resources, and package metadata.

🛠️ Planned commands

bacusp install Perritos.bp
bacusp convert source-file destination.bp
bacusp bridge Perritos.bp

* install: installs a compatible package.
* convert: creates a .bp package from supported input.
* bridge: analyzes compatibility with a target platform.

Available syntax and functionality may vary by implementation and version.

🌍 Project goals

Bacus-Pkg aims to simplify application and resource distribution through a common package format and tools for analyzing cross-platform compatibility.

Converting a file into .bp does not automatically translate its code or guarantee execution on every operating system.

🚧 Project status

Bacus-Pkg is under development. The package format, converter, installer, and compatibility analyzer must be tested together before being considered stable.

🤝 Contributing

Suggestions, testing, bug reports, and contributions are welcome.

📄 License

See the repository’s LICENSE file for the applicable terms of use, modification, and distribution.