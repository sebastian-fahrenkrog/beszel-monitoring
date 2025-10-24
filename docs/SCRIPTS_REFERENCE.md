# Scripts Reference

All management scripts for Beszel monitoring system.

## Script Overview

| Script | Purpose | Usage |
|--------|---------|-------|
| `add-server-auto.sh` | **Automated server addition** (recommended) | `./scripts/add-server-auto.sh root@server.com` |
| `add-server.sh` | Manual server addition | `./scripts/add-server.sh root@server.com` |
| `install-beszel-agent.sh` | Agent installation script | Called by add-server scripts |
| `remove-server-complete.sh` | Complete server removal | `./scripts/remove-server-complete.sh root@server.com` |
| `remove-server-from-hub.sh` | Hub-only removal | `./scripts/remove-server-from-hub.sh server.com` |
| `verify_agent_connection.sh` | Verify agent connection | `./scripts/verify_agent_connection.sh` |
| `manage_config.sh` | Config management | `./scripts/manage_config.sh export` |

## Adding Servers

### Quick Start (Recommended)

The **automated script** handles everything for you:

```bash
# Add single server
./scripts/add-server-auto.sh root@new-server.com

# Add multiple servers
./scripts/add-server-auto.sh root@server1.com root@server2.com root@server3.com

# Add and verify
./scripts/add-server-auto.sh --verify root@new-server.com

# List all monitored servers
./scripts/add-server-auto.sh --list
```

**What it does automatically:**
1. Authenticates with hub API
2. Regenerates universal token (required for each addition!)
3. Retrieves SSH public key from hub
4. Installs agent on target server(s)
5. Optionally verifies connection

### Manual Addition (Advanced)

For more control, use the manual script:

```bash
# Step 1: Set environment variables
export BESZEL_TOKEN="your-universal-token"
export BESZEL_KEY="ssh-ed25519 your-public-key"

# Step 2: Add server
./scripts/add-server.sh root@new-server.com
```

**When to use manual script:**
- Custom installation workflows
- Testing specific configurations
- Debugging connection issues

### Prerequisites

Both scripts require:
- SSH access to target server (root or sudo)
- For automated script: `curl`, `jq`, `ssh` installed locally
- Hub credentials (set via environment variables)

## Removing Servers

### Complete Removal

Remove both agent AND hub entry:

```bash
# Interactive (asks for confirmation)
./scripts/remove-server-complete.sh root@server.com

# Force mode (skip confirmations)
./scripts/remove-server-complete.sh --force root@server.com

# Hub only (keep agent installed)
./scripts/remove-server-complete.sh --hub-only server.com

# Agent only (keep hub entry)
./scripts/remove-server-complete.sh --agent-only root@server.com
```

### Hub-Only Removal

Remove server from dashboard without touching the agent:

```bash
# Interactive
./scripts/remove-server-from-hub.sh server.com

# Force mode
./scripts/remove-server-from-hub.sh --force server.com

# List all servers
./scripts/remove-server-from-hub.sh --list
```

## Verification and Troubleshooting

### Verify Agent Connection

Check if agents are connecting and sending metrics:

```bash
# Set credentials
export BESZEL_ADMIN_EMAIL="your-email@example.com"
export BESZEL_ADMIN_PASSWORD="your-password"

# Run verification
./scripts/verify_agent_connection.sh
```

**Output shows:**
- Authentication status
- Universal token status
- Connected systems list
- Latest metrics for each system

### Common Issues

#### "Failed to authenticate"
```bash
# Test credentials
curl -X POST https://monitoring.inproma.de/api/collections/users/auth-with-password \
  -H "Content-Type: application/json" \
  -d '{"identity": "your-email", "password": "your-password"}'
```

#### "Universal token expired"
Tokens expire after 1 hour or on hub restart. Use `add-server-auto.sh` which automatically regenerates tokens.

#### "Agent not connecting"
```bash
# Check agent logs on target server
ssh root@server.com 'journalctl -u beszel-agent -f'

# Verify environment variables
ssh root@server.com 'systemctl show beszel-agent --property=Environment'

# Restart agent
ssh root@server.com 'systemctl restart beszel-agent'
```

## Configuration Management

### Export Current Configuration

Save current hub configuration to `config.yml`:

```bash
export BESZEL_ADMIN_EMAIL="your-email"
export BESZEL_ADMIN_PASSWORD="your-password"

./scripts/manage_config.sh export
```

### Validate Configuration

Check YAML syntax:

```bash
./scripts/manage_config.sh validate
```

### Backup Configuration

Create timestamped backup:

```bash
./scripts/manage_config.sh backup
```

Backups stored in: `backups/config_YYYYMMDD_HHMMSS.yml`

## Environment Variables

### Required for Automated Script

| Variable | Description | Default |
|----------|-------------|---------|
| `BESZEL_HUB_URL` | Hub URL | https://monitoring.inproma.de |
| `BESZEL_HUB_SERVER` | Hub SSH server | monitoring.inproma.de |
| `BESZEL_ADMIN_EMAIL` | Admin email | sebastian.fahrenkrog@gmail.com |
| `BESZEL_ADMIN_PASSWORD` | Admin password | (required) |

### Required for Manual Script

| Variable | Description |
|----------|-------------|
| `BESZEL_TOKEN` | Universal token from hub |
| `BESZEL_KEY` | Hub SSH public key |

### Optional Configuration

| Variable | Description | Default |
|----------|-------------|---------|
| `BESZEL_AUTO_UPDATE` | Enable auto-updates | true |
| `GITHUB_USER` | GitHub username | sebastian-fahrenkrog |
| `GITHUB_REPO` | Repository name | beszel-monitoring |
| `GITHUB_BRANCH` | Branch name | main |

## Usage Examples

### Add Multiple Servers from File

```bash
# Create servers list
cat > servers.txt << EOF
root@web01.example.com
root@web02.example.com
root@db01.example.com
EOF

# Add all servers
./scripts/add-server-auto.sh $(cat servers.txt)
```

### Add Servers with Verification

```bash
# Add and immediately verify
./scripts/add-server-auto.sh --verify root@server1.com root@server2.com

# Check results
./scripts/add-server-auto.sh --list
```

### Batch Addition with Error Handling

```bash
#!/bin/bash
SERVERS=(
    "root@server1.com"
    "root@server2.com"
    "root@server3.com"
)

LOG_FILE="additions-$(date +%Y%m%d-%H%M%S).log"

for server in "${SERVERS[@]}"; do
    echo "Adding $server..." | tee -a "$LOG_FILE"
    if ./scripts/add-server-auto.sh "$server" 2>&1 | tee -a "$LOG_FILE"; then
        echo "✅ $server added" | tee -a "$LOG_FILE"
    else
        echo "❌ $server failed" | tee -a "$LOG_FILE"
    fi
done

echo "Log: $LOG_FILE"
```

### Remove Server with Backup

```bash
# Export config before removal
./scripts/manage_config.sh backup

# Remove server
./scripts/remove-server-complete.sh root@old-server.com

# Verify removal
./scripts/add-server-auto.sh --list
```

## Best Practices

### Security

1. **Never commit credentials** - Use environment variables or `.env` file
2. **Use SSH keys** - Configure passwordless SSH authentication
3. **Regenerate tokens** - Use automated script which handles token regeneration
4. **Backup regularly** - Export config before major changes

### Server Management

1. **Verify after addition** - Use `--verify` flag or check dashboard
2. **Document servers** - Update `docs/SERVERS.md` with server details
3. **Monitor logs** - Check agent logs after installation
4. **Test alerts** - Verify notification channels are working

### Bulk Operations

1. **Batch size** - Add 5-10 servers at a time for large deployments
2. **Error handling** - Log output and check for failures
3. **Verification** - Always verify batch additions completed successfully
4. **Parallel execution** - Use GNU parallel for very large deployments

## Script Locations

All scripts in: `/scripts/`

```
scripts/
├── add-server-auto.sh           # Automated addition (recommended)
├── add-server.sh                # Manual addition
├── install-beszel-agent.sh      # Agent installer
├── remove-server-complete.sh    # Complete removal
├── remove-server-from-hub.sh    # Hub-only removal
├── verify_agent_connection.sh   # Connection verification
├── manage_config.sh             # Config management
└── config.yml                   # Configuration file
```

## Related Documentation

- **Quick Reference**: `docs/QUICK_REFERENCE.md` - Quick commands and navigation
- **New Server Setup**: `docs/NEW_SERVER_SETUP.md` - Complete setup guide
- **Server List**: `docs/SERVERS.md` - All monitored servers
- **Troubleshooting**: `docs/WEBSOCKET_TROUBLESHOOTING.md` - Common issues

## Support

- **Dashboard**: https://monitoring.inproma.de
- **Documentation**: `docs/` directory
- **Issues**: Report problems in repository

---

**Last Updated**: 2025-10-24
**Maintained by**: Sebastian Fahrenkrog
