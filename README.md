# Factorio Headless Docker 🚀

A lightweight, secure, and fully configurable Factorio Headless Server containerized with Docker. Optimized for both quick deployment and advanced server management.

## Features

- **Secure**: Runs as a non-root user (`factorio`, UID 845).
- **Multi-stage build**: Minimal final image size based on Debian Bookworm Slim.
- **Triple Injector System**: Inject any setting into `server-settings.json`, `map-gen-settings.json`, or `map-settings.json` via environment variables.
- **Auto-generation**: Automatically creates a new world with your custom settings if no save file is found.
- **RCON Ready**: Built-in support for remote administration.
- **Persistence**: Clean volume mapping for saves, mods, and configs.

---

## Quick Start

### 1. Zero Complications (Recommended)
If you just want a server running with default settings:

```bash
docker run -d \
  --name factorio-server \
  -p 34197:34197/udp \
  -p 27015:27015/tcp \
  -v $(pwd)/data:/factorio \
  miguerubsk/factorio-headless:1.1.110
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

## Configuration

### Basic Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `SAVE_NAME` | Name of the save file to create/load | `factory_world` |
| `PORT` | Game port (UDP) | `34197` |
| `RCON_ENABLED` | Enable RCON support | `false` |
| `RCON_PORT` | RCON port (TCP) | `27015` |
| `RCON_PASSWORD` | RCON password | `factorio_pass` |

### The "Triple Injector" (Dynamic JSON)

You can override **any** property in the configuration files by using specific prefixes:

- `FACTORIO_CONF__` &rarr; Targets `server-settings.json`
- `MAP_GEN__` &rarr; Targets `map-gen-settings.json`
- `MAP_SET__` &rarr; Targets `map-settings.json`

Use `__` (double underscore) for nested JSON properties.

**Examples:**
- `FACTORIO_CONF__name="My Server"` sets the server name.
- `MAP_GEN__water=high` sets water frequency.
- `MAP_SET__pollution__enabled=false` disables pollution.
- `FACTORIO_CONF__tags='["docker", "hardcore"]'` (JSON arrays are supported).

---

## Persistence

All data is stored in the `/factorio` directory inside the container. To keep your progress, map these subdirectories:

- `./data/saves`: Your world `.zip` files.
- `./data/mods`: Installed mods.
- `./data/config`: Generated JSON settings (will be auto-filled on first run).

---

## Local Development

To build the image manually:
```bash
docker build --build-arg FACTORIO_VERSION=1.1.110 -t factorio-headless:local .
```

## License
MIT License. See [LICENSE](LICENSE) for details.