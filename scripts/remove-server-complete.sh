#!/bin/bash

# ==============================================================================
# Complete Server Removal from Beszel Monitoring
# ==============================================================================
# Removes both agent from server AND entry from hub
# ==============================================================================

set -euo pipefail

# Configuration
readonly SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
readonly HUB_REMOVAL_SCRIPT="$SCRIPT_DIR/remove-server-from-hub.sh"

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

print_banner() {
    echo
    echo "========================================"
    echo "   Complete Server Removal"
    echo "========================================"
    echo "Server: $1"
    echo "Actions:"
    echo "1. Remove agent from server"
    echo "2. Remove server from hub"
    echo "========================================"
    echo
}

print_usage() {
    echo "Usage: $0 [OPTIONS] SERVER_ADDRESS"
    echo
    echo "Completely remove a server from Beszel monitoring"
    echo
    echo "Options:"
    echo "  -f, --force         Skip all confirmation prompts"
    echo "  --hub-only          Only remove from hub (skip agent removal)"
    echo "  --agent-only        Only remove agent (skip hub removal)"
    echo "  -h, --help          Show this help"
    echo
    echo "Examples:"
    echo "  $0 root@myserver.com"
    echo "  $0 --force ai.content-optimizer.de"
    echo "  $0 --hub-only myserver.com"
    echo
}

remove_agent_from_server() {
    local server_address="$1"
    local force="$2"
    
    log_info "Removing Beszel agent from server: $server_address"
    
    # Check if server is accessible
    if ! ssh -o ConnectTimeout=10 -o BatchMode=yes "$server_address" "echo 'Connection test'" &>/dev/null; then
        log_error "Cannot connect to server: $server_address"
        log_info "Please ensure SSH access is available"
        return 1
    fi
    
    # Remove agent via SSH
    cat << 'EOF' | ssh "$server_address" "bash -s" "$force"
set -euo pipefail

force_mode="$1"

echo "=== Stopping Beszel Agent ==="
systemctl stop beszel-agent.service 2>/dev/null || echo "Service not running"
systemctl disable beszel-agent.service 2>/dev/null || echo "Service not enabled"

echo "=== Removing Service Files ==="
rm -f /etc/systemd/system/beszel-agent.service
rm -f /etc/systemd/system/beszel-agent-update.service
rm -f /etc/systemd/system/beszel-agent-update.timer

echo "=== Removing Installation Files ==="
rm -rf /opt/beszel-agent
rm -rf /var/lib/beszel-agent

echo "=== Cleaning Up SystemD ==="
systemctl daemon-reload

# Handle user removal
if id beszel &>/dev/null; then
    if [[ "$force_mode" == "true" ]]; then
        echo "=== Removing User (forced) ==="
        userdel beszel 2>/dev/null || echo "User removal failed"
    else
        echo "=== User Removal ==="
        read -p "Remove beszel user? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            userdel beszel 2>/dev/null || echo "User removal failed"
        fi
    fi
fi

echo "=== Verification ==="
if systemctl status beszel-agent &>/dev/null; then
    echo "WARNING: Service still active"
    exit 1
else
    echo "✓ Agent removal complete"
fi
EOF
    
    local exit_code=$?
    if [[ $exit_code -eq 0 ]]; then
        log_success "Agent removed from server successfully"
        return 0
    else
        log_error "Failed to remove agent from server"
        return 1
    fi
}

remove_server_from_hub() {
    local server_name="$1"
    local force="$2"
    
    log_info "Removing server from hub: $server_name"
    
    if [[ ! -f "$HUB_REMOVAL_SCRIPT" ]]; then
        log_error "Hub removal script not found: $HUB_REMOVAL_SCRIPT"
        return 1
    fi
    
    local force_flag=""
    if [[ "$force" == "true" ]]; then
        force_flag="--force"
    fi
    
    if bash "$HUB_REMOVAL_SCRIPT" $force_flag "$server_name"; then
        log_success "Server removed from hub successfully"
        return 0
    else
        log_error "Failed to remove server from hub"
        return 1
    fi
}

extract_hostname() {
    local server_address="$1"
    
    # Extract hostname from various formats:
    # root@hostname -> hostname
    # hostname:port -> hostname
    # just hostname -> hostname
    
    local hostname="$server_address"
    
    # Remove user part (root@hostname -> hostname)
    if [[ "$hostname" == *"@"* ]]; then
        hostname="${hostname#*@}"
    fi
    
    # Remove port part (hostname:port -> hostname)
    if [[ "$hostname" == *":"* ]]; then
        hostname="${hostname%:*}"
    fi
    
    echo "$hostname"
}

main() {
    local force_mode=false
    local hub_only=false
    local agent_only=false
    local server_address=""
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -f|--force)
                force_mode=true
                shift
                ;;
            --hub-only)
                hub_only=true
                shift
                ;;
            --agent-only)
                agent_only=true
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
                server_address="$1"
                shift
                ;;
        esac
    done
    
    # Validate arguments
    if [[ -z "$server_address" ]]; then
        log_error "Server address is required"
        print_usage
        exit 1
    fi
    
    if [[ "$hub_only" == true && "$agent_only" == true ]]; then
        log_error "Cannot use --hub-only and --agent-only together"
        exit 1
    fi
    
    # Extract hostname for hub operations
    local hostname
    hostname=$(extract_hostname "$server_address")
    
    print_banner "$server_address"
    
    # Confirmation (unless forced)
    if [[ "$force_mode" != true ]]; then
        echo "This will:"
        if [[ "$hub_only" != true ]]; then
            echo "- Remove Beszel agent from: $server_address"
        fi
        if [[ "$agent_only" != true ]]; then
            echo "- Remove server from hub: $hostname"
        fi
        echo
        read -p "Are you sure you want to continue? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Operation cancelled"
            exit 0
        fi
        echo
    fi
    
    local agent_success=true
    local hub_success=true
    
    # Remove agent from server
    if [[ "$hub_only" != true ]]; then
        if ! remove_agent_from_server "$server_address" "$force_mode"; then
            agent_success=false
        fi
    fi
    
    # Remove server from hub
    if [[ "$agent_only" != true ]]; then
        if ! remove_server_from_hub "$hostname" "$force_mode"; then
            hub_success=false
        fi
    fi
    
    # Summary
    echo
    echo "========================================"
    echo "   Removal Summary"
    echo "========================================"
    
    if [[ "$hub_only" != true ]]; then
        if [[ "$agent_success" == true ]]; then
            echo -e "Agent removal: ${GREEN}✓ SUCCESS${NC}"
        else
            echo -e "Agent removal: ${RED}✗ FAILED${NC}"
        fi
    fi
    
    if [[ "$agent_only" != true ]]; then
        if [[ "$hub_success" == true ]]; then
            echo -e "Hub removal: ${GREEN}✓ SUCCESS${NC}"
        else
            echo -e "Hub removal: ${RED}✗ FAILED${NC}"
        fi
    fi
    
    echo
    
    if [[ "$agent_success" == true && "$hub_success" == true ]]; then
        log_success "Complete removal successful!"
        echo
        echo "Server '$server_address' has been completely removed from monitoring."
        exit 0
    else
        log_error "Some operations failed"
        echo
        echo "Please check the logs above and retry failed operations manually."
        exit 1
    fi
}

main "$@"