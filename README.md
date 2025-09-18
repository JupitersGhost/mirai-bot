# Mirai Discord Bot

<div align="center">
  <img src="assets/miraicropped.png" alt="Chisato Mirai" width="200" height="200" style="border-radius: 50%;">
  
  **Mirai - CHIRASU Network Gateway and Defense**
</div>

---

Mirai-bot is a Discord presence and monitoring bot named Chisato Mirai, a kuudere-styled network defense operative in the CHIRASU collective. In lore, Mirai is cold, calculating, and relentlessly protective of CHIRASU's digital borders—embodying the role of an encrypted gateway and watchful sentinel.

The bot itself currently runs on a Libre Computer Renegade (ROC-RK3328, 4GB) with Armbian, where it has been tested as a reliable way to display device presence through Discord. While the script is lightweight and does not yet use AI, it’s designed to be extended—future updates may integrate models via Ollama, llama.cpp, or similar inference backends to give Mirai her full analytical personality.

## Features

- `/ping` - Quick reachability check
- `/health` - Bot health status (ephemeral)
- `/status` - Operational status (ephemeral) 
- `/hello random` - Random greeting from Mirai
- `/hello list` - List all available greetings
- `/admin sync` - Admin-only command to prune stale commands and re-register the current set
- Resilient startup with exponential backoff and safe command registration
- Health server auto-falls forward to the next available port if 8788 is in use
- Rotating status activities every 15 minutes
- Health check endpoint at `/healthz`

## Setup

1. Clone this repository
   ```bash
   git clone https://github.com/jupitersghost/mirai-bot.git
<<<<<<< HEAD
   cd mirai-bot
=======
   cd mirai-discord-bot
>>>>>>> b4f8ad3 (Local updates: main.go, README.md, example.env, go.mod)
   ```
2. Copy `.env.example` to `.env` and fill in your Discord bot credentials
   ```bash
   cp .env.example .env
   nano .env
   ```
3. Install Go dependencies: 
   ```bash
   go mod tidy
   ```
4. Build: 
   ```bash
   go build -o mirai-bot main.go
   ```
5. Run: 
   ```bash
   ./mirai-bot
   ```

## Discord Bot Setup

1. Create a Discord application at https://discord.com/developers/applications
2. Create a bot and get the token
3. Get the Application ID from General Information
4. **Set the bot's avatar**: Upload `assets/miraicropped.png` in the Bot tab
5. Invite the bot to your server with appropriate permissions

## Configuration

Create a `.env` file with:
```env
# Discord Bot Configuration
DISCORD_TOKEN=your_bot_token_here
APP_ID=your_application_id_here
GUILD_ID=your_guild_id_here
HEALTH_ADDR=127.0.0.1:8788
ADMIN_USER_ID=your_discord_user_id_here

```

### Getting Your Discord Credentials:

1. **DISCORD_TOKEN**: Go to your Discord application → Bot tab → Click "Reset Token" to generate a new one
2. **APP_ID**: Go to your Discord application → General Information → Copy "Application ID"
3. **GUILD_ID**: Right-click your Discord server icon → "Copy Server ID" (requires Developer Mode enabled)
4. **HEALTH_ADDR**: Health check endpoint address (127.0.0.1:8788 is default)

## Health Check Endpoint

The bot provides a health check endpoint for monitoring:

- **Default**: `http://127.0.0.1:8788/healthz`
- **Purpose**: Check if the bot is running and get status information
- **Usage**: `curl http://127.0.0.1:8788/healthz`

### Health Check Response:
```json
{
  "name": "Mirai (Go Bot)",
  "ready": true,
  "uptime_secs": 3600,
  "last_http_ok_unix_ms": 1694975234567,
  "version": "0.1.0",
  "quips_available": 55
}
```

### HEALTH_ADDR Options:
- `127.0.0.1:8788` - Local access only (recommended)
- `0.0.0.0:8788` - Network accessible (for external monitoring)
- `localhost:8080` - Different port if needed

## Running as a Service (Linux)

For production deployment, you can run Mirai as a systemd service on Linux systems:

### 1. Create the service directory and copy files:
```bash
# Create service directory
sudo mkdir -p /home/mirai/apps/mirai-bot

# Copy your bot files (adjust paths as needed)
sudo cp mirai-bot .env /home/mirai/apps/mirai-bot/

# Set proper ownership (replace 'mirai' with your username)
sudo chown -R mirai:mirai /home/mirai/apps/mirai-bot
```

### 2. Create the systemd service file:
```bash
sudo nano /etc/systemd/system/mirai-bot.service
```

Add this content (see `systemd/mirai-bot.service` for the complete file):
```ini
[Unit]
Description=Mirai Discord Bot
After=network.target
Wants=network-online.target

[Service]
Type=simple
User=mirai
Group=mirai
WorkingDirectory=/home/mirai/apps/mirai-bot
ExecStart=/home/mirai/apps/mirai-bot/mirai-bot
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal
SyslogIdentifier=mirai-bot

# Security settings
NoNewPrivileges=yes
PrivateTmp=yes
ProtectSystem=strict
ProtectHome=read-only
ReadWritePaths=/home/mirai/apps/mirai-bot

[Install]
WantedBy=multi-user.target
```

### 3. Enable and start the service:
```bash
# Reload systemd to recognize the new service
sudo systemctl daemon-reload

# Enable the service to start at boot
sudo systemctl enable mirai-bot

# Start the service
sudo systemctl start mirai-bot

# Check the status
sudo systemctl status mirai-bot
```

### 4. Service management commands:
```bash
# Start the service
sudo systemctl start mirai-bot

# Stop the service
sudo systemctl stop mirai-bot

# Restart the service (useful after rebuilding)
sudo systemctl restart mirai-bot

# Check status
sudo systemctl status mirai-bot

# View logs
sudo journalctl -u mirai-bot -f
```

## Bot Permissions

Your Discord bot needs the following permissions:
- Read Messages/View Channels
- Send Messages
- Use Slash Commands
- Embed Links (for health/status commands)

## Personality & Status Activities

Mirai rotates through various network-themed status activities every 15 minutes, reflecting her technical personality:

- **Watching**: signals, packet flows, network traffic, system logs
- **Playing**: keepalive tag, packet chess, network tag
- **Listening to**: network symphonies, server heartbeats, packet whispers
- **Custom**: network maintenance, system monitoring, security patrol

## Admin Sync

Mirai includes an **admin-only** slash command `/admin sync`.  
This safely removes any stale slash commands (such as legacy `/quips`) and re-registers the current command set.

- Only the Discord user ID specified in `ADMIN_USER_ID` within `.env` can run this command.  
- Use `/admin sync` whenever you:
  - Add, rename, or remove commands
  - Switch between **guild** (`GUILD_ID` set) and **global** (no `GUILD_ID`) scope

**Scope notes**:  
- **Guild scope** (with `GUILD_ID`): changes are nearly instant.  
- **Global scope** (no `GUILD_ID`): changes may take several minutes due to Discord caching.  
- If you previously created global commands and now want guild-only, you may need to temporarily unset `GUILD_ID`, restart, run `/admin sync` to prune globals, then restore `GUILD_ID`.

## Troubleshooting

- **Unknown interaction (10062)**:  
  Discord requires commands to be acknowledged within ~3 seconds. `/admin sync` now defers immediately, then sends a follow-up response. If this error persists:
  - Ensure only **one** Mirai instance is running (managed by systemd).
  - Re-run `/admin sync` after confirming the bot is connected.

- **Health port already in use**:  
  If `HEALTH_ADDR` is busy, Mirai automatically increments to the next available port (up to +20) and logs the chosen URL.

- **Commands not updating**:  
  - Run `/admin sync` to prune and refresh.
  - Check whether you are using guild vs global scope (see Admin Sync notes above).

## System Requirements

- Go 1.19 or higher
- Linux/ARM64 (tested on Armbian)
- Network connectivity
- Discord bot token and permissions

## Tested Hardware

- Libre Computer Renegade 4GB SBC (ROC-RK3328)
- Armbian OS
- Runs alongside Pi-hole and Unbound DNS

## License

MIT License

This project uses the [DiscordGo](https://github.com/bwmarrin/discordgo) library, which is licensed under the BSD 3-Clause License.

## Character & Art

Chisato Mirai is an original character created by the repository owner. The character design and artwork are created using Google's Gemini AI, based on a description of the character's appearance created by the repository owner.

## Contributing

Feel free to submit issues and pull requests to improve Mirai's functionality!
