#!/bin/bash
set -e

# --- RUTAS ---
FACTORIO_PATH="/factorio"
CORE_PATH="${FACTORIO_PATH}/core"
CONFIG_PATH="${FACTORIO_PATH}/config"
DATA_EXAMPLE="${CORE_PATH}/data"

# Archivos destino
SETTINGS_JSON="${CONFIG_PATH}/server-settings.json"
MAP_GEN_JSON="${CONFIG_PATH}/map-gen-settings.json"
MAP_SET_JSON="${CONFIG_PATH}/map-settings.json"

# --- 1. PREPARACIÓN DE ARCHIVOS ---
# Si no existen, los inicializamos desde los ejemplos del juego
[ ! -f "$SETTINGS_JSON" ] && cp "${DATA_EXAMPLE}/server-settings.example.json" "$SETTINGS_JSON"
[ ! -f "$MAP_GEN_JSON" ] && cp "${DATA_EXAMPLE}/map-gen-settings.example.json" "$MAP_GEN_JSON"
[ ! -f "$MAP_SET_JSON" ] && cp "${DATA_EXAMPLE}/map-settings.example.json" "$MAP_SET_JSON"

# --- 2. FUNCIÓN DE INYECCIÓN ---
apply_configs() {
    local prefix=$1
    local target_file=$2
    echo "--- [CONFIG] Procesando prefijo $prefix para $(basename "$target_file") ---"

    # Usamos while read para evitar problemas con espacios o caracteres especiales
    env | grep "^${prefix}" | while IFS='=' read -r env_key env_value; do
        key_full=$(echo "$env_key" | sed "s/^${prefix}//")
        jq_path=".$(echo "$key_full" | sed 's/__/./g')"

        echo "  > Inyectando $jq_path"

        # Detectar tipo de dato para JQ
        if [[ "$env_value" =~ ^(true|false)$ ]] || [[ "$env_value" =~ ^-?[0-9]+(\.[0-9]+)?$ ]]; then
            # Booleano o Número
            jq "$jq_path = $env_value" "$target_file" > "${target_file}.tmp" && mv "${target_file}.tmp" "$target_file"
        elif [[ "$env_value" =~ ^\[.*\]$ || "$env_value" =~ ^\{.*\}$ ]]; then
            # Array u Objeto JSON
            jq "$jq_path = $env_value" "$target_file" > "${target_file}.tmp" && mv "${target_file}.tmp" "$target_file"
        else
            # String (por defecto)
            jq "$jq_path = \"$env_value\"" "$target_file" > "${target_file}.tmp" && mv "${target_file}.tmp" "$target_file"
        fi
    done
}

# --- 3. APLICAR CONFIGURACIONES ---
apply_configs "FACTORIO_CONF__" "$SETTINGS_JSON"
apply_configs "MAP_GEN__" "$MAP_GEN_JSON"
apply_configs "MAP_SET__" "$MAP_SET_JSON"

# --- 4. GESTIÓN DE RCON Y MAPA ---
RCON_ARGS=""
if [ "${RCON_ENABLED,,}" = "true" ]; then
    RCON_ARGS="--rcon-port ${RCON_PORT:-27015} --rcon-password ${RCON_PASSWORD:-factorio_pass}"
fi

SAVE_FILE="${FACTORIO_PATH}/saves/${SAVE_NAME:-factory_world}.zip"

if [ ! -f "$SAVE_FILE" ]; then
    echo "--- [MAPA] Generando nuevo mundo con los settings aplicados ---"
    "${CORE_PATH}/bin/x64/factorio" --create "$SAVE_FILE" \
        --map-gen-settings "$MAP_GEN_JSON" \
        --map-settings "$MAP_SET_JSON"
fi

# --- 5. LANZAMIENTO ---
echo "--- [INICIO] Arrancando servidor Factorio ---"
exec "${CORE_PATH}/bin/x64/factorio" \
    --start-server "$SAVE_FILE" \
    --port "${PORT:-34197}" \
    --server-settings "$SETTINGS_JSON" \
    $RCON_ARGS "$@"