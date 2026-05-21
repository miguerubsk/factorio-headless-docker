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
RUN curl -L https://www.factorio.com/get-download/${FACTORIO_VERSION}/headless/linux64 -o factorio.tar.xz \
    && tar -xJf factorio.tar.xz \
    && rm factorio.tar.xz

# --- ETAPA 2: Imagen Final ---
FROM debian:bookworm-slim

# Metadatos
LABEL maintainer="miguerubsk"
LABEL description="Factorio Headless Server - Lightweight, Secure & Flexible"

# Instalamos solo lo mínimo indispensable
RUN apt-get update && apt-get install -y --no-install-recommends \
    libc6 \
    libstdc++6 \
    curl \
    wget \
    unzip \
    jq \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Crear usuario 'factorio' (UID/GID 845 es arbitrario pero fijo)
RUN groupadd -g 845 factorio && \
    useradd -u 845 -g factorio -d /factorio -s /bin/bash factorio

# Crear estructura de carpetas
RUN mkdir -p /factorio/saves /factorio/mods /factorio/config /factorio/scenarios /factorio/core

# Copiar el juego desde la etapa anterior
COPY --from=builder /tmp/factorio /factorio/core

# Copiar y preparar el script de entrada
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh && \
    chown -R factorio:factorio /factorio

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

ENTRYPOINT ["/entrypoint.sh"]