# Beszel Monitoring - Secure Installation Scripts

This repository contains secure, self-hosted installation scripts for [Beszel](https://github.com/henrygd/beszel) monitoring agents with WebSocket connectivity.

## 🔐 Why Self-Hosted Scripts?

- **Security**: Review and audit installation scripts before deployment
- **Control**: Modify scripts to match your infrastructure requirements  
- **Stability**: Scripts won't change unexpectedly
- **Compliance**: Meet security policies that prohibit external script execution

## 🚀 Quick Start - Add a New Server

### Method 1: Using Clear Variables (Recommended)

```bash
# Set up environment variables (get these from your Beszel hub admin)
export BESZEL_HUB_URL="https://your-monitoring-hub.example.com"
export BESZEL_TOKEN="your-universal-token-here"
export BESZEL_KEY="ssh-ed25519 your-hub-public-key-here"
export BESZEL_AUTO_UPDATE="true"

# Download and run the secure installation script
curl -fsSL https://raw.githubusercontent.com/sebastian-fahrenkrog/beszel-monitoring/main/scripts/install-beszel-agent.sh | sudo -E bash -s -- install
```

### Method 2: Using the Helper Script

```bash
# Clone this repository
git clone https://github.com/sebastian-fahrenkrog/beszel-monitoring.git
cd beszel-monitoring

# Add a remote server
./scripts/add-server.sh root@your-server.com

# Or install on current server
sudo ./scripts/add-server.sh
```

## 📁 Repository Structure

```
.
├── scripts/
│   ├── install-beszel-agent.sh  # Main installation script (secure version)
│   ├── add-server.sh            # Helper script for adding servers
│   └── original-install-agent.sh # Original script for reference
├── config.yml                    # System configuration (optional with universal tokens)
├── manage_config.sh              # Configuration management tool
├── verify_agent_connection.sh    # Connection verification script
└── docs/
    ├── NEW_SERVER_SETUP.md       # Complete guide for adding servers
    ├── WEBSOCKET_TROUBLESHOOTING.md # Troubleshooting guide
    └── QUICK_REFERENCE.md        # Quick command reference
```

## 🔧 Installation Script Features

The `install-beszel-agent.sh` script includes:

- **Full error handling** with `set -euo pipefail`
- **System compatibility checks** before installation
- **Clear variable configuration** at the top of the script
- **Security hardening** in systemd service
- **Colored output** for better readability
- **Automatic updates** configuration (optional)
- **Uninstall functionality** included

## 📝 Configuration Variables Explained

All configuration uses clear environment variables:

| Variable | Description | Example Value |
|----------|-------------|---------------|
| `BESZEL_HUB_URL` | Your monitoring hub URL | `https://your-hub.example.com` |
| `BESZEL_TOKEN` | Universal token (get from hub admin) | `your-universal-token-here` |
| `BESZEL_KEY` | Hub's SSH public key for verification | `ssh-ed25519 your-key-here` |
| `BESZEL_AUTO_UPDATE` | Enable automatic agent updates | `true` or `false` |

### Optional Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `BESZEL_AGENT_VERSION` | Specific version to install | `latest` |
| `BESZEL_INSTALL_DIR` | Installation directory | `/opt/beszel-agent` |
| `BESZEL_DATA_DIR` | Data directory | `/var/lib/beszel-agent` |
| `BESZEL_SERVICE_USER` | Service user | `beszel` |

## 🔐 Security Features

1. **No External Dependencies**: Scripts hosted in your own repository
2. **Review Before Run**: Always review scripts before execution
3. **Systemd Hardening**: Security restrictions in service file
4. **Minimal Permissions**: Runs as non-root user
5. **Resource Limits**: Prevents resource exhaustion

## 🎯 How It Works

### WebSocket Architecture
- **Agent-Initiated**: No inbound firewall rules needed
- **Persistent Connection**: Real-time metrics over WebSocket
- **Auto-Reconnect**: Built-in retry with exponential backoff

### Universal Tokens
- **Permanent**: Auto-renew every hour when used
- **Shared**: One token for unlimited servers
- **Secure**: Combined with SSH key verification

## 🚨 Troubleshooting

### Check Installation

```bash
# Service status
systemctl status beszel-agent

# View logs
journalctl -u beszel-agent -f

# Verify environment
systemctl show beszel-agent --property=Environment
```

### Common Issues

| Problem | Solution |
|---------|----------|
| "invalid signature" | Wrong SSH key - must be from `/beszel_data/id_ed25519` |
| "401 unauthorized" | Token not active or incorrect |
| "connection refused" | Check outbound HTTPS connectivity |

## 🛠️ Maintenance

### Update Agent

```bash
sudo /opt/beszel-agent/beszel-agent update
```

### Uninstall Agent

```bash
sudo bash install-beszel-agent.sh uninstall
```

## 📊 Dashboard Access

- **URL**: https://monitoring.inproma.de
- **Login**: admin@example.com (replace with your admin email)
- **Systems**: Appear automatically with their hostname

## 🤝 Contributing

Improvements welcome! Submit issues and pull requests.

## 📜 License

MIT License. Beszel itself has its own licensing terms.

## 🔗 Links

- [Beszel Official](https://github.com/henrygd/beszel)
- [Monitoring Dashboard](https://monitoring.inproma.de)

---

**⚠️ Security Note**: Always review scripts before execution, even from this repository!