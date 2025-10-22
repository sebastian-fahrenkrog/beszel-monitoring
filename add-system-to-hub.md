# How to Add m.dev.testserver.online to Beszel Hub

## Understanding Beszel Architecture

Beszel uses SSH-based authentication where:
1. The Hub connects to agents via SSH on their configured port (45876)
2. The agent authenticates using SSH public keys
3. Metrics are collected over this SSH connection

## Current Setup Status

✅ **Agent is running** on m.dev.testserver.online port 45876
✅ **SSH key generated** on Hub at `/opt/beszel-hub/beszel_data/agent_key`
✅ **Hub has SSH access** to m.dev.testserver.online on port 22
⚠️ **Problem**: External firewall blocks port 45876

## Solution: Use SSH Jump/Proxy

Since port 45876 is blocked by external firewall, you need to add the system using SSH proxy through port 22.

### Steps in Hub Web Interface:

1. **Log into https://monitoring.inproma.de**

2. **Add New System** - Look for:
   - "Systems" or "Servers" section
   - "+" or "Add System" button

3. **Configure the System** with these settings:

   **System Details:**
   - **Name**: Test Server (or any friendly name)
   - **Host**: m.dev.testserver.online
   
   **Connection Method:**
   - **Type**: SSH Connection
   - **SSH Host**: m.dev.testserver.online
   - **SSH Port**: 22
   - **SSH User**: root
   - **Agent Port**: 45876 (on localhost after SSH)
   
   **Authentication:**
   - **Use existing SSH key**: The hub already has SSH access to the agent server
   - Or you might need to specify the key path: `/opt/beszel-hub/beszel_data/agent_key`

4. **Alternative Configuration** (if direct SSH option exists):
   - **SSH Command**: `ssh -p 22 root@m.dev.testserver.online -L 45876:localhost:45876`
   - This creates the tunnel and connects to the agent

## Manual Test (if needed)

You can test the connection manually:

```bash
# From the Hub server, test SSH + agent connection
ssh root@monitoring.inproma.de
ssh -p 22 root@m.dev.testserver.online "nc -zv localhost 45876"
```

If this works (shows "succeeded"), the Hub should be able to connect.

## If the Hub Doesn't Support SSH Proxy

We may need to:
1. Create a permanent SSH tunnel (as a service)
2. Add the system as "localhost:45876" in the Hub

Let me know what options you see in the "Add System" interface!

## Quick Debug Commands

```bash
# Check agent is running
ssh root@m.dev.testserver.online "systemctl status beszel-agent"

# Check agent is listening
ssh root@m.dev.testserver.online "ss -tlnp | grep 45876"

# Check Hub's SSH access to agent server
ssh root@monitoring.inproma.de "ssh root@m.dev.testserver.online echo 'SSH works'"
```

## Expected Result

Once properly configured, you should see:
- System appears as "Online" or "Connected" in Hub
- CPU, Memory, Disk metrics start appearing
- Docker container stats (if any containers are running)

## Current Agent Status

The agent is running with SSH authentication mode:
- Listening on port 45876 for SSH connections
- Using public key: `ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIK9XX9+vRxPv+qyrSa0BPBwB0RGGti49eRtPqulz4lpC beszel-agent`
- Ready to accept connections from the Hub