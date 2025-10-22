# Adding Agent to Beszel Hub

## Steps to Add m.dev.testserver.online to Monitoring

### 1. Access Hub Web Interface
- Go to: https://monitoring.inproma.de
- Log in with your admin credentials

### 2. Add New System in Hub

In the Beszel Hub interface:

1. Look for **"Systems"**, **"Add System"**, or a **"+"** button
2. Click to add a new system
3. Enter the following information:
   - **Name**: m.dev.testserver.online (or any friendly name like "Test Server")
   - **Host/IP**: localhost (since we're using SSH tunnel)
   - **Port**: 45876

### 3. Get the Agent Token

After adding the system, Beszel will provide:
- A **token** or **key** for the agent
- Copy this token - it's unique for this agent

### 4. Configure Agent with Token

Once you have the token from the Hub, run this command (replace YOUR_TOKEN_HERE with the actual token):

```bash
ssh root@m.dev.testserver.online "cat > /etc/beszel/beszel-agent.env << 'EOF'
# Beszel Agent Configuration
PORT=45876
HOST=0.0.0.0
TOKEN=YOUR_TOKEN_HERE
AGENT_NAME=m.dev.testserver.online
LOG_LEVEL=info

# Hub Connection
HUB_URL=wss://monitoring.inproma.de/api/ws

# Docker Integration
DOCKER_HOST=unix:///var/run/docker.sock
DOCKER_ENABLED=true
EOF
systemctl restart beszel-agent"
```

### 5. Alternative: SSH-based Connection

If the Hub supports SSH-based agent connections:

1. In the Hub, choose **SSH connection** type
2. Use these settings:
   - **SSH Host**: m.dev.testserver.online
   - **SSH Port**: 22
   - **SSH User**: root
   - **Local Agent Port**: 45876
   - **SSH Key**: Already configured (Hub can SSH to agent server)

### 6. Verify Connection

After configuration:
1. Check agent logs: `ssh root@m.dev.testserver.online "journalctl -u beszel-agent -f"`
2. In the Hub web interface, the system should show as "Connected" or "Online"
3. Metrics should start appearing within a few seconds

## Current Setup Status

✅ **Agent is running** on m.dev.testserver.online:45876
✅ **SSH tunnel established** from Hub to Agent (localhost:45876)
✅ **Hub is accessible** at https://monitoring.inproma.de
⏳ **Waiting for**: Token from Hub to complete agent registration

## Quick Commands

```bash
# Check agent status
ssh root@m.dev.testserver.online "systemctl status beszel-agent"

# View agent logs
ssh root@m.dev.testserver.online "journalctl -u beszel-agent -f"

# Re-establish SSH tunnel if needed
ssh root@monitoring.inproma.de "/opt/beszel-hub/setup-tunnel.sh"

# Test tunnel connectivity
ssh root@monitoring.inproma.de "nc -zv localhost 45876"
```

## Notes

- The agent is currently listening for SSH connections on port 45876
- Due to external firewall, we're using SSH tunnel through port 22
- The tunnel makes the agent available at localhost:45876 on the Hub server
- The agent needs a token from the Hub to establish WebSocket connection