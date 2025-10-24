# Add Server to Beszel Monitoring

This directory contains scripts to add new servers to your Beszel monitoring system.

## Quick Start

### Option 1: Automated Script (Recommended)

The `add-server-auto.sh` script automatically handles token regeneration and agent installation:

```bash
# Add single server
./scripts/add-server-auto.sh root@new-server.com

# Add multiple servers at once
./scripts/add-server-auto.sh root@server1.com root@server2.com root@server3.com

# Add server and verify connection
./scripts/add-server-auto.sh --verify root@new-server.com

# List currently monitored servers
./scripts/add-server-auto.sh --list
```

### Option 2: Manual Script

The `add-server.sh` script requires you to set environment variables first:

```bash
# Set environment variables
export BESZEL_TOKEN="your-universal-token"
export BESZEL_KEY="ssh-ed25519 your-public-key"

# Add server
./scripts/add-server.sh root@new-server.com
```

## Features Comparison

| Feature | add-server-auto.sh | add-server.sh |
|---------|-------------------|---------------|
| Auto token regeneration | ✅ Yes | ❌ No (manual) |
| Auto SSH key retrieval | ✅ Yes | ❌ No (manual) |
| Multiple servers | ✅ Yes | ❌ No |
| Connection verification | ✅ Yes (--verify) | ❌ No |
| List servers | ✅ Yes (--list) | ❌ No |
| Environment setup | ✅ Automatic | ⚠️ Manual |

## Automated Script (`add-server-auto.sh`)

### Prerequisites

The script requires the following tools:
- `curl` - For API calls
- `jq` - For JSON parsing
- `ssh` - For remote server access

Install on Debian/Ubuntu:
```bash
sudo apt-get install curl jq openssh-client
```

Install on RHEL/CentOS:
```bash
sudo yum install curl jq openssh-clients
```

### Usage

```bash
./scripts/add-server-auto.sh [OPTIONS] SERVER_ADDRESS [SERVER_ADDRESS...]
```

**Options:**
- `-h, --help` - Show help message
- `-l, --list` - List currently monitored servers
- `-v, --verify` - Verify servers after installation

### Examples

#### Add Single Server

```bash
./scripts/add-server-auto.sh root@example.com
```

#### Add Multiple Servers

```bash
./scripts/add-server-auto.sh \
    root@server1.example.com \
    root@server2.example.com \
    root@server3.example.com
```

#### Add Server with Verification

```bash
./scripts/add-server-auto.sh --verify root@new-server.com
```

This will:
1. Install the agent
2. Wait 5 seconds
3. Verify the server appears in the hub
4. Display current metrics (CPU, memory)

#### List All Monitored Servers

```bash
./scripts/add-server-auto.sh --list
```

Output example:
```
======================================
  Currently Monitored Servers
======================================

[up] backup - CPU: 1%, Mem: 5.2%
[up] dama - CPU: 2%, Mem: 19.03%
[up] dataguide.sigor.de - CPU: 3%, Mem: 22.45%
[up] foodstar - CPU: 2%, Mem: 14.97%
...

Total servers: 28
======================================
```

### Environment Variables

You can customize the script behavior with environment variables:

| Variable | Description | Default |
|----------|-------------|---------|
| `BESZEL_HUB_URL` | Hub URL | https://monitoring.inproma.de |
| `BESZEL_HUB_SERVER` | Hub SSH server | monitoring.inproma.de |
| `BESZEL_ADMIN_EMAIL` | Admin email | sebastian.fahrenkrog@gmail.com |
| `BESZEL_ADMIN_PASSWORD` | Admin password | (configured) |
| `GITHUB_USER` | GitHub username | sebastian-fahrenkrog |
| `GITHUB_REPO` | Repository name | beszel-monitoring |
| `GITHUB_BRANCH` | Branch name | main |

Example with custom hub:
```bash
export BESZEL_HUB_URL="https://monitoring.example.com"
export BESZEL_HUB_SERVER="monitoring.example.com"
export BESZEL_ADMIN_EMAIL="admin@example.com"
export BESZEL_ADMIN_PASSWORD="your-password"

./scripts/add-server-auto.sh root@new-server.com
```

### How It Works

The script performs the following steps automatically:

1. **Check Dependencies** - Verifies curl, jq, and ssh are installed
2. **Regenerate Universal Token** - Authenticates with hub API and generates fresh token
3. **Retrieve SSH Public Key** - Gets the hub's SSH public key for agent verification
4. **Install Agent(s)** - Runs installation script on each target server
5. **Verify (Optional)** - Confirms servers appear in hub and are reporting metrics

### SSH Requirements

- You must have SSH access to the target servers
- Root access is required for agent installation
- SSH keys should be configured for passwordless authentication (recommended)

### Troubleshooting

#### "Failed to authenticate with hub"

Check your credentials:
```bash
curl -X POST https://monitoring.inproma.de/api/collections/users/auth-with-password \
  -H "Content-Type: application/json" \
  -d '{"identity": "your-email", "password": "your-password"}'
```

#### "Failed to retrieve SSH public key from hub"

Verify you can SSH to the hub server:
```bash
ssh root@monitoring.inproma.de 'ls /opt/beszel-hub/beszel_data/id_ed25519'
```

#### "Installation failed"

Check the following:
1. Target server is accessible via SSH
2. Target server has internet access to download installation script
3. Target server meets system requirements (Linux, systemd)

View detailed logs on the target server:
```bash
ssh root@target-server 'journalctl -u beszel-agent -n 50'
```

#### "Server not found in hub"

Wait a minute after installation, then check again:
```bash
./scripts/add-server-auto.sh --list
```

Or verify manually:
```bash
ssh root@target-server 'systemctl status beszel-agent'
```

## Manual Script (`add-server.sh`)

### Setup

1. **Regenerate Universal Token:**

```bash
# Get auth token
AUTH_TOKEN=$(curl -s -X POST https://monitoring.inproma.de/api/collections/users/auth-with-password \
  -H "Content-Type: application/json" \
  -d '{"identity": "sebastian.fahrenkrog@gmail.com", "password": "gOACNFz1TvdT8r"}' | jq -r '.token')

# Generate universal token
curl -X GET "https://monitoring.inproma.de/api/beszel/universal-token?enable=1" \
  -H "Authorization: Bearer $AUTH_TOKEN"
```

2. **Get SSH Public Key:**

```bash
ssh root@monitoring.inproma.de 'ssh-keygen -y -f /opt/beszel-hub/beszel_data/id_ed25519'
```

3. **Set Environment Variables:**

```bash
export BESZEL_TOKEN="your-universal-token-from-step-1"
export BESZEL_KEY="ssh-ed25519 your-public-key-from-step-2"
```

4. **Run Script:**

```bash
./scripts/add-server.sh root@new-server.com
```

## Best Practices

### Security

1. **Universal Token** - Automatically regenerated by add-server-auto.sh
2. **SSH Keys** - Use key-based authentication for SSH access
3. **Credentials** - Never commit credentials to git (use .env file)

### Multiple Servers

When adding multiple servers, use the automated script for efficiency:

```bash
# Create a list of servers
cat > servers.txt << EOF
root@server1.example.com
root@server2.example.com
root@server3.example.com
EOF

# Add all servers
./scripts/add-server-auto.sh $(cat servers.txt)
```

### Verification

Always verify connections after adding servers:

```bash
# Verify during installation
./scripts/add-server-auto.sh --verify root@new-server.com

# Or check later
./scripts/add-server-auto.sh --list
```

### Documentation

After adding servers, update `docs/SERVERS.md` with the new server details.

## Support

- **Documentation**: See `docs/` directory for detailed guides
- **Issues**: Report issues at the GitHub repository
- **Dashboard**: https://monitoring.inproma.de

## Related Documentation

- [Installation Instructions](../docs/INSTALLATION_INSTRUCTIONS.md)
- [Server List](../docs/SERVERS.md)
- [New Server Setup](../docs/NEW_SERVER_SETUP.md)
- [WebSocket Troubleshooting](../docs/WEBSOCKET_TROUBLESHOOTING.md)
