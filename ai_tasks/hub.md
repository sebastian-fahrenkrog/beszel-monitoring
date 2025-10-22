# Beszel Hub and Agent Installation Plan

## Project Overview
Deploy Beszel monitoring system with:
- **Hub Server**: monitoring.inproma.de (Docker deployment)
- **Agent Server**: m.dev.testserver.online (Linux systemd service)
- **Connection**: Agent reports to hub for centralized monitoring

## Phase 1: Hub Installation on monitoring.inproma.de

### 1.1 Prerequisites Check
```bash
# Connect to hub server
ssh root@monitoring.inproma.de

# Check Docker installation
docker --version
# If not installed:
curl -fsSL https://get.docker.com | sh

# Check Docker Compose
docker compose version
# If not installed:
apt-get update && apt-get install -y docker-compose-plugin

# Verify ports availability
ss -tulpn | grep 8090
# Ensure port 8090 is free
```

### 1.2 Create Hub Directory Structure
```bash
# Create Beszel hub directory
mkdir -p /opt/beszel-hub
cd /opt/beszel-hub

# Create data directory for persistent storage
mkdir -p beszel_data
```

### 1.3 Create Docker Compose Configuration
```bash
# Create docker-compose.yml
cat > docker-compose.yml <<'EOF'
services:
  beszel:
    image: 'henrygd/beszel:latest'
    container_name: 'beszel-hub'
    restart: unless-stopped
    ports:
      - '8090:8090'
    volumes:
      - ./beszel_data:/beszel_data
    environment:
      # Optional: Set custom admin credentials
      # ADMIN_USER: admin@example.com
      # ADMIN_PASS: secure_password_here
      
      # Optional: Enable automatic backups
      # BACKUP_ENABLED: true
      # BACKUP_SCHEDULE: "0 2 * * *"  # Daily at 2 AM
      
      # Optional: S3 backup configuration
      # BACKUP_S3_ENABLED: false
      # BACKUP_S3_BUCKET: beszel-backups
      # BACKUP_S3_REGION: eu-central-1
      # BACKUP_S3_ACCESS_KEY: your_access_key
      # BACKUP_S3_SECRET_KEY: your_secret_key
EOF
```

### 1.4 Deploy Hub Container
```bash
# Pull latest image
docker compose pull

# Start hub service
docker compose up -d

# Verify container is running
docker compose ps
docker compose logs -f beszel-hub

# Wait for initialization (check logs for "Server started" message)
```

### 1.5 Configure Firewall
```bash
# Allow port 8090 for web interface
ufw allow 8090/tcp comment "Beszel Hub Web Interface"

# If using iptables directly:
iptables -A INPUT -p tcp --dport 8090 -j ACCEPT -m comment --comment "Beszel Hub"
iptables-save > /etc/iptables/rules.v4
```

### 1.6 Initial Hub Setup
```bash
# Access web interface
echo "Access Beszel Hub at: http://monitoring.inproma.de:8090"

# Default login:
# Email: admin@example.com (or custom if set)
# Password: (set during first login or via environment)

# Important first steps in web UI:
# 1. Change admin password
# 2. Create SSH key pair for agent connections
# 3. Note down the public key for agent setup
```

### 1.7 Get SSH Key for Agent Authentication
```bash
# IMPORTANT: The hub automatically creates id_ed25519 on first start
# Extract the public key from the existing private key:
ssh-keygen -y -f /opt/beszel-hub/beszel_data/id_ed25519

# This will output something like:
# ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILG/StjM0ypoZOCqF+lLrqznYd4y45GKaKGOB6RbXc2H

# Copy this public key for agent configuration
# Do NOT use agent_key.pub if it exists - that's for a different purpose
```

### 1.8 Create Universal Token for Agent Auto-Registration
```bash
# Universal tokens allow agents to auto-register without pre-configuration

# Get auth token for API
AUTH_TOKEN=$(curl -s -X POST https://monitoring.inproma.de/api/collections/users/auth-with-password \
  -H "Content-Type: application/json" \
  -d '{"identity": "admin@example.com", "password": "YOUR_PASSWORD"}' | jq -r '.token')

# Create and activate universal token
curl -X GET "https://monitoring.inproma.de/api/beszel/universal-token?enable=1" \
  -H "Authorization: Bearer $AUTH_TOKEN" | jq

# Response will include the token:
# {"active": true, "token": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"}
```

## Phase 2: Agent Installation on m.dev.testserver.online

### 2.1 Prerequisites Check
```bash
# Connect to agent server
ssh root@m.dev.testserver.online

# Check system info
uname -a
lsb_release -a

# Check for systemd
systemctl --version

# Check Docker (if container monitoring needed)
docker --version || echo "Docker not installed - container monitoring unavailable"
```

### 2.2 Agent Installation with WebSocket Mode (Recommended)
```bash
# Get or create a universal token from hub API first (see Phase 1.8)
# Then install agent with WebSocket configuration:

# Set variables (replace with your values)
HUB_URL="https://monitoring.inproma.de"
TOKEN="YOUR_UNIVERSAL_TOKEN"
KEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI..."  # From hub's id_ed25519

# Install with WebSocket mode
curl -sL https://raw.githubusercontent.com/henrygd/beszel/main/supplemental/scripts/install-agent.sh | \
  bash -s -- \
  -url "$HUB_URL" \
  -t "$TOKEN" \
  -k "$KEY" \
  --auto-update=true
```

### 2.3 Configure Agent Connection
```bash
# Edit agent configuration
nano /etc/beszel/beszel-agent.env

# Add/modify these settings:
cat > /etc/beszel/beszel-agent.env <<'EOF'
# Hub connection details
KEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI..."  # Public key from hub
PORT=45876
HOST=0.0.0.0

# Optional: Custom agent name
# AGENT_NAME="TestServer-Dev"

# Optional: Docker monitoring
# DOCKER_HOST="unix:///var/run/docker.sock"
EOF

# Set proper permissions
chmod 600 /etc/beszel/beszel-agent.env
chown beszel:beszel /etc/beszel/beszel-agent.env
```

### 2.4 Configure Systemd Service
```bash
# Review service file
cat /etc/systemd/system/beszel-agent.service

# If needed, create override for custom settings
systemctl edit beszel-agent

# Add any custom configurations:
# [Service]
# Environment="LOG_LEVEL=debug"
# RestartSec=10
```

### 2.5 Enable Docker Monitoring (Optional)
```bash
# Add beszel user to docker group
usermod -aG docker beszel

# Verify docker socket permissions
ls -la /var/run/docker.sock

# Test docker access
sudo -u beszel docker ps
```

### 2.6 Start Agent Service
```bash
# Reload systemd
systemctl daemon-reload

# Enable auto-start on boot
systemctl enable beszel-agent

# Start agent
systemctl start beszel-agent

# Check status
systemctl status beszel-agent

# Monitor logs
journalctl -u beszel-agent -f
```

### 2.7 Configure Firewall
```bash
# Allow agent port
ufw allow 45876/tcp comment "Beszel Agent"

# Or with iptables:
iptables -A INPUT -p tcp --dport 45876 -j ACCEPT -m comment --comment "Beszel Agent"
iptables-save > /etc/iptables/rules.v4
```

## Phase 3: Add Server to Beszel Hub

### 3.1 Access Hub Web Interface
```bash
# Open browser to:
http://monitoring.inproma.de:8090

# Login with admin credentials
```

### 3.2 Add New System
```
1. Navigate to "Systems" or "Servers" section
2. Click "Add System" or "+" button
3. Fill in system details:
   - Name: "TestServer Dev"
   - Host: "m.dev.testserver.online"
   - Port: 45876
   - SSH User: "root" (for SSH-based connection)
   - Connection Type: "Direct" or "SSH"
   
4. For Direct Connection:
   - Use the agent's listening address
   - Ensure firewall allows hub → agent communication
   
5. For SSH Connection:
   - Provide SSH credentials
   - Hub will tunnel through SSH to reach agent
```

### 3.3 Configure Agent Connection in Hub
```bash
# Option A: Direct WebSocket Connection
# In hub web interface:
# - Connection URL: ws://m.dev.testserver.online:45876
# - Authentication: Use generated key pair

# Option B: SSH Tunnel Connection
# - SSH Host: m.dev.testserver.online
# - SSH User: root
# - SSH Port: 22
# - Agent Port: 45876 (localhost on remote)
```

### 3.4 Test Connection
```
1. After adding system, click "Test Connection"
2. Verify metrics are being received:
   - CPU usage
   - Memory usage
   - Disk usage
   - Network statistics
   - Container stats (if Docker available)
   
3. Check agent logs on server:
   ssh root@m.dev.testserver.online
   journalctl -u beszel-agent -n 50
```

## Phase 4: Verification and Monitoring

### 4.1 Verify Hub Operation
```bash
# On monitoring.inproma.de
docker compose logs beszel-hub
docker stats beszel-hub

# Check data persistence
ls -la /opt/beszel-hub/beszel_data/
```

### 4.2 Verify Agent Operation
```bash
# On m.dev.testserver.online
systemctl status beszel-agent
journalctl -u beszel-agent --since "10 minutes ago"

# Check resource usage
ps aux | grep beszel
netstat -tlnp | grep 45876
```

### 4.3 Configure Alerts (Web Interface)
```
1. Navigate to Alerts section
2. Create alert rules:
   - CPU > 80% for 5 minutes
   - Memory > 90%
   - Disk > 85%
   - Agent offline for 2 minutes
   
3. Configure notifications:
   - Email notifications
   - Webhook integrations
   - Slack/Discord webhooks
```

### 4.4 Setup Dashboards
```
1. Access main dashboard
2. Customize views:
   - Add/remove metric widgets
   - Configure refresh intervals
   - Set time ranges
   
3. Create custom dashboards:
   - Group related servers
   - Focus on specific metrics
   - Export/import dashboard configs
```

## Phase 5: Maintenance and Updates

### 5.1 Hub Updates
```bash
# On monitoring.inproma.de
cd /opt/beszel-hub

# Backup data
tar -czf beszel_backup_$(date +%Y%m%d).tar.gz beszel_data/

# Update container
docker compose pull
docker compose down
docker compose up -d

# Verify update
docker compose logs beszel-hub | grep version
```

### 5.2 Agent Updates
```bash
# On m.dev.testserver.online

# Stop agent
systemctl stop beszel-agent

# Download new version
curl -L https://github.com/henrygd/beszel/releases/latest/download/beszel-agent_linux_amd64.tar.gz -o /tmp/beszel-agent.tar.gz
cd /tmp && tar -xzf beszel-agent.tar.gz

# Backup old binary
mv /usr/local/bin/beszel-agent /usr/local/bin/beszel-agent.backup

# Install new binary
mv beszel-agent /usr/local/bin/
chmod +x /usr/local/bin/beszel-agent

# Restart service
systemctl start beszel-agent
systemctl status beszel-agent
```

## Troubleshooting Guide

### Common Issues and Solutions

#### Hub Cannot Connect to Agent
```bash
# Check network connectivity
ping m.dev.testserver.online
telnet m.dev.testserver.online 45876

# Verify agent is listening
ss -tlnp | grep 45876

# Check firewall rules
iptables -L -n | grep 45876
ufw status verbose
```

#### Agent Not Reporting Metrics
```bash
# Check agent logs
journalctl -u beszel-agent -n 100

# Verify configuration
cat /etc/beszel/beszel-agent.env

# Test local agent endpoint
curl http://localhost:45876/health
```

#### High Resource Usage
```bash
# Hub optimization
docker exec beszel-hub sh -c "top"
docker stats beszel-hub

# Agent optimization
systemctl status beszel-agent --no-pager -l
ps aux | grep beszel-agent
```

#### Data Persistence Issues
```bash
# Check volume mounts
docker inspect beszel-hub | jq '.[0].Mounts'

# Verify permissions
ls -la /opt/beszel-hub/beszel_data/

# Database maintenance
docker exec beszel-hub sh -c "cd /beszel_data && sqlite3 data.db 'VACUUM;'"
```

## Security Considerations

### 1. Network Security
- Use firewall rules to restrict access
- Consider VPN or SSH tunneling for agent connections
- Enable HTTPS with reverse proxy (nginx/traefik)

### 2. Authentication
- Strong passwords for hub admin
- Rotate SSH keys periodically
- Use OAuth/OIDC if available

### 3. Data Protection
- Regular backups of hub data
- Encrypt backups before storage
- Monitor access logs

### 4. System Hardening
- Run services as non-root users
- Use read-only mounts where possible
- Keep systems and Docker updated

## Completion Checklist

- [ ] Hub installed on monitoring.inproma.de
- [ ] Hub accessible via web interface
- [ ] Admin password changed
- [ ] SSH key pair generated
- [ ] Agent installed on m.dev.testserver.online  
- [ ] Agent service running and enabled
- [ ] Firewall rules configured
- [ ] Server added to hub
- [ ] Metrics being collected
- [ ] Alerts configured
- [ ] Backup strategy implemented
- [ ] Documentation updated

## Notes
- Default hub port: 8090
- Default agent port: 45876
- Data stored in: /beszel_data (container) or /opt/beszel-hub/beszel_data (host)
- Logs available via: `docker compose logs` (hub) or `journalctl` (agent)
- Support available at: https://github.com/henrygd/beszel/issues