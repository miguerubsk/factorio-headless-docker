# Factorio Headless Docker

A lightweight, flexible, and fully configurable Factorio Headless Server containerized with Docker. Optimized for performance and ease of use.

## Features

- **Multi-stage build**: Optimized image size using Debian Bookworm Slim.
- **Dynamic Configuration**: Inject any setting into `server-settings.json` via environment variables.
- **Auto-generation**: Automatically creates a new map if no save file is found.
- **RCON Support**: Built-in RCON management for remote administration.
- **Persistence**: Easy volume mapping for saves, mods, and configuration files.
- **Customizable**: Supports custom map generation and game settings.

## Quick Start

The easiest way to run the server is using Docker Compose.

1. **Clone the repository:**
   ```bash
   git clone https://github.com/miguerubsk/factorio-headless-docker.git
   cd factorio-headless-docker
   ```

2. **Start the server:**
   ```bash
   docker compose up -d
   ```

The server will be available on UDP port `34197`.

## Configuration

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `SAVE_NAME` | Name of the save file to create/load | `factory_world` |
| `PORT` | Game port (UDP) | `34197` |
| `RCON_ENABLED` | Enable RCON | `false` |
| `RCON_PORT` | RCON port (TCP) | `27015` |
| `RCON_PASSWORD` | RCON password | `factorio_default_pass` |

### Dynamic JSON Injection (Advanced)

You can override any property in `server-settings.json` by prefixing environment variables with `FACTORIO_CONF__`. Use `__` to represent nested paths.

**Example:**
- `FACTORIO_CONF__name="My Docker Server"` &rarr; Sets `.name` to `"My Docker Server"`
- `FACTORIO_CONF__visibility__public=true` &rarr; Sets `.visibility.public` to `true`
- `FACTORIO_CONF__tags='["docker", "game"]'` &rarr; Sets `.tags` to `["docker", "game"]`

### Custom Map Settings

Place your custom JSON files in the mapped `config` volume:
- `map-gen-settings.json`
- `map-settings.json`

The entrypoint script will automatically detect and use them when generating a new world.

## Volumes & Persistence

To ensure your progress is saved, the following paths should be mapped to your host machine:

- `/factorio/saves`: World save files (`.zip`).
- `/factorio/mods`: Game modifications.
- `/factorio/config`: Configuration files (`server-settings.json`, etc.).

In the default `compose.yml`, these are mapped to `./factorio_data/`.

## Building the Image

To build the image locally with a specific Factorio version:

```bash
docker build --build-arg FACTORIO_VERSION=1.1.110 -t factorio-headless:latest .
```

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
