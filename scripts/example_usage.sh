#!/bin/bash

# ==============================================================================
# Example Usage of add-server-auto.sh
# ==============================================================================
# This file shows various ways to use the automated server addition script
# ==============================================================================

# Example 1: Add a single server
echo "Example 1: Add single server"
echo "Command: ./add-server-auto.sh root@example.com"
echo ""

# Example 2: Add multiple servers at once
echo "Example 2: Add multiple servers"
echo "Command: ./add-server-auto.sh root@server1.com root@server2.com root@server3.com"
echo ""

# Example 3: Add servers from a file
echo "Example 3: Add servers from a file"
cat << 'EOF'
# Create servers.txt file
cat > servers.txt << 'SERVERS'
root@web01.example.com
root@web02.example.com
root@db01.example.com
root@cache01.example.com
SERVERS

# Add all servers from file
./add-server-auto.sh $(cat servers.txt)
EOF
echo ""

# Example 4: Add server with verification
echo "Example 4: Add server and verify connection"
echo "Command: ./add-server-auto.sh --verify root@example.com"
echo ""

# Example 5: List all monitored servers
echo "Example 5: List all monitored servers"
echo "Command: ./add-server-auto.sh --list"
echo ""

# Example 6: Using custom credentials
echo "Example 6: Using custom hub credentials"
cat << 'EOF'
export BESZEL_HUB_URL="https://monitoring.example.com"
export BESZEL_ADMIN_EMAIL="admin@example.com"
export BESZEL_ADMIN_PASSWORD="your-password"

./add-server-auto.sh root@new-server.com
EOF
echo ""

# Example 7: Batch installation with loop
echo "Example 7: Batch installation with loop (for many servers)"
cat << 'EOF'
# Array of servers
SERVERS=(
    "root@server1.example.com"
    "root@server2.example.com"
    "root@server3.example.com"
    "root@server4.example.com"
    "root@server5.example.com"
)

# Add all servers
./add-server-auto.sh "${SERVERS[@]}"

# Or add in smaller batches (recommended for 10+ servers)
for server in "${SERVERS[@]}"; do
    echo "Adding $server..."
    ./add-server-auto.sh "$server"
    sleep 2  # Wait between installations
done
EOF
echo ""

# Example 8: Parallel installation for speed
echo "Example 8: Parallel installation (advanced)"
cat << 'EOF'
# Install on 5 servers simultaneously
parallel -j 5 './add-server-auto.sh {}' ::: \
    root@server1.com \
    root@server2.com \
    root@server3.com \
    root@server4.com \
    root@server5.com

# Note: Requires GNU parallel to be installed
# Install: sudo apt-get install parallel
EOF
echo ""

# Example 9: Add server with specific SSH port
echo "Example 9: Add server with custom SSH port"
echo "Command: ./add-server-auto.sh root@example.com:2222"
echo ""

# Example 10: Error handling and logging
echo "Example 10: Add servers with error handling and logging"
cat << 'EOF'
#!/bin/bash

LOG_FILE="server-additions-$(date +%Y%m%d-%H%M%S).log"

SERVERS=(
    "root@server1.com"
    "root@server2.com"
    "root@server3.com"
)

echo "Starting server additions at $(date)" | tee -a "$LOG_FILE"

for server in "${SERVERS[@]}"; do
    echo "--------------------------------" | tee -a "$LOG_FILE"
    echo "Adding $server..." | tee -a "$LOG_FILE"

    if ./add-server-auto.sh "$server" 2>&1 | tee -a "$LOG_FILE"; then
        echo "✅ $server added successfully" | tee -a "$LOG_FILE"
    else
        echo "❌ $server failed to add" | tee -a "$LOG_FILE"
    fi
done

echo "Completed at $(date)" | tee -a "$LOG_FILE"
echo "Log file: $LOG_FILE"
EOF
echo ""

# Example 11: Real-world scenario - Add whistle-ranger servers
echo "Example 11: Real-world scenario - Add whistle-ranger.de servers"
cat << 'EOF'
#!/bin/bash

# Array of whistle-ranger.de servers
WHISTLE_SERVERS=(
    "root@mangal.whistle-ranger.de"
    "root@foodstar.whistle-ranger.de"
    "root@samtgemeinde-spelle.whistle-ranger.de"
    "root@just.whistle-ranger.de"
    "root@dama.whistle-ranger.de"
)

# Add all servers with verification
echo "Adding ${#WHISTLE_SERVERS[@]} whistle-ranger.de servers..."
./add-server-auto.sh --verify "${WHISTLE_SERVERS[@]}"

# Check results
./add-server-auto.sh --list | grep whistle-ranger
EOF
echo ""

echo "===================================="
echo "To run any of these examples:"
echo "1. Navigate to scripts/ directory"
echo "2. Make script executable: chmod +x add-server-auto.sh"
echo "3. Run the desired command"
echo "===================================="
