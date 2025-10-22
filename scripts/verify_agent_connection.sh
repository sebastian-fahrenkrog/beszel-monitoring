#!/bin/bash

# Script to verify Beszel agent connection from hub side

echo "======================================"
echo "Beszel Agent Connection Verification"
echo "======================================"

# API credentials - Load from environment
API_URL="${BESZEL_HUB_URL:-https://monitoring.inproma.de}"
EMAIL="${BESZEL_ADMIN_EMAIL:-}"
PASSWORD="${BESZEL_ADMIN_PASSWORD:-}"

# Check if credentials are provided
if [ -z "$EMAIL" ] || [ -z "$PASSWORD" ]; then
    echo "❌ Error: BESZEL_ADMIN_EMAIL and BESZEL_ADMIN_PASSWORD must be set"
    echo "   Set them as environment variables or source a .env file"
    exit 1
fi

# Get auth token
echo "Authenticating with hub..."
AUTH_TOKEN=$(curl -s -X POST "$API_URL/api/collections/users/auth-with-password" \
  -H "Content-Type: application/json" \
  -d "{\"identity\": \"$EMAIL\", \"password\": \"$PASSWORD\"}" | jq -r '.token')

if [ -z "$AUTH_TOKEN" ] || [ "$AUTH_TOKEN" = "null" ]; then
    echo "❌ Failed to authenticate with hub"
    exit 1
fi

echo "✅ Authentication successful"

# Check universal token status
echo ""
echo "Checking universal token status..."
UNIVERSAL_TOKEN=$(curl -s -X GET "$API_URL/api/beszel/universal-token" \
  -H "Authorization: Bearer $AUTH_TOKEN" | jq -r '.token')

echo "Universal token: $UNIVERSAL_TOKEN"

# Get list of systems
echo ""
echo "Fetching connected systems..."
SYSTEMS=$(curl -s -X GET "$API_URL/api/collections/systems/records" \
  -H "Authorization: Bearer $AUTH_TOKEN")

echo ""
echo "Connected Systems:"
echo "=================="
echo "$SYSTEMS" | jq -r '.items[] | "\(.name) - Host: \(.host) - Status: \(.status // "unknown")"' 2>/dev/null || echo "No systems found"

# Check for the agent (can be registered as hosting.dev.testserver.online or m.dev.testserver.online)
echo ""
TARGET_HOST="116.203.243.212"
if echo "$SYSTEMS" | grep -qE "(hosting\.dev\.testserver\.online|m\.dev\.testserver\.online|$TARGET_HOST)"; then
    echo "✅ Agent is registered!"
    
    # Get system details (check by IP or name)
    SYSTEM_ID=$(echo "$SYSTEMS" | jq -r ".items[] | select(.host == \"$TARGET_HOST\" or .name == \"hosting.dev.testserver.online\" or .name == \"m.dev.testserver.online\") | .id" | head -1)
    
    if [ -n "$SYSTEM_ID" ]; then
        echo "System ID: $SYSTEM_ID"
        
        # Try to get recent stats
        echo ""
        echo "Attempting to fetch recent metrics..."
        STATS=$(curl -s -X GET "$API_URL/api/collections/system_stats/records?filter=(system='$SYSTEM_ID')&sort=-created&perPage=1" \
          -H "Authorization: Bearer $AUTH_TOKEN")
        
        if [ "$(echo "$STATS" | jq -r '.items | length')" -gt 0 ]; then
            echo "✅ Metrics are being collected!"
            echo ""
            echo "Latest metrics:"
            echo "$STATS" | jq -r '.items[0] | "Timestamp: \(.created)\nCPU: \(.cpu // "N/A")%\nMemory: \(.memory // "N/A")%"'
        else
            echo "⚠️ No metrics found yet (agent may have just connected)"
        fi
    fi
else
    echo "⚠️ Agent not found in systems list"
    echo "This is normal if the agent hasn't connected yet."
    echo ""
    echo "With universal tokens, the agent will automatically register when it connects."
    echo "The system may appear as 'hosting.dev.testserver.online' based on its hostname."
fi

echo ""
echo "======================================"
echo "Hub Dashboard: $API_URL"
echo "======================================"