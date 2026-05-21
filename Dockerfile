# --- ETAPA 1: Construcción/Descarga ---
FROM debian:bookworm-slim AS builder

# Parámetros de versión (Default a la última estable conocida)
ARG FACTORIO_VERSION=2.0.13
ARG ARCH=x64

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
    xz-utils \
    && rm -rf /var/lib/apt/lists/*

# Descarga del binario oficial headless
WORKDIR /tmp
RUN curl -fL https://www.factorio.com/get-download/${FACTORIO_VERSION}/headless/linux64 -o factorio.tar.xz \
    && tar -xJf factorio.tar.xz \
    && rm factorio.tar.xz

# --- ETAPA 2: Imagen Final ---
FROM debian:bookworm-slim

# Metadatos
LABEL maintainer="miguerubsk"
LABEL description="Factorio Headless Server - Lightweight, Secure & Flexible"

# Instalamos dependencias necesarias (libglib2.0-0 suele ser requerida por el binario de factorio)
RUN apt-get update && apt-get install -y --no-install-recommends \
    libc6 \
    libstdc++6 \
    libglib2.0-0 \
    curl \
    wget \
    unzip \
    jq \
    ca-certificates \
    xz-utils \
    && rm -rf /var/lib/apt/lists/*

# Crear usuario 'factorio'
RUN groupadd -g 845 factorio && \
    useradd -u 845 -g factorio -d /factorio -s /bin/bash factorio

# Crear estructura de carpetas
RUN mkdir -p /factorio/saves /factorio/mods /factorio/config /factorio/scenarios

# Copiar el juego desde la etapa anterior
# Nota: /tmp/factorio en el builder contiene la carpeta 'bin', 'data', etc.
COPY --from=builder /tmp/factorio /factorio/core

# Asegurar permisos correctos
RUN chown -R factorio:factorio /factorio

# Variables de entorno por defecto
ENV SAVE_NAME=factory_world \
    PORT=34197 \
    RCON_PORT=27015

# Puerto del Juego (UDP) y RCON (TCP)
EXPOSE 34197/udp 27015/tcp

# Directorio de trabajo y usuario
WORKDIR /factorio
USER factorio

# Volumen para persistencia
VOLUME ["/factorio/saves", "/factorio/mods", "/factorio/config"]

COPY entrypoint.sh /entrypoint.sh
# Volvemos a root temporalmente para asegurar que el script es ejecutable si se copió con otros permisos
USER root
RUN chmod +x /entrypoint.sh
USER factorio

ENTRYPOINT ["/entrypoint.sh"]