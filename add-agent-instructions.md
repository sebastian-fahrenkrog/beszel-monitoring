# How to Add the Agent to Beszel Hub

## Manual Addition Through Web Interface

1. **Access the Hub**
   - Go to: https://monitoring.inproma.de
   - Log in with your admin credentials

2. **Add New System**
   - Look for "Systems", "Servers", or "Add System" button (usually a + icon)
   - Click to add a new system

3. **Configure the Agent Connection**

   Since we're using an SSH tunnel, use these settings:

   **Option A - Direct Connection via Tunnel:**
   - **Name**: m.dev.testserver.online (or any friendly name)
   - **Host**: localhost (or 127.0.0.1)
   - **Port**: 45876
   - **Public Key**: Use the key we generated
   ```
   ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIK9XX9+vRxPv+qyrSa0BPBwB0RGGti49eRtPqulz4lpC beszel-agent
   ```

   **Option B - SSH Connection:**
   - **Name**: m.dev.testserver.online
   - **SSH Host**: m.dev.testserver.online
   - **SSH Port**: 22
   - **SSH User**: root
   - **Agent Port**: 45876

4. **Test Connection**
   - After adding, click "Test Connection" or similar
   - You should see metrics starting to flow

## If the Above Doesn't Work

The agent might be expecting a different connection method. Let me check the agent configuration...
