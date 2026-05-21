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

### Space Age DLC (Factorio 2.0+)

The expansion is managed as a set of internal mods. You can toggle them using:

| Variable | Mod Name | Description |
|----------|----------|-------------|
| `DLC_SPACE_AGE` | `space-age` | Main expansion content. |
| `DLC_QUALITY` | `quality` | Adds quality tiers to items/machines. |
| `DLC_ELEVATED_RAILS` | `elevated-rails` | Adds ramps and multi-level rails. |

**Important Logic:**
- **Standalone:** You can enable `DLC_QUALITY` or `DLC_ELEVATED_RAILS` independently without the full expansion.
- **Dependencies:** If `DLC_SPACE_AGE` is set to `true`, the system will **automatically enable** both `quality` and `elevated-rails` regardless of their individual variables, as they are required for the expansion to run.

---

## Mod Management

For maximum flexibility, mods are handled through the `/factorio/mods` volume.

### 1. Manual Install
Just drop your `.zip` mod files into the `./data/mods` folder on your host. The server will automatically detect them, extract their internal names, and enable them in `mod-list.json` on the next boot.

### 2. Automated Downloads (`download-list.txt`)
Create a file named `download-list.txt` inside your mods volume with one URL per line:
```text
https://github.com/user/mod1/releases/download/v1.0/mod1_1.0.0.zip
https://example.com/mods/my-cool-mod.zip
```
The server will download these files automatically if they don't exist.

### 3. Auto-Updates (Official Portal)
To keep your mods up to date automatically from the [Factorio Mod Portal](https://mods.factorio.com/):

1.  Set `MODS_AUTO_UPDATE=true`.
2.  Provide your Factorio credentials via `FACTORIO_USER` and `FACTORIO_TOKEN` (get your token from your [Factorio profile settings](https://www.factorio.com/profile)).
3.  On every boot, the server will:
    *   Check all enabled mods in `mod-list.json`.
    *   Query the official API for the latest version compatible with Factorio 2.0.
    *   Download the new `.zip` and **delete the old version** automatically.

### 4. Activation Control
- New mods are **enabled by default**.
- Use the **DLC Environment Variables** (see above) for quick toggling of official expansion content.
- For granular control, manually edit the `mod-list.json` file inside the volume.

---

## Port Configuration & Remapping

By default, Factorio uses port `34197/udp`. You can change this in two ways:

### Option A: External Remapping (Recommended)
Change only the host port in your `docker-compose.yml`. The game remains on the default port internally, and Docker handles the redirection.

```yaml
ports:
  - "5000:34197/udp" # You connect via port 5000
```
- **Use when:** You simply want to avoid port conflicts on your host machine.

### Option B: Internal & External Change
Change the `PORT` environment variable and match it in the ports mapping.

```yaml
environment:
  - PORT=5000
ports:
  - "5000:5000/udp"
```
- **Use when:** You are using `network_mode: host`, you want the internal logs to reflect the custom port, or you want the server to be correctly indexed in the public server list with that specific port.

---

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