# Factorio Headless Docker 🚀

A lightweight, secure, and fully configurable Factorio Headless Server containerized with Docker. Optimized for both quick deployment and advanced server management.

## ✨ Features

- **🛡️ Secure**: Runs as a non-root user (`factorio`, UID 845).
- **📦 Multi-stage build**: Minimal final image size based on Debian Bookworm Slim with all necessary dependencies (`libglib2.0-0`, etc.).
- **💉 Triple Injector System**: Inject any setting into `server-settings.json`, `map-gen-settings.json`, or `map-settings.json` via environment variables.
- **🗺️ Auto-generation**: Automatically creates a new world with your custom settings if no save file is found.
- **🔌 RCON Ready**: Built-in support for remote administration.
- **💾 Persistence**: Clean volume mapping for saves, mods, and configs.
- **🔄 Auto-Updates**: Can automatically update the game and mods on a schedule.
- **🛸 DLC Support**: Ready for Factorio 2.0 and Space Age DLC.
- **📦 Mod Manager**: Automatically downloads missing mods and keeps them updated.

---

## 🚀 Quick Start

### 1. Zero Complications (Recommended)
If you just want a server running with default settings:

```bash
docker run -d \
  --name factorio-server \
  -p 34197:34197/udp \
  -p 27015:27015/tcp \
  -v $(pwd)/data:/factorio \
  miguerubsk/factorio-headless:latest
```

### 2. Using Docker Compose
Clone the repository and choose your path:

#### **A. Standard (Fastest)**
Uses the pre-built image from Docker Hub.
```bash
docker compose up -d
```

#### **B. Advanced (Custom Build)**
Builds the image locally (useful for different architectures or custom versions).
```bash
docker compose -f compose-build.yml up --build -d
```

---

## ⚙️ Configuration

### Basic Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `SAVE_NAME` | Name of the save file to create/load | `factory_world` |
| `PORT` | Game port (UDP) | `34197` |
| `RCON_ENABLED` | Enable RCON support | `false` |
| `RCON_PORT` | RCON port (TCP) | `27015` |
| `RCON_PASSWORD` | RCON password | `factorio_pass` |

### 🔄 Auto-Updates & Watchdog

| Variable | Description | Default |
|----------|-------------|---------|
| `GAME_AUTO_UPDATE` | Enable automatic game updates | `false` |
| `MODS_AUTO_UPDATE` | Enable automatic mod updates | `false` |
| `GAME_UPDATE_SCHEDULE`| Cron expression or HH:MM for updates | `04:00` |

### 🛸 Factorio 2.0 / Space Age DLC

| Variable | Description | Default |
|----------|-------------|---------|
| `DLC_SPACE_AGE` | Enable Space Age DLC (v2.0+) | `false` |
| `DLC_QUALITY` | Enable Quality DLC | `false` |
| `DLC_ELEVATED_RAILS` | Enable Elevated Rails DLC | `false` |

### 🧠 The "Triple Injector" (Dynamic JSON)

You can override **any** property in the configuration files by using specific prefixes:

- `FACTORIO_CONF__` &rarr; Targets `server-settings.json`
- `MAP_GEN__` &rarr; Targets `map-gen-settings.json`
- `MAP_SET__` &rarr; Targets `map-settings.json`

**Examples:**
- `FACTORIO_CONF__name="My Server"` sets the server name.
- `MAP_SET__pollution__enabled=false` disables pollution.
- `FACTORIO_CONF__visibility__public=true` enables public listing (requires `FACTORIO_USER` and `FACTORIO_TOKEN`).

> [!IMPORTANT]
> **Credential Auto-Injection**: `FACTORIO_USER` and `FACTORIO_TOKEN` are automatically injected into your `server-settings.json`. If these variables are missing, the server will **force** `visibility.public=false` to prevent crashes.

### 📦 Mod Management

1.  **Credentials**: Set `FACTORIO_USER` and `FACTORIO_TOKEN` (required for downloads).
2.  **Mod List**:
    *   Set `MODS_LIST` (comma-separated list of mod names **or full Portal URLs**).
    *   OR place a `mods.txt` in your `config` volume (one name or URL per line).

**Example `MODS_LIST`:**
`MODS_LIST=FNEI, https://mods.factorio.com/mod/Space-Age-Optimization`

3.  **Auto-Enable**: The server automatically downloads missing mods, enables them, and keeps them updated.

---

## 📁 Persistence

All data is stored in the `/factorio` directory inside the container. To keep your progress, map these subdirectories:

- `./data/saves`: Your world `.zip` files.
- `./data/mods`: Installed mods.
- `./data/config`: Generated JSON settings.

---

## 📄 License
MIT License. See [LICENSE](LICENSE) for details.
