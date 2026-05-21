#!/bin/bash
# set -e  # Eliminamos set -e para que el bucle de reinicio no muera si algo falla puntualmente

# --- RUTAS ---
FACTORIO_PATH="/factorio"
CORE_PATH="${FACTORIO_PATH}/core"
CONFIG_PATH="${FACTORIO_PATH}/config"
DATA_EXAMPLE="${CORE_PATH}/data"

# Archivos destino
SETTINGS_JSON="${CONFIG_PATH}/server-settings.json"
MAP_GEN_JSON="${CONFIG_PATH}/map-gen-settings.json"
MAP_SET_JSON="${CONFIG_PATH}/map-settings.json"

# --- FUNCIÓN DE ACTUALIZACIÓN (Juego y Mods) ---
perform_updates() {
    echo "--- [MANTENIMIENTO] Iniciando comprobación de actualizaciones ---"
    
    # 1. Actualización del Binario
    if [ "${GAME_AUTO_UPDATE,,}" = "true" ]; then
        LATEST_URL=$(curl -sI https://www.factorio.com/get-download/stable/headless/linux64 | grep -i location | awk '{print $2}' | tr -d '\r')
        if [ -n "$LATEST_URL" ]; then
            LATEST_VER=$(echo "$LATEST_URL" | sed -E 's/.*_([0-9]+\.[0-9]+\.[0-9]+)\.tar\.xz/\1/')
            CURRENT_VER=$("${CORE_PATH}/bin/x64/factorio" --version | head -n 1 | awk '{print $2}' || echo "0.0.0")
            if [ "$LATEST_VER" != "$CURRENT_VER" ]; then
                echo "--- [GAME] Actualizando: $CURRENT_VER -> $LATEST_VER ---"
                wget -q -O /tmp/factorio.tar.xz "$LATEST_URL"
                tar -xJf /tmp/factorio.tar.xz -C /tmp/
                cp -r /tmp/factorio/* "$CORE_PATH/"
                rm -rf /tmp/factorio /tmp/factorio.tar.xz
            fi
        fi
    fi

    # 2. Actualización de Mods
    if [ "${MODS_AUTO_UPDATE,,}" = "true" ] && [ -n "$FACTORIO_USER" ] && [ -n "$FACTORIO_TOKEN" ]; then
        MODS_DIR="${FACTORIO_PATH}/mods"
        MOD_LIST="${MODS_DIR}/mod-list.json"
        mods_to_check=$(jq -r '.mods[] | select(.enabled == true) | .name' "$MOD_LIST" | grep -vE "^(base|quality|elevated-rails|space-age)$" || true)
        for mod in $mods_to_check; do
            mod_info=$(curl -s "https://mods.factorio.com/api/mods/$mod/full")
            latest_release=$(echo "$mod_info" | jq -r '.releases | map(select(.info_json.factorio_version | startswith("2.0"))) | last')
            if [ "$latest_release" != "null" ]; then
                latest_ver=$(echo "$latest_release" | jq -r '.version')
                download_url=$(echo "$latest_release" | jq -r '.download_url')
                current_zip=$(ls "${MODS_DIR}/${mod}"_*.zip 2>/dev/null | head -n 1)
                current_ver="0.0.0"
                [ -n "$current_zip" ] && current_ver=$(basename "$current_zip" | sed -E "s/^${mod}_(.*)\.zip$/\1/")
                if [ "$latest_ver" != "$current_ver" ]; then
                    full_url="https://mods.factorio.com${download_url}?username=${FACTORIO_USER}&token=${FACTORIO_TOKEN}"
                    if wget -q -O "${MODS_DIR}/${mod}_${latest_ver}.zip" "$full_url"; then
                        [ -n "$current_zip" ] && [ "${MODS_DIR}/${mod}_${latest_ver}.zip" != "$current_zip" ] && rm "$current_zip"
                    fi
                fi
            fi
        done
    fi
}

# --- FUNCIÓN DE CONFIGURACIÓN INICIAL ---
setup_server() {
    # Preparar JSONs
    [ ! -f "$SETTINGS_JSON" ] && cp "${DATA_EXAMPLE}/server-settings.example.json" "$SETTINGS_JSON"
    [ ! -f "$MAP_GEN_JSON" ] && cp "${DATA_EXAMPLE}/map-gen-settings.example.json" "$MAP_GEN_JSON"
    [ ! -f "$MAP_SET_JSON" ] && cp "${DATA_EXAMPLE}/map-settings.example.json" "$MAP_SET_JSON"

    # Inyección de variables
    env | grep -E "^(FACTORIO_CONF__|MAP_GEN__|MAP_SET__)" | while IFS='=' read -r env_key env_value; do
        prefix=$(echo "$env_key" | cut -d'_' -f1-2)"__"
        target_file=""
        [[ "$env_key" == FACTORIO_CONF__* ]] && target_file="$SETTINGS_JSON"
        [[ "$env_key" == MAP_GEN__* ]] && target_file="$MAP_GEN_JSON"
        [[ "$env_key" == MAP_SET__* ]] && target_file="$MAP_SET_JSON"
        
        key_full=$(echo "$env_key" | sed "s/^${prefix}//")
        jq_path=".$(echo "$key_full" | sed 's/__/./g')"
        if [[ "$env_value" =~ ^(true|false)$ ]] || [[ "$env_value" =~ ^-?[0-9]+(\.[0-9]+)?$ ]]; then
            jq "$jq_path = $env_value" "$target_file" > "${target_file}.tmp" && mv "${target_file}.tmp" "$target_file"
        elif [[ "$env_value" =~ ^\[.*\]$ || "$env_value" =~ ^\{.*\}$ ]]; then
            jq "$jq_path = $env_value" "$target_file" > "${target_file}.tmp" && mv "${target_file}.tmp" "$target_file"
        else
            jq "$jq_path = \"$env_value\"" "$target_file" > "${target_file}.tmp" && mv "${target_file}.tmp" "$target_file"
        fi
    done

    # Gestión de Mods/DLC inicial
    MODS_DIR="${FACTORIO_PATH}/mods"
    MOD_LIST="${MODS_DIR}/mod-list.json"
    [ ! -d "$MODS_DIR" ] && mkdir -p "$MODS_DIR"
    [ ! -f "$MOD_LIST" ] && echo '{"mods": [{"name": "base", "enabled": true}]}' > "$MOD_LIST"

    update_mod_status() {
        if jq -e ".mods[] | select(.name == \"$1\")" "$MOD_LIST" > /dev/null; then
            jq "(.mods[] | select(.name == \"$1\")).enabled = $2" "$MOD_LIST" > "${MOD_LIST}.tmp" && mv "${MOD_LIST}.tmp" "$MOD_LIST"
        else
            jq ".mods += [{\"name\": \"$1\", \"enabled\": $2}]" "$MOD_LIST" > "${MOD_LIST}.tmp" && mv "${MOD_LIST}.tmp" "$MOD_LIST"
        fi
    }

    for mod_zip in "${MODS_DIR}"/*.zip; do
        [ -e "$mod_zip" ] || continue
        internal_name=$(unzip -p "$mod_zip" "*/info.json" | jq -r '.name' 2>/dev/null)
        [ -n "$internal_name" ] && [ "$internal_name" != "null" ] && update_mod_status "$internal_name" "true"
    done

    if [ "${DLC_SPACE_AGE,,}" = "true" ]; then DLC_QUALITY="true"; DLC_ELEVATED_RAILS="true"; fi
    [ -n "$DLC_ELEVATED_RAILS" ] && update_mod_status "elevated-rails" "${DLC_ELEVATED_RAILS,,}"
    [ -n "$DLC_QUALITY" ]        && update_mod_status "quality"        "${DLC_QUALITY,,}"
    [ -n "$DLC_SPACE_AGE" ]      && update_mod_status "space-age"       "${DLC_SPACE_AGE,,}"

    # Mapa
    SAVE_FILE="${FACTORIO_PATH}/saves/${SAVE_NAME:-factory_world}.zip"
    if [ ! -f "$SAVE_FILE" ]; then
        "${CORE_PATH}/bin/x64/factorio" --create "$SAVE_FILE" --map-gen-settings "$MAP_GEN_JSON" --map-settings "$MAP_SET_JSON"
    fi
}

# --- WATCHDOG DE REINICIO INTERNO ---
RESTART_PENDING=false
watchdog() {
    local schedule=$1
    while true; do
        target_s=$(date -d "$schedule" +%s)
        now_s=$(date +%s)
        [ $target_s -le $now_s ] && target_s=$((target_s + 86400))
        sleep $((target_s - now_s))
        
        echo "--- [WATCHDOG] Programando reinicio para mantenimiento ($schedule) ---"
        RESTART_PENDING=true
        pkill -TERM factorio
    done
}

[ "${MODS_AUTO_UPDATE,,}" = "true" ] && watchdog "${MODS_UPDATE_SCHEDULE:-04:00}" &
[ "${GAME_AUTO_UPDATE,,}" = "true" ] && watchdog "${GAME_UPDATE_SCHEDULE:-04:00}" &

# --- BUCLE PRINCIPAL (Mantiene el contenedor vivo) ---
while true; do
    perform_updates
    setup_server
    
    RCON_ARGS=""
    [ "${RCON_ENABLED,,}" = "true" ] && RCON_ARGS="--rcon-port ${RCON_PORT:-27015} --rcon-password ${RCON_PASSWORD:-factorio_pass}"

    echo "--- [INICIO] Arrancando proceso de Factorio ---"
    "${CORE_PATH}/bin/x64/factorio" \
        --start-server "${FACTORIO_PATH}/saves/${SAVE_NAME:-factory_world}.zip" \
        --port "${PORT:-34197}" \
        --server-settings "$SETTINGS_JSON" \
        $RCON_ARGS "$@" &
    
    FACTORIO_PID=$!
    wait $FACTORIO_PID
    
    if [ "$RESTART_PENDING" = "true" ]; then
        echo "--- [RESTART] Reinicio programado detectado. Iniciando nuevo ciclo. ---"
        RESTART_PENDING=false
        continue
    fi
    
    echo "--- [ERROR] El proceso de Factorio terminó inesperadamente. Reiniciando en 10s... ---"
    sleep 10
done
