# Adding New Servers to Beszel Monitoring

## ⚠️ IMPORTANT: Universal Token Expiration

**CRITICAL**: Universal tokens expire after **1 hour** or when the **hub restarts**. You **MUST** regenerate the token before adding each new server!

## Quick Start - Two-Step Process 🚀

### Step 1: Regenerate Universal Token

```bash
# Authenticate with hub
AUTH_TOKEN=$(curl -s -X POST https://monitoring.inproma.de/api/collections/users/auth-with-password \
  -H "Content-Type: application/json" \
  -d '{"identity": "sebastian.fahrenkrog@gmail.com", "password": "gOACNFz1TvdT8r"}' | jq -r '.token')

# Generate/activate universal token
RESPONSE=$(curl -s -X GET "https://monitoring.inproma.de/api/beszel/universal-token?enable=1" \
  -H "Authorization: Bearer $AUTH_TOKEN")

echo "Universal Token Response: $RESPONSE"
# Copy the "token" value from the response
```

### Step 2: Install Agent with New Token

```bash
# Using environment variables (replace TOKEN with value from Step 1)
export BESZEL_HUB_URL='https://monitoring.inproma.de'
export BESZEL_TOKEN='PASTE-TOKEN-FROM-STEP-1-HERE'
export BESZEL_KEY='ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILG/StjM0ypoZOCqF+lLrqznYd4y45GKaKGOB6RbXc2H'
export BESZEL_AUTO_UPDATE='true'

curl -fsSL https://raw.githubusercontent.com/sebastian-fahrenkrog/beszel-monitoring/main/scripts/install-beszel-agent.sh | sudo -E bash -s -- install
```

**That's it!** The server will appear automatically in the dashboard at https://monitoring.inproma.de

### Alternative: Using Helper Script

```bash
# Clone repository and use helper script
git clone https://github.com/sebastian-fahrenkrog/beszel-monitoring.git
cd beszel-monitoring
./scripts/add-server.sh root@your-server.com
```

## Understanding Universal Tokens

### How They Work
Universal tokens in Beszel are **permanent API keys** that allow agents to auto-register with the hub:

- **Duration**: Tokens stay active indefinitely (auto-renew every hour when used)
- **Scope**: One token can be used for unlimited servers
- **Security**: Combined with SSH key verification for authentication
- **Automation**: Perfect for deployment scripts and infrastructure as code

### Token Lifecycle
```
Token Created → Agent Uses Token → Token Auto-Renews (1hr) → Stays Active Forever
                        ↑                                              ↓
                        └──────────────────────────────────────────────┘
```

As long as at least one agent connects within each hour, the token remains active indefinitely.

## Step-by-Step Guide

### 1. Prerequisites
- [ ] SSH access to the new server
- [ ] Root or sudo privileges
- [ ] Outbound HTTPS (port 443) allowed

### 2. Connect to Your New Server
```bash
ssh root@YOUR_NEW_SERVER
```

### 3. Run the Installation
```bash
# Option A: Direct execution (if you trust the network)
curl -sL https://raw.githubusercontent.com/henrygd/beszel/main/supplemental/scripts/install-agent.sh | \
  bash -s -- \
  -url "https://monitoring.inproma.de" \
  -t "c8a8c7a7-135a-4818-ad7a-0f8581aadc96" \
  -k "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILG/StjM0ypoZOCqF+lLrqznYd4y45GKaKGOB6RbXc2H" \
  --auto-update=true

# Option B: Download, review, then execute
curl -sL https://raw.githubusercontent.com/henrygd/beszel/main/supplemental/scripts/install-agent.sh -o install.sh
cat install.sh  # Review the script
bash install.sh \
  -url "https://monitoring.inproma.de" \
  -t "c8a8c7a7-135a-4818-ad7a-0f8581aadc96" \
  -k "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILG/StjM0ypoZOCqF+lLrqznYd4y45GKaKGOB6RbXc2H" \
  --auto-update=true
```

### 4. Verify Installation
```bash
# Check agent status
systemctl status beszel-agent

# View logs
journalctl -u beszel-agent -n 20

# Look for success message
# "INFO WebSocket connected host=monitoring.inproma.de"
```

### 5. Check Dashboard
Open https://monitoring.inproma.de and look for your new server. It will appear with its actual hostname from `/etc/hostname`.

## Real-World Example: ai.content-optimizer.de

Here's the actual output from successfully adding a production server:

```bash
# Installation command
ssh root@ai.content-optimizer.de
export BESZEL_HUB_URL='https://monitoring.inproma.de'
export BESZEL_TOKEN='c8a8c7a7-135a-4818-ad7a-0f8581aadc96'
export BESZEL_KEY='ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILG/StjM0ypoZOCqF+lLrqznYd4y45GKaKGOB6RbXc2H'
export BESZEL_AUTO_UPDATE='true'

curl -fsSL https://raw.githubusercontent.com/sebastian-fahrenkrog/beszel-monitoring/main/scripts/install-beszel-agent.sh | bash -s -- install
```

**Installation Output:**
```
======================================
   Beszel Agent Installer v1.0.0
======================================
Hub URL: https://monitoring.inproma.de
Mode: WebSocket (Agent-Initiated)
======================================

[INFO] Checking system compatibility...
[SUCCESS] System compatibility check passed
[INFO] Creating service user 'beszel'...
[SUCCESS] User 'beszel' created
[INFO] Adding 'beszel' to docker group for container monitoring...
[INFO] Downloading Beszel agent...
[SUCCESS] Agent downloaded and installed to /opt/beszel-agent
[INFO] Creating systemd service...
[SUCCESS] Systemd service created
[INFO] Setting up automatic updates...
[SUCCESS] Auto-update configured (daily at 3 AM)
[INFO] Starting Beszel agent service...
[SUCCESS] Beszel agent service is running
[INFO] Verifying WebSocket connection...
[SUCCESS] Agent connected to hub successfully!
[INFO] Hub URL: https://monitoring.inproma.de
[INFO] Agent will appear in dashboard with hostname: ai.content-optimizer.de

[SUCCESS] Installation complete!
```

**Server Details Detected:**
- **Hostname:** ai.content-optimizer.de
- **CPU:** 20 cores
- **Memory:** 62GB
- **GPU:** NVIDIA RTX 4000 SFF Ada Generation (automatically detected)
- **Docker:** Version 26.1.4 (monitoring enabled)

The server appeared instantly in the dashboard with full metrics including GPU monitoring!

## Automation Examples

### Ansible Playbook
```yaml
---
- name: Install Beszel Agent
  hosts: all
  become: yes
  tasks:
    - name: Install Beszel agent using secure self-hosted script
      shell: |
        export BESZEL_HUB_URL='https://monitoring.inproma.de'
        export BESZEL_TOKEN='c8a8c7a7-135a-4818-ad7a-0f8581aadc96'
        export BESZEL_KEY='ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILG/StjM0ypoZOCqF+lLrqznYd4y45GKaKGOB6RbXc2H'
        export BESZEL_AUTO_UPDATE='true'
        curl -fsSL https://raw.githubusercontent.com/sebastian-fahrenkrog/beszel-monitoring/main/scripts/install-beszel-agent.sh | bash -s -- install
      args:
        creates: /etc/systemd/system/beszel-agent.service
```

### Terraform Provisioner
```hcl
resource "null_resource" "beszel_agent" {
  connection {
    type     = "ssh"
    host     = aws_instance.server.public_ip
    user     = "root"
    private_key = file("~/.ssh/id_rsa")
  }

  provisioner "remote-exec" {
    inline = [
      "export BESZEL_HUB_URL='https://monitoring.inproma.de'",
      "export BESZEL_TOKEN='c8a8c7a7-135a-4818-ad7a-0f8581aadc96'",
      "export BESZEL_KEY='ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILG/StjM0ypoZOCqF+lLrqznYd4y45GKaKGOB6RbXc2H'",
      "export BESZEL_AUTO_UPDATE='true'",
      "curl -fsSL https://raw.githubusercontent.com/sebastian-fahrenkrog/beszel-monitoring/main/scripts/install-beszel-agent.sh | bash -s -- install"
    ]
  }
}
```

### Docker Init Script
```dockerfile
# In your Dockerfile or docker-compose
ENV BESZEL_HUB_URL='https://monitoring.inproma.de'
ENV BESZEL_TOKEN='c8a8c7a7-135a-4818-ad7a-0f8581aadc96'
ENV BESZEL_KEY='ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILG/StjM0ypoZOCqF+lLrqznYd4y45GKaKGOB6RbXc2H'
ENV BESZEL_AUTO_UPDATE='true'

RUN curl -fsSL https://raw.githubusercontent.com/sebastian-fahrenkrog/beszel-monitoring/main/scripts/install-beszel-agent.sh | bash -s -- install
```

### Cloud-Init (Ubuntu/Debian)
```yaml
#cloud-config
runcmd:
  - export BESZEL_HUB_URL='https://monitoring.inproma.de'
  - export BESZEL_TOKEN='c8a8c7a7-135a-4818-ad7a-0f8581aadc96'
  - export BESZEL_KEY='ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILG/StjM0ypoZOCqF+lLrqznYd4y45GKaKGOB6RbXc2H'
  - export BESZEL_AUTO_UPDATE='true'
  - curl -fsSL https://raw.githubusercontent.com/sebastian-fahrenkrog/beszel-monitoring/main/scripts/install-beszel-agent.sh | bash -s -- install
```

## Bulk Server Addition

### Script for Multiple Servers
Create a file `servers.txt`:
```
server1.example.com
server2.example.com
server3.example.com
```

Then run:
```bash
#!/bin/bash
# Use our secure self-hosted script for bulk installation
while IFS= read -r server; do
    echo "Installing on $server..."
    ssh root@"$server" '
        export BESZEL_HUB_URL="https://monitoring.inproma.de"
        export BESZEL_TOKEN="c8a8c7a7-135a-4818-ad7a-0f8581aadc96"
        export BESZEL_KEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILG/StjM0ypoZOCqF+lLrqznYd4y45GKaKGOB6RbXc2H"
        export BESZEL_AUTO_UPDATE="true"
        curl -fsSL https://raw.githubusercontent.com/sebastian-fahrenkrog/beszel-monitoring/main/scripts/install-beszel-agent.sh | bash -s -- install
    '
    echo "✓ $server completed"
done < servers.txt
```

## Managing Token Status

### Check Token Status
```bash
# Using the verification script
./verify_agent_connection.sh

# Or via API
AUTH_TOKEN=$(curl -s -X POST https://monitoring.inproma.de/api/collections/users/auth-with-password \
  -H "Content-Type: application/json" \
  -d '{"identity": "sebastian.fahrenkrog@gmail.com", "password": "gOACNFz1TvdT8r"}' | jq -r '.token')

curl -s -X GET "https://monitoring.inproma.de/api/beszel/universal-token" \
  -H "Authorization: Bearer $AUTH_TOKEN" | jq
```

### Reactivate Token (if needed)
```bash
# Usually not necessary, but if token becomes inactive:
curl -X GET "https://monitoring.inproma.de/api/beszel/universal-token?token=c8a8c7a7-135a-4818-ad7a-0f8581aadc96&enable=1" \
  -H "Authorization: Bearer $AUTH_TOKEN"
```

### Generate New Token
```bash
# Create a completely new token
curl -X GET "https://monitoring.inproma.de/api/beszel/universal-token?enable=1" \
  -H "Authorization: Bearer $AUTH_TOKEN"
```

## Server Naming

Servers will appear in the dashboard with their actual hostname from `/etc/hostname`. To customize:

### Option 1: Change Hostname Before Installation
```bash
hostnamectl set-hostname my-custom-name
# Then install agent
```

### Option 2: Set SYSTEM_NAME Environment Variable
```bash
# Edit after installation
systemctl edit beszel-agent

# Add:
[Service]
Environment="BESZEL_AGENT_SYSTEM_NAME=My Custom Name"

# Restart
systemctl restart beszel-agent
```

## Security Considerations

### Token Security
- **Treat tokens like passwords** - Don't commit to public repos
- **Use environment variables** in CI/CD pipelines
- **Rotate periodically** if compromised
- **Monitor usage** via dashboard for unexpected systems

### Network Security
- **Outbound only** - No inbound ports needed
- **TLS encrypted** - All communication over HTTPS/WSS
- **SSH key verification** - Additional authentication layer

## Troubleshooting

### Server Not Appearing
1. Check agent status: `systemctl status beszel-agent`
2. Check logs: `journalctl -u beszel-agent -f`
3. Verify token is active: `./verify_agent_connection.sh`
4. Check network connectivity: `curl -I https://monitoring.inproma.de`

### Common Issues
| Problem | Solution |
|---------|----------|
| "invalid signature" | Wrong SSH key - use key from id_ed25519 |
| "401 unauthorized" | Token inactive - reactivate via API |
| "connection refused" | Network issue - check outbound HTTPS |
| Different hostname | Normal - uses actual system hostname |

## Best Practices

1. **Use Configuration Management**: Integrate with Ansible, Puppet, Chef, etc.
2. **Document Server Purpose**: Use meaningful hostnames
3. **Monitor Token Usage**: Check dashboard for unexpected systems
4. **Automate Everything**: Include in server provisioning scripts
5. **Test First**: Try on non-production servers first

## FAQ

### Q: Can I use the same token forever?
**A:** Yes! Tokens auto-renew when used and stay active indefinitely.

### Q: How many servers can use one token?
**A:** Unlimited. One token can be used for all your servers.

### Q: Is it safe to hardcode the token?
**A:** For private automation scripts, yes. For public repos, use environment variables.

### Q: What if the token is compromised?
**A:** Deactivate it via API and generate a new one. Update all agents.

### Q: Do I need to open firewall ports?
**A:** No! Agents only make outbound HTTPS connections.

## Quick Reference Card

```bash
# Installation Command (save this!) - Using Secure Self-Hosted Script
export BESZEL_HUB_URL='https://monitoring.inproma.de'
export BESZEL_TOKEN='c8a8c7a7-135a-4818-ad7a-0f8581aadc96'
export BESZEL_KEY='ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILG/StjM0ypoZOCqF+lLrqznYd4y45GKaKGOB6RbXc2H'
export BESZEL_AUTO_UPDATE='true'
curl -fsSL https://raw.githubusercontent.com/sebastian-fahrenkrog/beszel-monitoring/main/scripts/install-beszel-agent.sh | sudo -E bash -s -- install

# Check Status
systemctl status beszel-agent

# View Logs
journalctl -u beszel-agent -f

# Restart Agent
systemctl restart beszel-agent

# Dashboard
https://monitoring.inproma.de
```

---

**Remember**: Adding a new server is as simple as running one command. The universal token and WebSocket architecture make it seamless!