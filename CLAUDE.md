# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This repository contains the Beszel monitoring system deployment for:
- **Hub Server**: monitoring.inproma.de (Docker container behind Nginx proxy)
- **Agent Server**: m.dev.testserver.online (appears as hosting.dev.testserver.online)
- **Connection Mode**: Agent-initiated WebSocket (no inbound firewall rules needed)

### Repository Structure
- **scripts/**: All management and installation scripts
- **docs/**: Complete documentation and guides
- **custom-health-checks/**: Custom health check system
- **ai_tasks/**: Task planning documents
- **ai_docs/**: Technical documentation and source code reference

Beszel is a lightweight server monitoring platform built with Go and PocketBase, using a hub-agent architecture for distributed system monitoring.

## Important Files and Scripts

### Core Scripts (scripts/)
- `install-beszel-agent.sh` - Main agent installation script with WebSocket configuration
- `add-server.sh` - Helper script for adding new servers
- `remove-server-complete.sh` - Complete server removal (agent + hub)
- `remove-server-from-hub.sh` - Hub-only removal via API
- `verify_agent_connection.sh` - Verify agent connection and metrics collection
- `manage_config.sh` - Configuration management tool

### Key Documentation (docs/)
- `NEW_SERVER_SETUP.md` - **Quick guide for adding new servers (START HERE!)**
- `REMOVE_SERVER.md` - Server removal guide
- `SERVERS.md` - Server inventory and tracking
- `INSTALLATION_INSTRUCTIONS.md` - Detailed installation guide
- `WEBSOCKET_TROUBLESHOOTING.md` - Common issues and solutions
- `CUSTOM_HEALTH_CHECKS.md` - Custom monitoring guide

### Source Code Reference
- `ai_docs/src/beszel/` - Complete Beszel source code for implementation details
- `ai_tasks/` - Deployment planning documents

## Current Deployment Details

### Hub Access
- **URL**: https://monitoring.inproma.de
- **Admin**: sebastian.fahrenkrog@gmail.com / gOACNFz1TvdT8r
- **API Endpoint**: https://monitoring.inproma.de/api/
- **Container**: beszel-hub (Docker)
- **Data Directory**: `/opt/beszel-hub/beszel_data/`

### Agent Configuration
- **Universal Token**: **MUST BE REGENERATED** for each new server (expires after 1 hour or on hub restart!)
- **Current Token**: 4087a54a-8935-426c-b8ab-eae23ad8df4c (generated 2024-10-22 15:41)
- **SSH Public Key**: From hub's `/beszel_data/id_ed25519` (NOT agent_key.pub!)
- **Connection**: WebSocket to wss://monitoring.inproma.de/api/beszel/agent-connect

### Adding New Servers - IMPORTANT: Token Regeneration Required!

**⚠️ CRITICAL**: Universal tokens expire after 1 hour or when the hub restarts. You **MUST** regenerate the token before adding each new server!

#### Step 1: Regenerate Universal Token
```bash
# Get authentication token
AUTH_TOKEN=$(curl -s -X POST https://monitoring.inproma.de/api/collections/users/auth-with-password \
  -H "Content-Type: application/json" \
  -d '{"identity": "sebastian.fahrenkrog@gmail.com", "password": "gOACNFz1TvdT8r"}' | jq -r '.token')

# Generate/activate universal token
curl -X GET "https://monitoring.inproma.de/api/beszel/universal-token?enable=1" \
  -H "Authorization: Bearer $AUTH_TOKEN"
# Returns: {"active":true,"token":"NEW-TOKEN-HERE"}
```

#### Step 2: Install Agent with New Token
```bash
# Use the NEW token from step 1
export BESZEL_HUB_URL='https://monitoring.inproma.de'
export BESZEL_TOKEN='NEW-TOKEN-FROM-STEP-1'
export BESZEL_KEY='ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILG/StjM0ypoZOCqF+lLrqznYd4y45GKaKGOB6RbXc2H'
export BESZEL_AUTO_UPDATE='true'

curl -fsSL https://raw.githubusercontent.com/sebastian-fahrenkrog/beszel-monitoring/main/scripts/install-beszel-agent.sh | sudo -E bash -s -- install
```

## Admin Operations

### Hub Management

```bash
# SSH to hub server
ssh root@monitoring.inproma.de

# Check hub status
docker ps | grep beszel
docker logs beszel-hub --tail 50

# Restart hub
cd /opt/beszel-hub
docker compose restart

# Backup data
tar -czf beszel_backup_$(date +%Y%m%d).tar.gz beszel_data/

# Extract SSH public key (for agents)
ssh-keygen -y -f /opt/beszel-hub/beszel_data/id_ed25519
```

### Agent Management

```bash
# SSH to agent server
ssh root@m.dev.testserver.online

# Check agent status
systemctl status beszel-agent
journalctl -u beszel-agent -f

# Restart agent
systemctl restart beszel-agent

# Check environment variables
systemctl show beszel-agent --property=Environment

# Update agent
/opt/beszel-agent/beszel-agent update
```

### API Operations

```bash
# Get auth token
AUTH_TOKEN=$(curl -s -X POST https://monitoring.inproma.de/api/collections/users/auth-with-password \
  -H "Content-Type: application/json" \
  -d '{"identity": "sebastian.fahrenkrog@gmail.com", "password": "gOACNFz1TvdT8r"}' | jq -r '.token')

# Get/create universal token
curl -X GET "https://monitoring.inproma.de/api/beszel/universal-token?enable=1" \
  -H "Authorization: Bearer $AUTH_TOKEN" | jq

# List systems
curl -X GET "https://monitoring.inproma.de/api/collections/systems/records" \
  -H "Authorization: Bearer $AUTH_TOKEN" | jq

# Check system stats
curl -X GET "https://monitoring.inproma.de/api/collections/system_stats/records?filter=(system='SYSTEM_ID')&sort=-created&perPage=1" \
  -H "Authorization: Bearer $AUTH_TOKEN" | jq
```

## Critical Configuration Points

### WebSocket Mode Requirements

1. **Environment Variables** (must use BESZEL_AGENT_ prefix):
   - `BESZEL_AGENT_HUB_URL=https://monitoring.inproma.de`
   - `BESZEL_AGENT_TOKEN=<universal-token>`
   - `BESZEL_AGENT_KEY=<hub-ssh-public-key>`

2. **SSH Key**: Must be from `/beszel_data/id_ed25519`, not `agent_key.pub`

3. **Nginx Configuration**: Must support WebSocket upgrade headers

4. **Universal Token**: Must be activated via API with `?enable=1`

## Source Code Reference

When troubleshooting, reference the source code in `ai_docs/src/`:

### Key Files for WebSocket Mode
- `agent/client.go` - WebSocket client implementation
- `agent/connection_manager.go` - Connection management and reconnection
- `internal/hub/agent_connect.go` - Hub-side WebSocket handler
- `internal/common/common-ws.go` - Message protocol definitions

### Authentication Flow
1. Agent connects with token in header
2. Hub sends SSH signature challenge
3. Agent verifies signature with public key
4. Hub creates/finds system record
5. WebSocket connection established for metrics

## Development Commands

### Go Backend Development (Beszel)

```bash
# Build commands (from ai_docs/src/beszel/)
make build              # Build both agent and hub
make build-agent        # Build agent only
make build-hub          # Build hub only  
make build-hub-dev      # Build hub for development

# Development servers
make dev                # Run all dev servers (hub, agent, web UI)
make dev-hub            # Run hub server only (port 8090)
make dev-agent          # Run agent only
make dev-server         # Run web UI dev server

# Testing and quality
make test               # Run all tests with synctest
make lint               # Run golangci-lint
make tidy               # Clean up go.mod
```

### Frontend Development (React/Vite)

```bash
# From ai_docs/src/beszel/internal/site/
bun install             # Install dependencies (or npm install)
bun run dev             # Start development server
bun run build           # Production build
bun run lint            # Run biome linter
bun run check           # Full biome check
bun run check:fix       # Auto-fix linting issues

# Localization
bun run sync            # Extract and compile translations
bun run sync_and_purge  # Clean extraction and compile
```

## Architecture

### Hub Component
- **Location**: `ai_docs/src/beszel/internal/cmd/hub/`
- **Port**: 8090 (default)
- **Database**: SQLite (via PocketBase)
- **Frontend**: React + Vite + TailwindCSS in `internal/site/`
- **Docker Image**: `henrygd/beszel:latest`

### Agent Component  
- **Location**: `ai_docs/src/beszel/internal/cmd/agent/`
- **Port**: 45876 (SSH mode only, not used in WebSocket mode)
- **Communication**: WebSocket to hub (agent-initiated)
- **Docker Image**: `henrygd/beszel-agent:latest`

### Key Directories
- `internal/alerts/`: Alert system and notifications
- `internal/records/`: Data models and database operations
- `internal/migrations/`: Database migrations
- `internal/site/`: React frontend application
- `supplemental/scripts/`: Installation and deployment scripts
- `agent/`: Agent implementation including WebSocket client
- `internal/hub/`: Hub implementation including WebSocket server

## Troubleshooting Quick Reference

### Agent Not Connecting
1. Check environment variables: `systemctl show beszel-agent --property=Environment`
2. Verify token is active: Check via API
3. Confirm correct SSH key: From `id_ed25519`, not `agent_key.pub`
4. Check logs: `journalctl -u beszel-agent -f`

### Common Errors
- **"invalid signature - check KEY value"**: Wrong SSH public key
- **"unexpected status code: 401"**: Token not active or wrong
- **"HUB_URL environment variable not set"**: Missing BESZEL_AGENT_ prefix
- **"Connection closed err=EOF"**: Network or hub issue, will auto-reconnect

### Success Indicators
- Agent logs: "WebSocket connected host=monitoring.inproma.de"
- Hub dashboard: System appears with "up" status
- Metrics: Real-time updates visible in dashboard

## Monitored Metrics
The system tracks: CPU usage, memory usage, disk I/O, network traffic, load average, temperature sensors, GPU usage, Docker container stats, and battery status.

## Notes
- Systems may appear with their actual hostname (e.g., hosting.dev.testserver.online instead of m.dev.testserver.online)
- WebSocket mode doesn't require any inbound firewall rules on the agent
- Automatic reconnection is built-in with exponential backoff
- Universal tokens allow automatic system registration without pre-configuration