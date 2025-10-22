# Removing Servers from Beszel Monitoring

This guide explains how to properly remove a server from Beszel monitoring.

## Quick Removal Steps

### 1. Stop and Uninstall Agent on Target Server

```bash
# SSH to the server you want to remove
ssh root@your-server.com

# Stop the agent service
systemctl stop beszel-agent.service
systemctl disable beszel-agent.service

# Uninstall using our secure script
export BESZEL_HUB_URL='https://monitoring.inproma.de'
export BESZEL_TOKEN='c8a8c7a7-135a-4818-ad7a-0f8581aadc96'
export BESZEL_KEY='ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILG/StjM0ypoZOCqF+lLrqznYd4y45GKaKGOB6RbXc2H'

curl -fsSL https://raw.githubusercontent.com/sebastian-fahrenkrog/beszel-monitoring/main/scripts/install-beszel-agent.sh | bash -s -- uninstall
```

### 2. Manual Cleanup (if needed)

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

### 3. Remove from Hub Dashboard

The server will automatically disappear from the Beszel hub dashboard after it stops connecting. However, you can manually remove it:

1. Open https://monitoring.inproma.de
2. Log in with your credentials
3. Navigate to the systems list
4. Find the server you want to remove
5. Click the delete/remove button for that server

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

---

**Remember**: Server removal is immediate once the agent stops. The universal token remains valid for other servers.