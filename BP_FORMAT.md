Formato de paquetes Bacus-Pkg (BP)

Bacus-Pkg Package Format (BP)

Autor / Author: Ciberspar
Proyecto / Project: Bacus-Pkg
Versión de especificación / Specification version: BP v2
Formato / Format: .bp

1. Propósito / Purpose

ES: BP es un formato de paquetes diseñado para distribuir aplicaciones, archivos, metadatos y variantes para distintos sistemas operativos. Un paquete .bp no garantiza por sí mismo que una aplicación sea compatible con todos los sistemas.

EN: BP is a package format designed to distribute applications, files, metadata and variants for different operating systems. A .bp package does not, by itself, guarantee that an application is compatible with every operating system.

2. Estructura / Structure

ES: Un paquete BP v2 contiene un manifiesto, información de compatibilidad, sumas de verificación y los archivos de la aplicación.

EN: A BP v2 package contains a manifest, compatibility information, checksums and application files.

Archivos obligatorios / Required files:

* manifest.tsv
* COMPATIBILITY.txt
* checksums.sha256
* payload/

3. Idiomas / Languages

ES: Las herramientas oficiales deben admitir español e inglés. El idioma de los mensajes no debe cambiar la interpretación técnica del paquete. Los metadatos descriptivos pueden ofrecer variantes como description.es y description.en.

EN: Official tools must support Spanish and English. The message language must not change the technical interpretation of a package. Descriptive metadata may provide variants such as description.es and description.en.

4. Compatibilidad / Compatibility

ES: Cada paquete debe declarar los sistemas operativos, las arquitecturas y las dependencias que necesita. Si la compatibilidad no está demostrada, el gestor debe indicarlo claramente.

EN: Each package must declare its required operating systems, architectures and dependencies. If compatibility has not been demonstrated, the package manager must state this clearly.

5. Seguridad / Security

ES: El instalador debe validar las rutas, comprobar la integridad de los archivos y evitar escribir fuera de las ubicaciones autorizadas. Las sumas de verificación no sustituyen las firmas digitales.

EN: The installer must validate paths, verify file integrity and prevent writes outside authorized locations. Checksums do not replace digital signatures.

6. Versionado / Versioning

ES: Los cambios incompatibles en la estructura o el significado de los campos requieren una nueva versión de la especificación.

EN: Incompatible changes to the structure or meaning of fields require a new specification version.

7. Portabilidad / Portability

ES: BP puede contener variantes para distintos sistemas y arquitecturas. El gestor debe seleccionar únicamente una variante compatible. El formato no convierte automáticamente ejecutables nativos entre plataformas.

EN: BP can contain variants for different systems and architectures. The package manager must select only a compatible variant. The format does not automatically translate native executables between platforms.