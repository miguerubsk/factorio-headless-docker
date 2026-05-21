# Factorio Headless Server 🚀

A lightweight, secure, and highly configurable Factorio Headless Server. Designed for stability, automatic management, and full Factorio 2.0 / Space Age support.

## ✨ Key Features

- **🛡️ Security First**: Runs as a non-root user (`factorio`, UID/GID 845).
- **📦 Multi-stage Build**: Minimal image size based on Debian Bookworm Slim.
- **💉 Triple Injector**: Dynamic configuration of `server-settings`, `map-gen`, and `map-settings` via environment variables.
- **🔄 Auto-Updates**: Built-in watchdog for automatic game and mod updates.
- **🛸 DLC Support**: Native support for Factorio 2.0, Space Age, Quality, and Elevated Rails.
- **📦 Mod Manager**: Automated mod downloads and dependency handling.

---

## 🚀 Quick Start

### Basic Run
```bash
docker run -d \
  --name factorio-server \
  -p 34197:34197/udp \
  -p 27015:27015/tcp \
  -v /path/to/data:/factorio \
  miguerubsk/factorio-headless:latest
```

### Docker Compose
```yaml
services:
  factorio:
    image: miguerubsk/factorio-headless:latest
    container_name: factorio_server
    ports:
      - "34197:34197/udp"
      - "27015:27015/tcp"
    environment:
      - SAVE_NAME=my_factory
      - RCON_ENABLED=true
      - RCON_PASSWORD=your_password
    volumes:
      - ./data:/factorio
    restart: unless-stopped
```

---

## ⚙️ Configuration

### Core Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `SAVE_NAME` | Name of the save file | `factory_world` |
| `RCON_ENABLED` | Enable RCON administration | `false` |
| `DLC_SPACE_AGE` | Enable Space Age DLC (v2.0+) | `false` |
| `GAME_AUTO_UPDATE` | Enable automatic updates | `false` |

### 🧠 Dynamic JSON Injection
Override any setting using prefixes:
- `FACTORIO_CONF__` &rarr; `server-settings.json`
- `MAP_GEN__` &rarr; `map-gen-settings.json`
- `MAP_SET__` &rarr; `map-settings.json`

**Example:** `FACTORIO_CONF__name="My Super Server"`

---

## 📁 Persistence

Mount a volume to `/factorio` to persist your data. The internal structure is:
- `/factorio/saves`: Game world files.
- `/factorio/mods`: Installed mods.
- `/factorio/config`: Configuration and JSON settings.

---

## 📄 License
MIT License. Created by [Miguerubsk](https://github.com/miguerubsk).
