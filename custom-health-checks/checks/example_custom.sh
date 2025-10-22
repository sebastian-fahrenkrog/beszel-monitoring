#!/bin/bash
# Example custom health check script
# This script can be written in any language - just output JSON

# Get environment variables
URL="${CHECK_URL:-http://localhost:8080/health}"
TIMEOUT="${CHECK_TIMEOUT:-5}"

# Perform the check
response=$(curl -s -o /dev/null -w "%{http_code}" --max-time "$TIMEOUT" "$URL" 2>/dev/null)

# Evaluate result
if [[ "$response" == "200" ]]; then
    status="ok"
    message="Service is healthy"
    exit_code=0
elif [[ "$response" == "000" ]]; then
    status="critical"
    message="Service is not responding"
    exit_code=2
else
    status="warning"
    message="Service returned HTTP $response"
    exit_code=1
fi

# Output JSON
cat << EOF
{
  "status": "$status",
  "message": "$message",
  "value": $response,
  "unit": "http_status",
  "details": {
    "url": "$URL",
    "response_code": $response
  }
}
EOF

exit $exit_code