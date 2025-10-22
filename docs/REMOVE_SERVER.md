# Removing Servers from Beszel Monitoring

This guide explains how to properly remove a server from Beszel monitoring.

## Quick Removal Steps

### Method 1: Complete Automated Removal (Recommended)

```bash
# Clone the monitoring repository (if not already done)
git clone https://github.com/sebastian-fahrenkrog/beszel-monitoring.git
cd beszel-monitoring

# Remove both agent AND hub entry in one command
./scripts/remove-server-complete.sh root@your-server.com

# Or force removal without prompts
./scripts/remove-server-complete.sh --force root@your-server.com
```

### Method 2: Manual Step-by-Step Removal

#### Step 1: Remove Agent from Server

```bash
# SSH to the server you want to remove
ssh root@your-server.com

# Stop the agent service
systemctl stop beszel-agent.service
systemctl disable beszel-agent.service

# Uninstall using our secure script (automated mode)
export BESZEL_FORCE_UNINSTALL="true"
curl -fsSL https://raw.githubusercontent.com/sebastian-fahrenkrog/beszel-monitoring/main/scripts/install-beszel-agent.sh | bash -s -- uninstall
```

#### Step 2: Remove Server from Hub

```bash
# From your local machine or hub server
cd beszel-monitoring
./scripts/remove-server-from-hub.sh your-server.com

# Or force removal
./scripts/remove-server-from-hub.sh --force your-server.com
```

### Method 3: Manual Cleanup (if scripts fail)

If the uninstall script fails, perform manual cleanup:

```bash
# Remove systemd services
sudo systemctl stop beszel-agent.service beszel-agent-update.timer
sudo systemctl disable beszel-agent.service beszel-agent-update.timer
sudo rm -f /etc/systemd/system/beszel-agent.service
sudo rm -f /etc/systemd/system/beszel-agent-update.service
sudo rm -f /etc/systemd/system/beszel-agent-update.timer

# Remove installation files
sudo rm -rf /opt/beszel-agent
sudo rm -rf /var/lib/beszel-agent

# Remove user (optional)
sudo userdel beszel

# Reload systemd
sudo systemctl daemon-reload
```

## Available Scripts

### 1. Complete Removal Script (`remove-server-complete.sh`)

Removes both agent and hub entry in one operation:

```bash
# Basic usage
./scripts/remove-server-complete.sh root@server.com

# Force mode (no prompts)
./scripts/remove-server-complete.sh --force server.com

# Only remove from hub (keep agent)
./scripts/remove-server-complete.sh --hub-only server.com

# Only remove agent (keep in hub)
./scripts/remove-server-complete.sh --agent-only root@server.com
```

### 2. Hub-Only Removal Script (`remove-server-from-hub.sh`)

Removes server from hub dashboard via API:

```bash
# Remove server from hub
./scripts/remove-server-from-hub.sh server.com

# Force removal
./scripts/remove-server-from-hub.sh --force server.com

# List all servers in hub
./scripts/remove-server-from-hub.sh --list
```

### 3. Agent-Only Removal (install script)

```bash
# On the target server
export BESZEL_FORCE_UNINSTALL="true"
curl -fsSL https://raw.githubusercontent.com/sebastian-fahrenkrog/beszel-monitoring/main/scripts/install-beszel-agent.sh | bash -s -- uninstall
```

## Verification

After removal, verify the server is completely cleaned up:

```bash
# Check service status (should show "not found")
systemctl status beszel-agent

# Check for leftover files
ls -la /opt/beszel-agent 2>/dev/null || echo "Directory removed successfully"
ls -la /var/lib/beszel-agent 2>/dev/null || echo "Data directory removed successfully"

# Check if user exists
id beszel 2>/dev/null || echo "User removed successfully"
```

## Real-World Example: Removing ai.content-optimizer.de

Here's the actual process used to remove ai.content-optimizer.de:

```bash
# Connected to server
ssh root@ai.content-optimizer.de

# Stopped and disabled service
systemctl stop beszel-agent.service
systemctl disable beszel-agent.service

# Manual cleanup (uninstall script had interactive prompts)
rm -f /etc/systemd/system/beszel-agent.service
rm -f /etc/systemd/system/beszel-agent-update.service
rm -f /etc/systemd/system/beszel-agent-update.timer
rm -rf /opt/beszel-agent
rm -rf /var/lib/beszel-agent
systemctl daemon-reload
userdel beszel

# Verification
systemctl status beszel-agent  # Unit not found (expected)
ls -la /opt/beszel-agent        # No such file (expected)
```

**Result**: Server successfully removed and stopped appearing in the monitoring dashboard.

## Bulk Server Removal

To remove multiple servers at once:

```bash
#!/bin/bash
# save as remove_servers.sh

SERVERS=(
    "server1.example.com"
    "server2.example.com"
    "server3.example.com"
)

for server in "${SERVERS[@]}"; do
    echo "Removing $server..."
    ssh root@"$server" '
        systemctl stop beszel-agent.service
        systemctl disable beszel-agent.service
        rm -f /etc/systemd/system/beszel-agent*
        rm -rf /opt/beszel-agent
        rm -rf /var/lib/beszel-agent
        userdel beszel 2>/dev/null || true
        systemctl daemon-reload
        echo "Cleanup complete for $(hostname)"
    '
done
```

## What Happens on the Hub

When an agent is removed:

1. **Immediate**: Agent stops sending data
2. **~90 seconds**: Hub marks agent as "offline" 
3. **Dashboard**: Server shows as disconnected
4. **Data**: Historical data remains in hub database
5. **Manual removal**: Admin can delete server from dashboard

## Troubleshooting

### Service Won't Stop
```bash
# Force kill if needed
sudo pkill -f beszel-agent
sudo systemctl reset-failed beszel-agent
```

### Permission Denied Errors
```bash
# Ensure you're running as root or with sudo
sudo systemctl stop beszel-agent
```

### Files Still Present
```bash
# Force removal
sudo rm -rf /opt/beszel-agent /var/lib/beszel-agent
sudo find /etc/systemd -name "*beszel*" -delete
sudo systemctl daemon-reload
```

### Agent Reinstalls Automatically
Some deployment tools might reinstall the agent. Check:
- Ansible playbooks
- Docker containers
- Cron jobs
- Configuration management tools

## Data Retention

**Important**: Removing an agent only stops data collection. Historical data remains in the hub database. To completely remove all traces:

1. Remove the agent (steps above)
2. Delete the system from the hub dashboard
3. Historical data will be cleaned up according to hub retention settings

## Re-adding a Server

If you need to add the server back later:

```bash
# Use the standard installation process
export BESZEL_HUB_URL='https://monitoring.inproma.de'
export BESZEL_TOKEN='c8a8c7a7-135a-4818-ad7a-0f8581aadc96'
export BESZEL_KEY='ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILG/StjM0ypoZOCqF+lLrqznYd4y45GKaKGOB6RbXc2H'
export BESZEL_AUTO_UPDATE='true'

curl -fsSL https://raw.githubusercontent.com/sebastian-fahrenkrog/beszel-monitoring/main/scripts/install-beszel-agent.sh | sudo -E bash -s -- install
```

The server will appear as a new system in the dashboard (historical data connection depends on hostname matching).

## Security Notes

- Remove any SSH keys or access credentials after server removal
- Update firewall rules if they specifically referenced the removed server
- Clean up any monitoring-related cron jobs or scripts
- Review log rotation and cleanup scripts

## Script Features

### Complete Removal Script Features
- ✅ Removes agent from server via SSH
- ✅ Removes server from hub via API
- ✅ Confirmation prompts (unless forced)
- ✅ Detailed progress reporting
- ✅ Partial operation support (hub-only, agent-only)
- ✅ Hostname extraction from various formats

### Hub Removal Script Features
- ✅ API-based server removal
- ✅ Server lookup by name or IP
- ✅ List all servers in hub
- ✅ Force mode support
- ✅ Authentication handling

### Agent Removal Features
- ✅ Complete cleanup of all files
- ✅ Service and timer removal
- ✅ User removal (optional)
- ✅ Force mode for automation
- ✅ Verification checks

## Quick Reference

```bash
# Complete automated removal
./scripts/remove-server-complete.sh --force root@server.com

# List servers in hub
./scripts/remove-server-from-hub.sh --list

# Remove from hub only
./scripts/remove-server-from-hub.sh --force server.com

# Remove agent only (on server)
export BESZEL_FORCE_UNINSTALL="true"
curl -fsSL https://raw.githubusercontent.com/sebastian-fahrenkrog/beszel-monitoring/main/scripts/install-beszel-agent.sh | bash -s -- uninstall
```

---

**Remember**: Complete removal requires both agent cleanup AND hub removal. The universal token remains valid for other servers.