# Monitored Servers

This document tracks all servers currently monitored by the Beszel monitoring system.

## Hub Server

| Server | URL | Type | Status | Notes |
|--------|-----|------|--------|-------|
| monitoring.inproma.de | https://monitoring.inproma.de | Hub | ✅ Active | Docker deployment with nginx proxy |

## Monitored Agents

| Hostname | IP/Domain | Added | Status | Specs | Notes |
|----------|-----------|-------|--------|-------|-------|
| hosting.dev.testserver.online | m.dev.testserver.online | 2024-10-21 | ✅ Active | Linux | First agent, used for testing WebSocket mode |
| master.corespot-manager.com | inproma.dataguide.de | 2024-10-22 | ✅ Active | 16 CPU, 61GB RAM, Docker | Production server |
| ~~ai.content-optimizer.de~~ | ~~ai.content-optimizer.de~~ | ~~2024-10-22~~ | ❌ Removed 2024-10-22 | ~~20 CPU, 62GB RAM, RTX 4000 GPU, Docker~~ | ~~Production AI server with GPU monitoring~~ |

## Installation History

### master.corespot-manager.com (Latest)
- **Added**: 2024-10-22
- **Method**: Secure self-hosted script from GitHub
- **Universal Token**: 4087a54a-8935-426c-b8ab-eae23ad8df4c (regenerated before installation)
- **Key Learning**: Universal tokens MUST be regenerated before each new server installation
- **Installation Command**:
```bash
# Step 1: Regenerate universal token
AUTH_TOKEN=$(curl -s -X POST https://monitoring.inproma.de/api/collections/users/auth-with-password \
  -H "Content-Type: application/json" \
  -d '{"identity": "sebastian.fahrenkrog@gmail.com", "password": "gOACNFz1TvdT8r"}' | jq -r '.token')

curl -X GET "https://monitoring.inproma.de/api/beszel/universal-token?enable=1" \
  -H "Authorization: Bearer $AUTH_TOKEN"

# Step 2: Install with new token
export BESZEL_HUB_URL='https://monitoring.inproma.de'
export BESZEL_TOKEN='4087a54a-8935-426c-b8ab-eae23ad8df4c'
export BESZEL_KEY='ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILG/StjM0ypoZOCqF+lLrqznYd4y45GKaKGOB6RbXc2H'
export BESZEL_AUTO_UPDATE='true'

curl -fsSL https://raw.githubusercontent.com/sebastian-fahrenkrog/beszel-monitoring/main/scripts/install-beszel-agent.sh | bash -s -- install
```
- **Status**: Successfully connected after token regeneration

### ai.content-optimizer.de (Removed)
- **Added**: 2024-10-22
- **Removed**: 2024-10-22
- **Method**: Secure self-hosted script from GitHub
- **Removal Process**:
```bash
# Stopped and removed agent
systemctl stop beszel-agent.service
systemctl disable beszel-agent.service
rm -rf /opt/beszel-agent /var/lib/beszel-agent
userdel beszel
systemctl daemon-reload
```
- **Reason**: No longer needed for monitoring
- **Features**: Had auto-updates, Docker monitoring, GPU monitoring

### hosting.dev.testserver.online
- **Date**: 2024-10-21
- **Method**: Initial testing with various scripts
- **Key Learning**: Discovered correct SSH key location (`/beszel_data/id_ed25519`)
- **Status**: Successfully connected after fixing authentication

## System Capabilities

### GPU Monitoring
- ai.content-optimizer.de: NVIDIA RTX 4000 SFF Ada Generation
- Metrics: Temperature, memory usage, utilization, power draw

### Docker Monitoring
- Both servers have Docker installed
- Agent user added to docker group for container statistics
- Monitors container CPU, memory, network usage

## Adding New Servers

To add a new server, use the helper script:

```bash
# From monitoring repository
./scripts/add-server.sh root@new-server.com

# Or use direct installation
export BESZEL_HUB_URL='https://monitoring.inproma.de'
export BESZEL_TOKEN='c8a8c7a7-135a-4818-ad7a-0f8581aadc96'
export BESZEL_KEY='ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILG/StjM0ypoZOCqF+lLrqznYd4y45GKaKGOB6RbXc2H'
export BESZEL_AUTO_UPDATE='true'

curl -fsSL https://raw.githubusercontent.com/sebastian-fahrenkrog/beszel-monitoring/main/scripts/install-beszel-agent.sh | sudo -E bash -s -- install
```

## Removing Servers

To remove a server from monitoring:

```bash
# SSH to the server
ssh root@server-to-remove.com

# Stop and uninstall agent
systemctl stop beszel-agent.service
systemctl disable beszel-agent.service

# Use uninstall script
curl -fsSL https://raw.githubusercontent.com/sebastian-fahrenkrog/beszel-monitoring/main/scripts/install-beszel-agent.sh | bash -s -- uninstall

# Or manual cleanup
rm -rf /opt/beszel-agent /var/lib/beszel-agent
userdel beszel
systemctl daemon-reload
```

See [REMOVE_SERVER.md](REMOVE_SERVER.md) for complete removal documentation.

## Maintenance Commands

### Check Agent Status
```bash
systemctl status beszel-agent
journalctl -u beszel-agent -f
```

### Update Agent
```bash
sudo /opt/beszel-agent/beszel-agent update
```

### Restart Agent
```bash
sudo systemctl restart beszel-agent
```

## Notes

- Universal token auto-renews every hour when used
- WebSocket connection allows agent-initiated connection (no inbound firewall rules needed)
- Auto-update runs daily at 3 AM with 1-hour random delay
- All servers appear in dashboard with their hostname