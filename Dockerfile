# --- ETAPA 1: Construcción/Descarga ---
FROM debian:bookworm-slim AS builder

# Parámetros de versión
ARG FACTORIO_VERSION=1.0.0
ARG ARCH=x64

RUN apt-get update && apt-get install -y \
    curl \
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
LABEL description="Factorio Headless Server v1.0 - Lightweight & Flexible"

# Instalamos solo lo mínimo indispensable para que el binario y los scripts funcionen
RUN apt-get update && apt-get install -y \
    libc6 \
    libstdc++6 \
    curl \
    jq \
    && rm -rf /var/lib/apt/lists/*

# Crear estructura de carpetas
RUN mkdir -p /factorio /factorio/saves /factorio/mods /factorio/config /factorio/scenarios

# Copiar el juego desde la etapa anterior
COPY --from=builder /tmp/factorio /factorio/core

# Variables de entorno por defecto para personalización
ENV SAVE_NAME=factory_world \
    MAP_GEN_SETTINGS=/factorio/config/map-gen-settings.json \
    MAP_SETTINGS=/factorio/config/map-settings.json \
    SERVER_SETTINGS=/factorio/config/server-settings.json \
    PORT=34197

# Puerto del Juego (UDP) y RCON (TCP)
EXPOSE 34197/udp 27015/tcp

# Directorio de trabajo y volumen para persistencia
WORKDIR /factorio
VOLUME ["/factorio/saves", "/factorio/mods", "/factorio/config"]

# Copiaremos el script de entrada (lo crearemos a continuación)
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
