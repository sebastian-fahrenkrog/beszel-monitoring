#!/bin/bash

# Beszel Configuration Management Script
# Manages config.yml for system definitions

set -e

# Configuration
HUB_URL="${BESZEL_HUB_URL:-https://monitoring.inproma.de}"
CONFIG_FILE="config.yml"
BACKUP_DIR="backups"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to display help
show_help() {
    echo "Beszel Configuration Manager"
    echo ""
    echo "Usage: $0 [command]"
    echo ""
    echo "Commands:"
    echo "  export    - Export current system configuration from hub to config.yml"
    echo "  import    - Import config.yml to hub (WARNING: Will sync systems)"
    echo "  backup    - Create backup of current configuration"
    echo "  validate  - Validate config.yml syntax"
    echo "  diff      - Show differences between hub and config.yml"
    echo "  help      - Show this help message"
    echo ""
}

# Function to get auth token
get_auth_token() {
    local email="${BESZEL_ADMIN_EMAIL:-}"
    local password="${BESZEL_ADMIN_PASSWORD:-}"
    
    if [ -z "$email" ] || [ -z "$password" ]; then
        echo -e "${RED}Error: BESZEL_ADMIN_EMAIL and BESZEL_ADMIN_PASSWORD must be set${NC}"
        echo -e "${YELLOW}Set them as environment variables or in a .env file${NC}"
        exit 1
    fi
    
    AUTH_TOKEN=$(curl -s -X POST "$HUB_URL/api/collections/users/auth-with-password" \
        -H "Content-Type: application/json" \
        -d "{\"identity\": \"$email\", \"password\": \"$password\"}" | jq -r '.token')
    
    if [ -z "$AUTH_TOKEN" ] || [ "$AUTH_TOKEN" = "null" ]; then
        echo -e "${RED}Error: Failed to authenticate with hub${NC}"
        exit 1
    fi
}

# Function to export current configuration
export_config() {
    echo "Exporting current system configuration from hub..."
    get_auth_token
    
    # Create backup first
    if [ -f "$CONFIG_FILE" ]; then
        mkdir -p "$BACKUP_DIR"
        cp "$CONFIG_FILE" "$BACKUP_DIR/config_$(date +%Y%m%d_%H%M%S).yml"
        echo -e "${GREEN}Created backup of existing config.yml${NC}"
    fi
    
    # Get systems from hub
    SYSTEMS=$(curl -s -X GET "$HUB_URL/api/collections/systems/records" \
        -H "Authorization: Bearer $AUTH_TOKEN")
    
    # Generate YAML
    cat > "$CONFIG_FILE" << 'HEADER'
# Beszel Systems Configuration
# Generated: $(date)
# This file manages system definitions for the Beszel monitoring platform
# Systems defined here will be synchronized with the database on restart
# WARNING: Systems not defined here will be deleted from the database!

systems:
HEADER
    
    echo "$SYSTEMS" | jq -r '.items[] | "  - name: \"\(.name)\"
    host: \"\(.host)\"
    port: \"\(.port)\"
    status: \"\(.status)\"
    # ID: \(.id)"' >> "$CONFIG_FILE"
    
    echo -e "${GREEN}Configuration exported to $CONFIG_FILE${NC}"
    
    # Show summary
    SYSTEM_COUNT=$(echo "$SYSTEMS" | jq '.items | length')
    echo "Exported $SYSTEM_COUNT system(s)"
}

# Function to validate YAML syntax
validate_config() {
    echo "Validating config.yml syntax..."
    
    if ! [ -f "$CONFIG_FILE" ]; then
        echo -e "${RED}Error: $CONFIG_FILE not found${NC}"
        exit 1
    fi
    
    # Check if yq is installed
    if command -v yq &> /dev/null; then
        if yq eval '.' "$CONFIG_FILE" > /dev/null 2>&1; then
            echo -e "${GREEN}✓ YAML syntax is valid${NC}"
            
            # Count systems
            SYSTEM_COUNT=$(yq eval '.systems | length' "$CONFIG_FILE")
            echo "Found $SYSTEM_COUNT system(s) in configuration"
            
            # List systems
            echo ""
            echo "Systems defined:"
            yq eval '.systems[].name' "$CONFIG_FILE" | while read -r name; do
                echo "  - $name"
            done
        else
            echo -e "${RED}✗ YAML syntax error${NC}"
            exit 1
        fi
    else
        echo -e "${YELLOW}Warning: yq not installed, skipping YAML validation${NC}"
        echo "Install with: brew install yq (macOS) or apt-get install yq (Linux)"
    fi
}

# Function to show differences
show_diff() {
    echo "Comparing hub configuration with config.yml..."
    get_auth_token
    
    if ! [ -f "$CONFIG_FILE" ]; then
        echo -e "${RED}Error: $CONFIG_FILE not found${NC}"
        exit 1
    fi
    
    # Get current systems from hub
    CURRENT_SYSTEMS=$(curl -s -X GET "$HUB_URL/api/collections/systems/records" \
        -H "Authorization: Bearer $AUTH_TOKEN" | jq -r '.items[].name' | sort)
    
    # Get systems from config.yml
    if command -v yq &> /dev/null; then
        CONFIG_SYSTEMS=$(yq eval '.systems[].name' "$CONFIG_FILE" | sort)
    else
        echo -e "${YELLOW}Warning: yq not installed, cannot parse YAML${NC}"
        exit 1
    fi
    
    echo ""
    echo "Systems in Hub:"
    echo "$CURRENT_SYSTEMS" | sed 's/^/  - /'
    
    echo ""
    echo "Systems in config.yml:"
    echo "$CONFIG_SYSTEMS" | sed 's/^/  - /'
    
    # Find differences
    echo ""
    echo "Differences:"
    
    # Systems only in hub
    ONLY_HUB=$(comm -23 <(echo "$CURRENT_SYSTEMS") <(echo "$CONFIG_SYSTEMS"))
    if [ -n "$ONLY_HUB" ]; then
        echo -e "${YELLOW}Only in Hub (will be deleted on import):${NC}"
        echo "$ONLY_HUB" | sed 's/^/  - /'
    fi
    
    # Systems only in config
    ONLY_CONFIG=$(comm -13 <(echo "$CURRENT_SYSTEMS") <(echo "$CONFIG_SYSTEMS"))
    if [ -n "$ONLY_CONFIG" ]; then
        echo -e "${GREEN}Only in config.yml (will be added on import):${NC}"
        echo "$ONLY_CONFIG" | sed 's/^/  - /'
    fi
    
    if [ -z "$ONLY_HUB" ] && [ -z "$ONLY_CONFIG" ]; then
        echo -e "${GREEN}✓ Hub and config.yml are in sync${NC}"
    fi
}

# Function to create backup
create_backup() {
    echo "Creating configuration backup..."
    
    mkdir -p "$BACKUP_DIR"
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    
    # Backup config.yml if it exists
    if [ -f "$CONFIG_FILE" ]; then
        cp "$CONFIG_FILE" "$BACKUP_DIR/config_$TIMESTAMP.yml"
        echo -e "${GREEN}Backed up config.yml to $BACKUP_DIR/config_$TIMESTAMP.yml${NC}"
    fi
    
    # Export current hub configuration
    get_auth_token
    SYSTEMS=$(curl -s -X GET "$HUB_URL/api/collections/systems/records" \
        -H "Authorization: Bearer $AUTH_TOKEN")
    
    echo "$SYSTEMS" | jq '.' > "$BACKUP_DIR/hub_systems_$TIMESTAMP.json"
    echo -e "${GREEN}Backed up hub configuration to $BACKUP_DIR/hub_systems_$TIMESTAMP.json${NC}"
    
    # Show backup summary
    echo ""
    echo "Backup created:"
    ls -lh "$BACKUP_DIR"/*$TIMESTAMP* | awk '{print "  - " $NF " (" $5 ")"}'
}

# Function to import configuration (placeholder)
import_config() {
    echo -e "${YELLOW}Import functionality requires hub-side implementation${NC}"
    echo "To import config.yml:"
    echo "1. Copy config.yml to hub server: /opt/beszel-hub/beszel_data/config.yml"
    echo "2. Restart hub container: docker compose restart"
    echo ""
    echo "The hub will automatically sync systems based on config.yml"
    echo -e "${RED}WARNING: Systems not in config.yml will be deleted!${NC}"
}

# Main script logic
case "${1:-help}" in
    export)
        export_config
        ;;
    validate)
        validate_config
        ;;
    diff)
        show_diff
        ;;
    backup)
        create_backup
        ;;
    import)
        import_config
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        echo -e "${RED}Unknown command: $1${NC}"
        echo ""
        show_help
        exit 1
        ;;
esac