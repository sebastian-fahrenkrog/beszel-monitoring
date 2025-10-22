#!/bin/bash

# ==============================================================================
# Remove Server from Beszel Hub
# ==============================================================================
# Removes a server from the Beszel hub via API
# ==============================================================================

set -euo pipefail

# Configuration
readonly HUB_URL="https://monitoring.inproma.de"
readonly HUB_USER="sebastian.fahrenkrog@gmail.com"
readonly HUB_PASS="gOACNFz1TvdT8r"

# Colors
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly RED='\033[0;31m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# Functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_usage() {
    echo "Usage: $0 [OPTIONS] SERVER_NAME"
    echo
    echo "Remove a server from Beszel hub"
    echo
    echo "Options:"
    echo "  -l, --list          List all servers in hub"
    echo "  -f, --force         Skip confirmation prompt"
    echo "  -h, --help          Show this help"
    echo
    echo "Examples:"
    echo "  $0 ai.content-optimizer.de"
    echo "  $0 --list"
    echo "  $0 --force myserver.com"
    echo
}

get_auth_token() {
    log_info "Authenticating with hub..."
    
    local token
    token=$(curl -s -X POST "${HUB_URL}/api/collections/users/auth-with-password" \
        -H "Content-Type: application/json" \
        -d "{\"identity\": \"${HUB_USER}\", \"password\": \"${HUB_PASS}\"}" | \
        jq -r '.token // empty')
    
    if [[ -z "$token" ]]; then
        log_error "Failed to authenticate with hub"
        exit 1
    fi
    
    echo "$token"
}

list_servers() {
    local auth_token="$1"
    
    log_info "Fetching servers from hub..."
    
    local servers
    servers=$(curl -s -X GET "${HUB_URL}/api/collections/systems/records" \
        -H "Authorization: Bearer ${auth_token}")
    
    if [[ -z "$servers" ]] || ! echo "$servers" | jq empty 2>/dev/null; then
        log_error "Failed to fetch servers from hub or invalid JSON response"
        echo "Response: $servers" >&2
        exit 1
    fi
    
    echo "$servers"
}

find_server_by_name() {
    local auth_token="$1"
    local server_name="$2"
    
    local servers
    servers=$(list_servers "$auth_token")
    
    echo "$servers" | jq -r --arg name "$server_name" \
        '.items[] | select(.name == $name or .host == $name) | .id'
}

remove_server_from_hub() {
    local auth_token="$1"
    local server_id="$2"
    
    log_info "Removing server from hub (ID: $server_id)..."
    
    local response
    response=$(curl -s -w "%{http_code}" -X DELETE \
        "${HUB_URL}/api/collections/systems/records/${server_id}" \
        -H "Authorization: Bearer ${auth_token}")
    
    local http_code="${response: -3}"
    
    if [[ "$http_code" == "204" ]]; then
        log_success "Server removed from hub successfully"
        return 0
    else
        log_error "Failed to remove server from hub (HTTP: $http_code)"
        return 1
    fi
}

display_servers() {
    local auth_token="$1"
    
    local servers
    servers=$(list_servers "$auth_token")
    
    echo
    echo "========================================"
    echo "   Servers in Beszel Hub"
    echo "========================================"
    echo
    
    echo "$servers" | jq -r '.items[] | 
        "ID: \(.id)\n" +
        "Name: \(.name)\n" +
        "Host: \(.host)\n" +
        "Status: \(.status)\n" +
        "Created: \(.created)\n" +
        "----------------------------------------"'
    
    local count
    count=$(echo "$servers" | jq '.items | length')
    echo "Total servers: $count"
    echo
}

main() {
    local list_only=false
    local force_remove=false
    local server_name=""
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -l|--list)
                list_only=true
                shift
                ;;
            -f|--force)
                force_remove=true
                shift
                ;;
            -h|--help)
                print_usage
                exit 0
                ;;
            -*|--*)
                log_error "Unknown option $1"
                print_usage
                exit 1
                ;;
            *)
                server_name="$1"
                shift
                ;;
        esac
    done
    
    # Get authentication token
    local auth_token
    auth_token=$(get_auth_token)
    
    # List servers mode
    if [[ "$list_only" == true ]]; then
        display_servers "$auth_token"
        exit 0
    fi
    
    # Validate server name
    if [[ -z "$server_name" ]]; then
        log_error "Server name is required"
        print_usage
        exit 1
    fi
    
    # Find server by name
    log_info "Looking for server: $server_name"
    local server_id
    server_id=$(find_server_by_name "$auth_token" "$server_name")
    
    if [[ -z "$server_id" ]]; then
        log_error "Server '$server_name' not found in hub"
        log_info "Use --list to see all servers"
        exit 1
    fi
    
    log_info "Found server: $server_name (ID: $server_id)"
    
    # Confirmation prompt (unless forced)
    if [[ "$force_remove" != true ]]; then
        echo
        read -p "Are you sure you want to remove '$server_name' from the hub? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Operation cancelled"
            exit 0
        fi
    fi
    
    # Remove server
    if remove_server_from_hub "$auth_token" "$server_id"; then
        echo
        log_success "Server '$server_name' removed from hub successfully"
        echo
        echo "Note: This only removes the server from the hub dashboard."
        echo "To also remove the agent from the server, use:"
        echo "  ./remove-server-complete.sh $server_name"
    else
        exit 1
    fi
}

main "$@"