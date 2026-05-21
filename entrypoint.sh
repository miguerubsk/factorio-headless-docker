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

# --- 5. GESTIÓN DE MODS / DLC (Factorio 2.0+) ---
MODS_DIR="${FACTORIO_PATH}/mods"
MOD_LIST="${MODS_DIR}/mod-list.json"
DOWNLOAD_LIST="${MODS_DIR}/download-list.txt"

[ ! -d "$MODS_DIR" ] && mkdir -p "$MODS_DIR"
if [ ! -f "$MOD_LIST" ]; then
    echo '{"mods": [{"name": "base", "enabled": true}]}' > "$MOD_LIST"
fi

update_mod_status() {
    local mod_name=$1
    local enabled=$2
    if jq -e ".mods[] | select(.name == \"$mod_name\")" "$MOD_LIST" > /dev/null; then
        jq "(.mods[] | select(.name == \"$mod_name\")).enabled = $enabled" "$MOD_LIST" > "${MOD_LIST}.tmp" && mv "${MOD_LIST}.tmp" "$MOD_LIST"
    else
        jq ".mods += [{\"name\": \"$mod_name\", \"enabled\": $enabled}]" "$MOD_LIST" > "${MOD_LIST}.tmp" && mv "${MOD_LIST}.tmp" "$MOD_LIST"
    fi
}

# 5.1 Descarga de mods desde download-list.txt
if [ -f "$DOWNLOAD_LIST" ]; then
    echo "--- [MODS] Procesando lista de descargas ---"
    while IFS= read -r link || [ -n "$link" ]; do
        [[ "$link" =~ ^#.* ]] || [ -z "$link" ] && continue
        filename=$(basename "$link")
        
        if [ ! -f "${MODS_DIR}/$filename" ] || [ "${MODS_AUTO_UPDATE,,}" = "true" ]; then
            echo "  > Descargando/Actualizando: $filename"
            wget -q -O "${MODS_DIR}/$filename" "$link"
        fi
    done < "$DOWNLOAD_LIST"
fi

# 5.2 Auto-activación de nuevos mods .zip
echo "--- [MODS] Sincronizando carpeta de mods con mod-list.json ---"
for mod_zip in "${MODS_DIR}"/*.zip; do
    [ -e "$mod_zip" ] || continue
    internal_name=$(unzip -p "$mod_zip" "*/info.json" | jq -r '.name' 2>/dev/null)
    if [ -n "$internal_name" ] && [ "$internal_name" != "null" ]; then
        update_mod_status "$internal_name" "true"
    fi
done

# 5.3 Auto-actualización desde el Portal de Factorio
if [ "${MODS_AUTO_UPDATE,,}" = "true" ]; then
    echo "--- [MODS] Buscando actualizaciones en el portal oficial ---"
    if [ -z "$FACTORIO_USER" ] || [ -z "$FACTORIO_TOKEN" ]; then
        echo "  ! Error: FACTORIO_USER y FACTORIO_TOKEN son obligatorios para actualizar."
    else
        # Obtener lista de mods habilitados (excluyendo core/dlc)
        mods_to_check=$(jq -r '.mods[] | select(.enabled == true) | .name' "$MOD_LIST" | grep -vE "^(base|quality|elevated-rails|space-age)$" || true)
        
        for mod in $mods_to_check; do
            echo "  > Comprobando $mod..."
            mod_info=$(curl -s "https://mods.factorio.com/api/mods/$mod/full")
            # Obtener última versión compatible con Factorio 2.0
            latest_release=$(echo "$mod_info" | jq -r '.releases | map(select(.info_json.factorio_version | startswith("2.0"))) | last')
            
            if [ "$latest_release" != "null" ]; then
                latest_ver=$(echo "$latest_release" | jq -r '.version')
                download_url=$(echo "$latest_release" | jq -r '.download_url')
                
                # Buscar versión local actual
                current_zip=$(ls "${MODS_DIR}/${mod}"_*.zip 2>/dev/null | head -n 1)
                current_ver="0.0.0"
                [ -n "$current_zip" ] && current_ver=$(basename "$current_zip" | sed -E "s/^${mod}_(.*)\.zip$/\1/")

                if [ "$latest_ver" != "$current_ver" ]; then
                    echo "    [ACTUALIZANDO] $current_ver -> $latest_ver"
                    full_url="https://mods.factorio.com${download_url}?username=${FACTORIO_USER}&token=${FACTORIO_TOKEN}"
                    if wget -q -O "${MODS_DIR}/${mod}_${latest_ver}.zip" "$full_url"; then
                        [ -n "$current_zip" ] && [ "${MODS_DIR}/${mod}_${latest_ver}.zip" != "$current_zip" ] && rm "$current_zip"
                    else
                        echo "    ! Error al descargar $mod"
                    fi
                fi
            fi
        done
    fi
fi

# 5.3 Lógica de dependencias DLC
if [ "${DLC_SPACE_AGE,,}" = "true" ]; then
    echo "--- [MODS] Space Age activo: Forzando dependencias ---"
    DLC_QUALITY="true"
    DLC_ELEVATED_RAILS="true"
fi

[ -n "$DLC_ELEVATED_RAILS" ] && update_mod_status "elevated-rails" "${DLC_ELEVATED_RAILS,,}"
[ -n "$DLC_QUALITY" ]        && update_mod_status "quality"        "${DLC_QUALITY,,}"
[ -n "$DLC_SPACE_AGE" ]      && update_mod_status "space-age"       "${DLC_SPACE_AGE,,}"

# --- 6. GESTIÓN DE MAPA ---
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