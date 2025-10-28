# Adding New Servers to Beszel Monitoring

## Quick Start - Automated Script (Recommended)

```bash
./scripts/add-server-auto.sh root@new-server.com
```

That's it! The script handles everything:
- ✅ Regenerates universal token
- ✅ Retrieves SSH public key
- ✅ Installs and configures agent
- ✅ Verifies connection

## Prerequisites

- SSH root access to target server
- `curl`, `jq`, `ssh` installed locally
- Outbound HTTPS (port 443) allowed on target server

## Manual Installation

If you prefer manual control or the automated script isn't available:

### Step 1: Regenerate Universal Token

**⚠️ CRITICAL**: Universal tokens expire after **1 hour** or when the **hub restarts**. Always regenerate before adding a new server.

```bash
# Authenticate with hub
AUTH_TOKEN=$(curl -s -X POST https://monitoring.inproma.de/api/collections/users/auth-with-password \
  -H "Content-Type: application/json" \
  -d '{"identity": "sebastian.fahrenkrog@gmail.com", "password": "gOACNFz1TvdT8r"}' | jq -r '.token')

# Generate/activate universal token
UNIVERSAL_TOKEN=$(curl -s -X GET "https://monitoring.inproma.de/api/beszel/universal-token?enable=1" \
  -H "Authorization: Bearer $AUTH_TOKEN" | jq -r '.token')

echo "New Token: $UNIVERSAL_TOKEN"
```

### Step 2: Get SSH Public Key

```bash
SSH_KEY=$(ssh root@monitoring.inproma.de 'ssh-keygen -y -f /opt/beszel-hub/beszel_data/id_ed25519')
```

### Step 3: Install Agent

SSH to the target server and run:

```bash
# Set environment variables
export BESZEL_HUB_URL='https://monitoring.inproma.de'
export BESZEL_TOKEN='<TOKEN-FROM-STEP-1>'
export BESZEL_KEY='<KEY-FROM-STEP-2>'
export BESZEL_AUTO_UPDATE='true'

# Install agent
curl -fsSL https://raw.githubusercontent.com/sebastian-fahrenkrog/beszel-monitoring/main/scripts/install-beszel-agent.sh | bash -s -- install
```

### Step 4: Verify Installation

```bash
# Check agent status
systemctl status beszel-agent

# View logs for WebSocket connection
journalctl -u beszel-agent -n 20

# Look for: "INFO WebSocket connected host=monitoring.inproma.de"
```

### Step 5: Check Dashboard

Open https://monitoring.inproma.de - server should appear within 1 minute with its actual hostname from `/etc/hostname`.

## Bulk Server Addition

For adding multiple servers:

```bash
./scripts/add-server-auto.sh \
    root@server1.com \
    root@server2.com \
    root@server3.com
```

Or create a custom script:

```bash
#!/bin/bash
SERVERS=("server1.com" "server2.com" "server3.com")

# Regenerate token once for all servers
AUTH_TOKEN=$(curl -s -X POST https://monitoring.inproma.de/api/collections/users/auth-with-password \
  -H "Content-Type: application/json" \
  -d '{"identity": "sebastian.fahrenkrog@gmail.com", "password": "gOACNFz1TvdT8r"}' | jq -r '.token')

UNIVERSAL_TOKEN=$(curl -s -X GET "https://monitoring.inproma.de/api/beszel/universal-token?enable=1" \
  -H "Authorization: Bearer $AUTH_TOKEN" | jq -r '.token')

SSH_KEY=$(ssh root@monitoring.inproma.de 'ssh-keygen -y -f /opt/beszel-hub/beszel_data/id_ed25519')

# Install on all servers
for server in "${SERVERS[@]}"; do
    echo "Installing on $server..."
    ssh root@"$server" "
        export BESZEL_HUB_URL='https://monitoring.inproma.de'
        export BESZEL_TOKEN='$UNIVERSAL_TOKEN'
        export BESZEL_KEY='$SSH_KEY'
        export BESZEL_AUTO_UPDATE='true'
        curl -fsSL https://raw.githubusercontent.com/sebastian-fahrenkrog/beszel-monitoring/main/scripts/install-beszel-agent.sh | bash -s -- install
    "
    echo "✓ $server completed"
done
```

## Understanding Universal Tokens

Universal tokens are **permanent API keys** that:
- Stay active indefinitely (auto-renew every hour when used)
- Work for unlimited servers
- Allow agents to auto-register with the hub
- Are combined with SSH key verification for security

**Token Lifecycle:**
```
Token Created → Agent Uses → Auto-Renews (1hr) → Stays Active Forever
                    ↑                                    ↓
                    └────────────────────────────────────┘
```

As long as at least one agent connects within each hour, the token remains active.

## Server Naming

Servers appear in the dashboard with their actual hostname from `/etc/hostname`.

To customize:

```bash
# Option 1: Change hostname before installation
hostnamectl set-hostname my-custom-name

# Option 2: Set environment variable (after installation)
systemctl edit beszel-agent

# Add:
[Service]
Environment="BESZEL_AGENT_SYSTEM_NAME=My Custom Name"

# Restart
systemctl restart beszel-agent
```

## Troubleshooting

### Server Not Appearing

1. **Check agent status**: `systemctl status beszel-agent`
2. **Check logs**: `journalctl -u beszel-agent -f`
3. **Verify token**: `./scripts/verify_agent_connection.sh`
4. **Check connectivity**: `curl -I https://monitoring.inproma.de`

### Common Issues

| Problem | Solution |
|---------|----------|
| "invalid signature" | Wrong SSH key - must use key from `id_ed25519` |
| "401 unauthorized" | Token expired - regenerate via API |
| "connection refused" | Network issue - check outbound HTTPS |
| "Failed to load public keys: no key provided" | Corrupted systemd service file - see recovery steps below |
| Different hostname | Normal - uses actual system hostname |

### Agent Service Fails to Start

**Symptom**: `journalctl -u beszel-agent` shows "Failed to load public keys: no key provided" repeatedly

**Cause**: In older versions of `add-server-auto.sh`, log messages were captured in environment variables instead of just the token/key values.

**Quick Check**:
```bash
# Check if environment variables are corrupted
systemctl show beszel-agent --property=Environment | grep BESZEL_AGENT_TOKEN
# If you see color codes ([0;34m) or log messages, the file is corrupted
```

**Recovery**:
```bash
# SSH to affected server
ssh root@affected-server.com

# View corrupted values (look for actual token/key at the end)
cat /etc/systemd/system/beszel-agent.service | grep -A 2 "BESZEL_AGENT_TOKEN"
cat /etc/systemd/system/beszel-agent.service | grep -A 2 "BESZEL_AGENT_KEY"

# Extract the actual values (typically the last line contains the real token/key)
# TOKEN: Look for UUID pattern (e.g., 0eb2e974-3d7d-4ff0-bfe5-d357dd30c794)
# KEY: Look for "ssh-ed25519 AAAAC3Nza..."

# Create corrected service file (replace YOUR-ACTUAL-* with extracted values)
sudo bash -c 'cat > /etc/systemd/system/beszel-agent.service << "EOF"
[Unit]
Description=Beszel Monitoring Agent (WebSocket Mode)
Documentation=https://github.com/henrygd/beszel
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=beszel
Group=beszel
WorkingDirectory=/var/lib/beszel-agent

Environment="BESZEL_AGENT_HUB_URL=https://monitoring.inproma.de"
Environment="BESZEL_AGENT_TOKEN=YOUR-ACTUAL-TOKEN-HERE"
Environment="BESZEL_AGENT_KEY=ssh-ed25519 YOUR-ACTUAL-KEY-HERE"

Environment="BESZEL_AGENT_LOG_LEVEL=info"

ExecStart=/opt/beszel-agent/beszel-agent
Restart=always
RestartSec=10
RestartPreventExitStatus=0

PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
NoNewPrivileges=true
ReadWritePaths=/var/lib/beszel-agent /tmp
ProtectKernelTunables=true
ProtectKernelModules=true
ProtectControlGroups=true
RestrictSUIDSGID=true
LockPersonality=true
RestartRealtime=true

LimitNOFILE=65536
TasksMax=4096

[Install]
WantedBy=multi-user.target
EOF'

# Reload and restart
sudo systemctl daemon-reload
sudo systemctl restart beszel-agent
sudo systemctl status beszel-agent
```

**Prevention**: This issue is fixed in the latest version of `add-server-auto.sh` (all log messages now redirect to stderr).

### Success Indicators

✅ Agent logs: `INFO WebSocket connected host=monitoring.inproma.de`
✅ Dashboard shows system as "up"
✅ Real-time metrics updating

For detailed troubleshooting, see [WEBSOCKET_TROUBLESHOOTING.md](WEBSOCKET_TROUBLESHOOTING.md).

## Key Features

- **No firewall changes needed** - Agent initiates outbound connection
- **Auto-registration** - Systems appear automatically
- **Permanent tokens** - No manual renewal needed
- **Auto-reconnection** - Built-in retry logic
- **Auto-updates** - Agents update themselves daily at 3 AM

## Next Steps

After adding servers:

1. ✅ Verify in dashboard: https://monitoring.inproma.de
2. ✅ Update `docs/SERVERS.md` with server details
3. ✅ Configure alerts if needed
4. ✅ Set up custom monitoring if required

## Related Documentation

- [Quick Reference](QUICK_REFERENCE.md) - Common commands and quick access
- [Remove Server](REMOVE_SERVER.md) - Server removal guide
- [WebSocket Troubleshooting](WEBSOCKET_TROUBLESHOOTING.md) - Common issues and solutions
- [Server Inventory](SERVERS.md) - List of all monitored servers
