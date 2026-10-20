# Usamos una imagen base liviana de Alpine Linux
FROM alpine:latest

# Instalamos lo necesario (Bash, curl, etc., por si tu script lo necesita)
RUN apk add --no-cache bash curl

# Copiamos tu script o binario dentro del contenedor
COPY script.sh /usr/local/bin/mi-herramienta

# Le damos permisos de ejecución
RUN chmod +x /usr/local/bin/mi-herramienta

# Comando por defecto
CMD ["mi-herramienta"]
