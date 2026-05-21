#!/bin/bash

# --- RUTAS ---
FACTORIO_PATH="/factorio"; CORE_PATH="${FACTORIO_PATH}/core"; CONFIG_PATH="${FACTORIO_PATH}/config"; DATA_EXAMPLE="${CORE_PATH}/data"
SETTINGS_JSON="${CONFIG_PATH}/server-settings.json"; MAP_GEN_JSON="${CONFIG_PATH}/map-gen-settings.json"; MAP_SET_JSON="${CONFIG_PATH}/map-settings.json"

# --- 1. LÓGICA DE DETECCIÓN DE VERSIONES ---
check_for_updates() {
    local updates_found=false
    
    # 1.1 Comprobar Juego
    if [ "${GAME_AUTO_UPDATE,,}" = "true" ]; then
        LATEST_URL=$(curl -sI https://www.factorio.com/get-download/stable/headless/linux64 | grep -i location | awk '{print $2}' | tr -d '\r')
        LATEST_VER=$(echo "$LATEST_URL" | sed -E 's/.*_([0-9]+\.[0-9]+\.[0-9]+)\.tar\.xz/\1/')
        CURRENT_VER=$("${CORE_PATH}/bin/x64/factorio" --version | head -n 1 | awk '{print $2}' || echo "0.0.0")
        [ "$LATEST_VER" != "$CURRENT_VER" ] && updates_found=true
    fi

    # 1.2 Comprobar Mods
    if [ "$updates_found" = "false" ] && [ "${MODS_AUTO_UPDATE,,}" = "true" ] && [ -n "$FACTORIO_USER" ]; then
        MOD_LIST="${FACTORIO_PATH}/mods/mod-list.json"
        mods_to_check=$(jq -r '.mods[] | select(.enabled == true) | .name' "$MOD_LIST" | grep -vE "^(base|quality|elevated-rails|space-age)$" || true)
        for mod in $mods_to_check; do
            mod_info=$(curl -s "https://mods.factorio.com/api/mods/$mod/full")
            latest_ver=$(echo "$mod_info" | jq -r '.releases | map(select(.info_json.factorio_version | startswith("2.0"))) | last | .version')
            current_zip=$(ls "${FACTORIO_PATH}/mods/${mod}"_*.zip 2>/dev/null | head -n 1)
            current_ver=$(basename "$current_zip" | sed -E "s/^${mod}_(.*)\.zip$/\1/" 2>/dev/null || echo "0.0.0")
            if [ "$latest_ver" != "null" ] && [ "$latest_ver" != "$current_ver" ]; then
                updates_found=true; break
            fi
        done
    fi
    [ "$updates_found" = "true" ] && return 0 || return 1
}

apply_updates() {
    echo "--- [MANTENIMIENTO] Aplicando actualizaciones detectadas ---"
    # Lógica de descarga idéntica a la anterior pero solo se llama si check_for_updates es 0
    if [ "${GAME_AUTO_UPDATE,,}" = "true" ]; then
        LATEST_URL=$(curl -sI https://www.factorio.com/get-download/stable/headless/linux64 | grep -i location | awk '{print $2}' | tr -d '\r')
        wget -q -O /tmp/factorio.tar.xz "$LATEST_URL" && tar -xJf /tmp/factorio.tar.xz -C /tmp/ && cp -r /tmp/factorio/* "$CORE_PATH/" && rm -rf /tmp/factorio /tmp/factorio.tar.xz
    fi
    if [ "${MODS_AUTO_UPDATE,,}" = "true" ]; then
        # Re-utilizamos la lógica de descarga de mods (omito por brevedad pero está en el script real)
        MODS_DIR="${FACTORIO_PATH}/mods"; MOD_LIST="${MODS_DIR}/mod-list.json"
        mods_to_check=$(jq -r '.mods[] | select(.enabled == true) | .name' "$MOD_LIST" | grep -vE "^(base|quality|elevated-rails|space-age)$" || true)
        for mod in $mods_to_check; do
            mod_info=$(curl -s "https://mods.factorio.com/api/mods/$mod/full")
            release=$(echo "$mod_info" | jq -r '.releases | map(select(.info_json.factorio_version | startswith("2.0"))) | last')
            latest_ver=$(echo "$release" | jq -r '.version'); download_url=$(echo "$release" | jq -r '.download_url')
            current_zip=$(ls "${MODS_DIR}/${mod}"_*.zip 2>/dev/null | head -n 1)
            current_ver=$(basename "$current_zip" | sed -E "s/^${mod}_(.*)\.zip$/\1/" 2>/dev/null || echo "0.0.0")
            if [ "$latest_ver" != "null" ] && [ "$latest_ver" != "$current_ver" ]; then
                full_url="https://mods.factorio.com${download_url}?username=${FACTORIO_USER}&token=${FACTORIO_TOKEN}"
                wget -q -O "${MODS_DIR}/${mod}_${latest_ver}.zip" "$full_url" && [ -n "$current_zip" ] && rm "$current_zip"
            fi
        done
    fi
}

# --- 2. CONFIGURACIÓN INICIAL ---
setup_server() {
    [ ! -f "$SETTINGS_JSON" ] && cp "${DATA_EXAMPLE}/server-settings.example.json" "$SETTINGS_JSON"
    [ ! -f "$MAP_GEN_JSON" ] && cp "${DATA_EXAMPLE}/map-gen-settings.example.json" "$MAP_GEN_JSON"
    [ ! -f "$MAP_SET_JSON" ] && cp "${DATA_EXAMPLE}/map-settings.example.json" "$MAP_SET_JSON"
    env | grep -E "^(FACTORIO_CONF__|MAP_GEN__|MAP_SET__)" | while IFS='=' read -r env_key env_value; do
        prefix=$(echo "$env_key" | cut -d'_' -f1-2)"__"; target_file=""
        [[ "$env_key" == FACTORIO_CONF__* ]] && target_file="$SETTINGS_JSON"
        [[ "$env_key" == MAP_GEN__* ]] && target_file="$MAP_GEN_JSON"
        [[ "$env_key" == MAP_SET__* ]] && target_file="$MAP_SET_JSON"
        jq_path=".$(echo "$env_key" | sed "s/^${prefix}//" | sed 's/__/./g')"
        if [[ "$env_value" =~ ^(true|false)$ ]] || [[ "$env_value" =~ ^-?[0-9]+(\.[0-9]+)?$ ]]; then
            jq "$jq_path = $env_value" "$target_file" > "${target_file}.tmp" && mv "${target_file}.tmp" "$target_file"
        elif [[ "$env_value" =~ ^\[.*\]$ || "$env_value" =~ ^\{.*\}$ ]]; then
            jq "$jq_path = $env_value" "$target_file" > "${target_file}.tmp" && mv "${target_file}.tmp" "$target_file"
        else
            jq "$jq_path = \"$env_value\"" "$target_file" > "${target_file}.tmp" && mv "${target_file}.tmp" "$target_file"
        fi
    done
    MODS_DIR="${FACTORIO_PATH}/mods"; MOD_LIST="${MODS_DIR}/mod-list.json"
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
    SAVE_FILE="${FACTORIO_PATH}/saves/${SAVE_NAME:-factory_world}.zip"
    [ ! -f "$SAVE_FILE" ] && "${CORE_PATH}/bin/x64/factorio" --create "$SAVE_FILE" --map-gen-settings "$MAP_GEN_JSON" --map-settings "$MAP_SET_JSON"
}

# --- 3. WATCHDOG INTELIGENTE ---
RESTART_PENDING=false
check_cron() {
    read -r c_min c_hour c_dom c_mon c_dow <<< "$1"
    read -r d_min d_hour d_dom d_mon d_dow <<< "$(date +'%M %H %d %m %u')"
    [[ ("$c_min" == "*" || "$c_min" == "$d_min") && ("$c_hour" == "*" || "$c_hour" == "$d_hour") ]] && return 0 || return 1
}

watchdog() {
    local schedule=$1
    echo "--- [WATCHDOG] Mantenimiento programado: $schedule ---"
    while true; do
        if [[ "$schedule" =~ ^[0-9]{2}:[0-9]{2}$ ]]; then
            target_s=$(date -d "$schedule" +%s); now_s=$(date +%s)
            [ $target_s -le $now_s ] && target_s=$((target_s + 86400))
            sleep $((target_s - now_s))
            MATCH=true
        else
            sleep 60; check_cron "$schedule" && MATCH=true || MATCH=false
        fi
        
        if [ "$MATCH" = "true" ]; then
            echo "--- [WATCHDOG] Hora de mantenimiento. Comprobando si hay actualizaciones... ---"
            if check_for_updates; then
                echo "--- [WATCHDOG] ¡Actualizaciones disponibles! Reiniciando proceso... ---"
                RESTART_PENDING=true; pkill -TERM factorio; sleep 30
            else
                echo "--- [WATCHDOG] No hay actualizaciones. El servidor seguirá online. ---"
                # Esperar 2 minutos para no volver a entrar en el mismo minuto cron
                sleep 120
            fi
        fi
    done
}

# Iniciamos el watchdog solo si hay algo que actualizar
([ "${GAME_AUTO_UPDATE,,}" = "true" ] || [ "${MODS_AUTO_UPDATE,,}" = "true" ]) && watchdog "${GAME_UPDATE_SCHEDULE:-04:00}" &

# --- 4. BUCLE PRINCIPAL ---
setup_server # Ejecutar setup inicial
while true; do
    # Al arrancar siempre comprobamos por si acabamos de iniciar el contenedor manualmente
    check_for_updates && apply_updates
    
    RCON_ARGS=""
    [ "${RCON_ENABLED,,}" = "true" ] && RCON_ARGS="--rcon-port ${RCON_PORT:-27015} --rcon-password ${RCON_PASSWORD:-factorio_pass}"
    
    echo "--- [INICIO] Arrancando Factorio ---"
    "${CORE_PATH}/bin/x64/factorio" --start-server "${FACTORIO_PATH}/saves/${SAVE_NAME:-factory_world}.zip" --port "${PORT:-34197}" --server-settings "$SETTINGS_JSON" $RCON_ARGS "$@" &
    
    FACTORIO_PID=$!; wait $FACTORIO_PID
    
    if [ "$RESTART_PENDING" = "true" ]; then
        RESTART_PENDING=false; continue
    fi
    echo "--- [ERROR] Proceso detenido inesperadamente. Reintentando en 10s... ---"; sleep 10
done
