#!/bin/bash
# ==============================================================================
# Add GlobaLeaks Health Monitors to Uptime Kuma
# ==============================================================================
# This script adds HTTP health check monitors for all GlobaLeaks instances
# running on whistle-ranger.de servers to the Uptime Kuma monitoring system.
#
# Prerequisites:
# - Uptime Kuma running at uptime.inproma.de
# - Access to Uptime Kuma server via SSH
# - GlobaLeaks health endpoint accessible at https://SERVER:8443/api/health
#
# Usage:
#   ./add-globaleaks-monitors-uptime-kuma.sh
#
# ==============================================================================

set -e  # Exit on error

# Configuration
UPTIME_SERVER="uptime.inproma.de"
UPTIME_CONTAINER="uptime-kuma"
UPTIME_USERNAME="${UPTIME_USERNAME:-sebastian.fahrenkrog@gmail.com}"
UPTIME_PASSWORD="${UPTIME_PASSWORD:-Ht66idyvk9aDEm}"
HEALTH_PORT="8443"
HEALTH_PATH="/api/health"

# Color output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Servers to monitor
WHISTLE_SERVERS=(
  "mangal.whistle-ranger.de"
  "foodstar.whistle-ranger.de"
  "samtgemeinde-spelle.whistle-ranger.de"
  "just.whistle-ranger.de"
  "dama.whistle-ranger.de"
  "gekko.whistle-ranger.de"
  "rebo.whistle-ranger.de"
  "r-und-s.whistle-ranger.de"
  "lampe.whistle-ranger.de"
  "bl-kms.whistle-ranger.de"
  "shaffi-group.whistle-ranger.de"
  "why.whistle-ranger.de"
  "rp-timing.whistle-ranger.de"
  "rp-jessinghaus.whistle-ranger.de"
  "rp-leipzig.whistle-ranger.de"
  "rp-dortmund.whistle-ranger.de"
  "rp.whistle-ranger.de"
  "esslust.whistle-ranger.de"
  "hecking.whistle-ranger.de"
  "stage.whistle-ranger.de"
)

OTHER_SERVERS=(
  "whistleblower-bk.de"
  "prodsgvo-whistle.de"
)

# Combine all servers
ALL_SERVERS=("${WHISTLE_SERVERS[@]}" "${OTHER_SERVERS[@]}")

echo -e "${GREEN}===================================================================${NC}"
echo -e "${GREEN}  Adding GlobaLeaks Health Monitors to Uptime Kuma${NC}"
echo -e "${GREEN}===================================================================${NC}"
echo ""
echo "Uptime Kuma Server: $UPTIME_SERVER"
echo "Total Servers: ${#ALL_SERVERS[@]}"
echo ""

# Function to add a single monitor
add_monitor() {
  local server="$1"
  local url="https://${server}:${HEALTH_PORT}${HEALTH_PATH}"
  local monitor_name="${server} - GlobaLeaks"

  echo -e "${YELLOW}Adding monitor: ${monitor_name}${NC}"
  echo "  URL: $url"

  # Create Node.js script for Socket.io API call
  # Note: Triple backslashes for SSH -> Docker exec escaping
  local node_script="const io=require(\\\"socket.io-client\\\");
const s=io(\\\"http://localhost:3001\\\",{transports:[\\\"websocket\\\"]});
s.on(\\\"connect\\\",()=>{
  s.emit(\\\"login\\\",{username:\\\"${UPTIME_USERNAME}\\\",password:\\\"${UPTIME_PASSWORD}\\\"},(r)=>{
    if(r.ok){
      const monitor={
        type:\\\"http\\\",
        name:\\\"${monitor_name}\\\",
        url:\\\"${url}\\\",
        interval:60,
        retryInterval:60,
        maxretries:3,
        ignoreTls:true,
        upsideDown:false,
        maxredirects:0,
        accepted_statuscodes:[\\\"200\\\",\\\"401\\\"],
        timeout:10,
        method:\\\"GET\\\",
        active:true
      };
      s.emit(\\\"add\\\",monitor,(ar)=>{
        if(ar.ok){
          console.log(\\\"✅ Monitor added (ID: \\\"+ar.monitorID+\\\")\\\");
        }else{
          console.log(\\\"❌ Failed: \\\"+ar.msg);
        }
        s.close();
      });
    }else{
      console.log(\\\"❌ Login failed\\\");
      s.close();
    }
  });
});"

  # Execute via SSH and Docker exec
  if ssh "root@${UPTIME_SERVER}" "docker exec ${UPTIME_CONTAINER} node -e \"${node_script}\"" 2>&1; then
    echo -e "${GREEN}  ✅ Success${NC}"
  else
    echo -e "${RED}  ❌ Failed${NC}"
  fi

  echo ""
}

# Check SSH connectivity to Uptime Kuma server
echo "Checking connectivity to Uptime Kuma server..."
if ! ssh -o ConnectTimeout=5 "root@${UPTIME_SERVER}" 'exit' 2>/dev/null; then
  echo -e "${RED}❌ Cannot connect to ${UPTIME_SERVER} via SSH${NC}"
  echo "Please ensure:"
  echo "  1. SSH access is configured"
  echo "  2. Server is reachable"
  exit 1
fi
echo -e "${GREEN}✅ Connection successful${NC}"
echo ""

# Check if Uptime Kuma container is running
echo "Checking if Uptime Kuma container is running..."
if ! ssh "root@${UPTIME_SERVER}" "docker ps | grep -q ${UPTIME_CONTAINER}" 2>/dev/null; then
  echo -e "${RED}❌ Uptime Kuma container '${UPTIME_CONTAINER}' is not running${NC}"
  exit 1
fi
echo -e "${GREEN}✅ Container is running${NC}"
echo ""

# Add monitors
echo -e "${GREEN}===================================================================${NC}"
echo -e "${GREEN}  Adding Monitors${NC}"
echo -e "${GREEN}===================================================================${NC}"
echo ""

SUCCESS_COUNT=0
FAIL_COUNT=0

for server in "${ALL_SERVERS[@]}"; do
  if add_monitor "$server"; then
    ((SUCCESS_COUNT++))
  else
    ((FAIL_COUNT++))
  fi

  # Wait 2 seconds between additions to avoid overwhelming the system
  sleep 2
done

# Summary
echo -e "${GREEN}===================================================================${NC}"
echo -e "${GREEN}  Summary${NC}"
echo -e "${GREEN}===================================================================${NC}"
echo ""
echo "Total servers: ${#ALL_SERVERS[@]}"
echo -e "${GREEN}Successfully added: ${SUCCESS_COUNT}${NC}"
if [ $FAIL_COUNT -gt 0 ]; then
  echo -e "${RED}Failed: ${FAIL_COUNT}${NC}"
fi
echo ""
echo -e "${GREEN}✅ Monitor addition complete!${NC}"
echo ""
echo "Next steps:"
echo "  1. Visit https://uptime.inproma.de"
echo "  2. Verify all monitors are showing up"
echo "  3. Check monitor status (green = healthy)"
echo "  4. Configure notification channels if not already set up"
echo ""
echo "To test alerts:"
echo "  ssh root@stage.whistle-ranger.de"
echo "  systemctl stop globaleaks"
echo "  # Wait 2-3 minutes for alert"
echo "  systemctl start globaleaks"
echo ""
