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
| Different hostname | Normal - uses actual system hostname |

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
