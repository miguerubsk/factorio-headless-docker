# Factorio Headless Docker 🚀

A lightweight, secure, and fully autonomous Factorio Headless Server. Optimized for Factorio 2.0+ and Space Age DLC.

## Features

- **Autonomous**: Self-updating game binary and mods without container restarts.
- **Factorio 2.0+ Ready**: Full support for Space Age, Quality, and Elevated Rails DLCs.
- **Smart Mod Manager**: Automatic downloads from the Official Portal, version checking, and auto-activation.
- **Triple Injector**: Configure any game setting via environment variables.
- **Secure**: Runs as a non-root user (`factorio`, UID 845).
- **Healthchecked**: Built-in monitoring for service reliability.

---

## Configuration

### Basic Variables
| Variable | Description | Default |
|----------|-------------|---------|
| `SAVE_NAME` | Name of the save file | `factory_world` |
| `PORT` | Internal game port (UDP) | `34197` |
| `RCON_ENABLED` | Enable RCON support | `false` |
| `RCON_PORT` | RCON port (TCP) | `27015` |
| `RCON_PASSWORD` | RCON password | `factorio_pass` |

### Space Age DLC (Factorio 2.0+)
| Variable | Mod Name | Description |
|----------|----------|-------------|
| `DLC_SPACE_AGE` | `space-age` | Main expansion content. |
| `DLC_QUALITY` | `quality` | Adds quality tiers. |
| `DLC_ELEVATED_RAILS` | `elevated-rails` | Adds ramps and multi-level rails. |

> [!NOTE]
> DLC features require **Factorio 2.0.0** or higher. If a lower version is detected, these variables will be ignored to prevent configuration errors.

*Note: Enabling `DLC_SPACE_AGE` automatically forces `DLC_QUALITY` and `DLC_ELEVATED_RAILS` to `true`.*

---

## Automated Updates & Maintenance

The container features an internal watchdog that manages updates without killing the container itself.

### Game & Mod Updates
| Variable | Default | Description |
|----------|---------|-------------|
| `GAME_AUTO_UPDATE` | `false` | Enable automatic binary updates from factorio.com. |
| `MODS_AUTO_UPDATE` | `false` | Enable automatic mod updates from the Official Portal. |
| `GAME_UPDATE_SCHEDULE` | `04:00` | Schedule for game restart/update. |
| `MODS_UPDATE_SCHEDULE` | `04:00` | Schedule for mod update check. |
| `FACTORIO_USER` | (empty) | Your Factorio.com username (required for mods). |
| `FACTORIO_TOKEN` | (empty) | Your Service Token (required for mods). |

**Supported Schedules:**
- **Simple (HH:MM):** `04:00`, `23:30`.
- **Advanced (Cron):** `0 4 * * 1` (Every Monday at 4:00 AM).

**Smart Restart Logic:** At the scheduled time, the watchdog **first checks** for updates. 
- If a new game version or mod update is found, the server saves and restarts internally to apply them.
- If **no updates** are found, the server **remains online** to avoid unnecessary downtime for players.

---

## Mod Management

The volume `/factorio/mods` is used for all mod storage.

1.  **Manual**: Drop `.zip` files into the folder. They will be auto-activated on boot.
2.  **Portal**: Enabled mods are automatically checked for updates if `MODS_AUTO_UPDATE` is active.
3.  **Automatic Cleanup**: When a mod is updated, the old version is automatically deleted to prevent conflicts.

---

## Port Configuration & Remapping

### Option A: External Remapping (Recommended)
Change only the host port. The game remains on 34197 internally.
```yaml
ports:
  - "5000:34197/udp" # You connect via port 5000
```

### Option B: Internal & External Change
Use when using `network_mode: host` or for public server indexing.
```yaml
environment:
  - PORT=5000
ports:
  - "5000:5000/udp"
```

---

## Technical Details

### Healthcheck
The container monitors the Factorio process every minute.
- **Interval**: 1m
- **Retries**: 3
- **Action**: Check if `factorio` process is running.

### Persistence
Map these directories to keep your data:
- `/factorio/saves`: World files.
- `/factorio/mods`: Mods and `mod-list.json`.
- `/factorio/config`: Server settings and configs.

## License
MIT License.
