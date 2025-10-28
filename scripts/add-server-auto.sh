#!/bin/bash

# ==============================================================================
# Automated Server Addition to Beszel Monitoring
# ==============================================================================
# This script automatically:
# 1. Regenerates the universal token from the hub
# 2. Retrieves the SSH public key from the hub
# 3. Installs the Beszel agent on the target server(s)
# 4. Verifies the connection and metrics collection
# ==============================================================================

set -euo pipefail

# ==============================================================================
# CONFIGURATION
# ==============================================================================

# Hub Configuration
readonly HUB_URL="${BESZEL_HUB_URL:-https://monitoring.inproma.de}"
readonly HUB_SERVER="${BESZEL_HUB_SERVER:-monitoring.inproma.de}"
readonly HUB_ADMIN_EMAIL="${BESZEL_ADMIN_EMAIL:-sebastian.fahrenkrog@gmail.com}"
readonly HUB_ADMIN_PASSWORD="${BESZEL_ADMIN_PASSWORD:-gOACNFz1TvdT8r}"

# Installation script URL
readonly GITHUB_USER="${GITHUB_USER:-sebastian-fahrenkrog}"
readonly GITHUB_REPO="${GITHUB_REPO:-beszel-monitoring}"
readonly GITHUB_BRANCH="${GITHUB_BRANCH:-main}"
readonly INSTALL_SCRIPT_URL="https://raw.githubusercontent.com/${GITHUB_USER}/${GITHUB_REPO}/${GITHUB_BRANCH}/scripts/install-beszel-agent.sh"

# Enable auto-updates
readonly ENABLE_AUTO_UPDATE="true"

# ==============================================================================
# Color Output
# ==============================================================================

readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'

# ==============================================================================
# Functions
# ==============================================================================

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_banner() {
    echo
    echo "======================================"
    echo "  Beszel Monitoring - Add Server"
    echo "======================================"
    echo -e "${BLUE}Hub:${NC} ${HUB_URL}"
    echo "======================================"
    echo
}

print_usage() {
    cat << EOF
Usage: $0 [OPTIONS] SERVER_ADDRESS [SERVER_ADDRESS...]

Add one or more servers to Beszel monitoring system.

Arguments:
  SERVER_ADDRESS    SSH connection string (e.g., root@server.example.com)
                    Can specify multiple servers separated by space

Options:
  -h, --help       Show this help message
  -l, --list       List currently monitored servers
  -v, --verify     Verify servers after installation

Examples:
  # Add single server
  $0 root@example.com

  # Add multiple servers
  $0 root@server1.com root@server2.com root@server3.com

  # Add server and verify connection
  $0 --verify root@example.com

  # List currently monitored servers
  $0 --list

Environment Variables:
  BESZEL_HUB_URL           Hub URL (default: ${HUB_URL})
  BESZEL_HUB_SERVER        Hub SSH server (default: ${HUB_SERVER})
  BESZEL_ADMIN_EMAIL       Admin email (default: ${HUB_ADMIN_EMAIL})
  BESZEL_ADMIN_PASSWORD    Admin password (required if different)

EOF
}

check_dependencies() {
    local missing_deps=()

    for cmd in curl jq ssh; do
        if ! command -v "$cmd" &> /dev/null; then
            missing_deps+=("$cmd")
        fi
    done

    if [ ${#missing_deps[@]} -gt 0 ]; then
        log_error "Missing required dependencies: ${missing_deps[*]}"
        log_info "Install with: sudo apt-get install curl jq openssh-client (Debian/Ubuntu)"
        log_info "            or: sudo yum install curl jq openssh-clients (RHEL/CentOS)"
        exit 1
    fi
}

regenerate_universal_token() {
    log_info "Regenerating universal token from hub..." >&2

    # Get authentication token
    local auth_response
    auth_response=$(curl -s -X POST "${HUB_URL}/api/collections/users/auth-with-password" \
        -H "Content-Type: application/json" \
        -d "{\"identity\": \"${HUB_ADMIN_EMAIL}\", \"password\": \"${HUB_ADMIN_PASSWORD}\"}")

    local auth_token
    auth_token=$(echo "$auth_response" | jq -r '.token')

    if [ -z "$auth_token" ] || [ "$auth_token" = "null" ]; then
        log_error "Failed to authenticate with hub" >&2
        echo "Response: $auth_response" >&2
        exit 1
    fi

    # Generate/activate universal token
    local token_response
    token_response=$(curl -s -X GET "${HUB_URL}/api/beszel/universal-token?enable=1" \
        -H "Authorization: Bearer ${auth_token}")

    local universal_token
    universal_token=$(echo "$token_response" | jq -r '.token')

    if [ -z "$universal_token" ] || [ "$universal_token" = "null" ]; then
        log_error "Failed to generate universal token" >&2
        echo "Response: $token_response" >&2
        exit 1
    fi

    log_success "Universal token generated: ${universal_token:0:8}...${universal_token: -8}" >&2
    echo "$universal_token"
}

get_hub_ssh_key() {
    log_info "Retrieving SSH public key from hub..." >&2

    local ssh_key
    ssh_key=$(ssh -o StrictHostKeyChecking=no "root@${HUB_SERVER}" \
        'ssh-keygen -y -f /opt/beszel-hub/beszel_data/id_ed25519' 2>/dev/null)

    if [ -z "$ssh_key" ]; then
        log_error "Failed to retrieve SSH public key from hub" >&2
        exit 1
    fi

    log_success "SSH public key retrieved" >&2
    echo "$ssh_key"
}

install_agent_on_server() {
    local server="$1"
    local universal_token="$2"
    local ssh_public_key="$3"

    log_info "Installing agent on ${server}..." >&2

    # Create remote installation command
    local remote_cmd="
        export BESZEL_HUB_URL='${HUB_URL}'
        export BESZEL_TOKEN='${universal_token}'
        export BESZEL_KEY='${ssh_public_key}'
        export BESZEL_AUTO_UPDATE='${ENABLE_AUTO_UPDATE}'

        curl -fsSL '${INSTALL_SCRIPT_URL}' | bash -s -- install
    "

    # Execute on remote server
    if ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$server" "$remote_cmd"; then
        log_success "${server} - Installation successful" >&2
        return 0
    else
        log_error "${server} - Installation failed" >&2
        return 1
    fi
}

list_monitored_servers() {
    log_info "Retrieving list of monitored servers..."

    # Get authentication token
    local auth_response
    auth_response=$(curl -s -X POST "${HUB_URL}/api/collections/users/auth-with-password" \
        -H "Content-Type: application/json" \
        -d "{\"identity\": \"${HUB_ADMIN_EMAIL}\", \"password\": \"${HUB_ADMIN_PASSWORD}\"}")

    local auth_token
    auth_token=$(echo "$auth_response" | jq -r '.token')

    if [ -z "$auth_token" ] || [ "$auth_token" = "null" ]; then
        log_error "Failed to authenticate with hub"
        exit 1
    fi

    # Get systems list
    local systems
    systems=$(curl -s -X GET "${HUB_URL}/api/collections/systems/records?perPage=100" \
        -H "Authorization: Bearer ${auth_token}")

    echo
    echo "======================================"
    echo "  Currently Monitored Servers"
    echo "======================================"
    echo

    echo "$systems" | jq -r '.items[] | "[\(.status)] \(.name) - CPU: \(.info.c // "N/A")%, Mem: \(.info.mp // "N/A")%"' | sort

    local total_count
    total_count=$(echo "$systems" | jq '.items | length')

    echo
    echo "Total servers: ${total_count}"
    echo "======================================"
}

verify_server_connection() {
    local server_hostname="$1"

    log_info "Verifying connection for ${server_hostname}..."

    # Get authentication token
    local auth_response
    auth_response=$(curl -s -X POST "${HUB_URL}/api/collections/users/auth-with-password" \
        -H "Content-Type: application/json" \
        -d "{\"identity\": \"${HUB_ADMIN_EMAIL}\", \"password\": \"${HUB_ADMIN_PASSWORD}\"}")

    local auth_token
    auth_token=$(echo "$auth_response" | jq -r '.token')

    # Wait a few seconds for metrics to be collected
    sleep 5

    # Get systems list and check for our server
    local systems
    systems=$(curl -s -X GET "${HUB_URL}/api/collections/systems/records?perPage=100" \
        -H "Authorization: Bearer ${auth_token}")

    local server_info
    server_info=$(echo "$systems" | jq -r ".items[] | select(.name == \"${server_hostname}\")")

    if [ -z "$server_info" ]; then
        log_warning "Server not found in hub (it may take a minute to appear)"
        return 1
    fi

    local status
    status=$(echo "$server_info" | jq -r '.status')

    if [ "$status" = "up" ]; then
        local cpu
        local mem
        cpu=$(echo "$server_info" | jq -r '.info.c // "N/A"')
        mem=$(echo "$server_info" | jq -r '.info.mp // "N/A"')

        log_success "${server_hostname} is connected - CPU: ${cpu}%, Mem: ${mem}%"
        return 0
    else
        log_warning "${server_hostname} status: ${status}"
        return 1
    fi
}

# ==============================================================================
# Main Logic
# ==============================================================================

main() {
    local servers=()
    local verify_after_install=false
    local list_servers=false

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                print_usage
                exit 0
                ;;
            -l|--list)
                list_servers=true
                shift
                ;;
            -v|--verify)
                verify_after_install=true
                shift
                ;;
            -*)
                log_error "Unknown option: $1"
                print_usage
                exit 1
                ;;
            *)
                servers+=("$1")
                shift
                ;;
        esac
    done

    print_banner

    # Check dependencies
    check_dependencies

    # Handle --list option
    if [ "$list_servers" = true ]; then
        list_monitored_servers
        exit 0
    fi

    # Check if servers were provided
    if [ ${#servers[@]} -eq 0 ]; then
        log_error "No servers specified"
        print_usage
        exit 1
    fi

    # Step 1: Regenerate universal token
    local universal_token
    universal_token=$(regenerate_universal_token)

    # Step 2: Get SSH public key
    local ssh_public_key
    ssh_public_key=$(get_hub_ssh_key)

    echo
    log_info "Starting installation on ${#servers[@]} server(s)..."
    echo

    # Step 3: Install agents on all servers
    local successful_installs=()
    local failed_installs=()

    for server in "${servers[@]}"; do
        echo "--------------------------------------"
        if install_agent_on_server "$server" "$universal_token" "$ssh_public_key"; then
            successful_installs+=("$server")
        else
            failed_installs+=("$server")
        fi
        echo
    done

    # Summary
    echo
    echo "======================================"
    echo "  Installation Summary"
    echo "======================================"
    echo -e "${GREEN}Successful:${NC} ${#successful_installs[@]}"
    echo -e "${RED}Failed:${NC} ${#failed_installs[@]}"
    echo

    if [ ${#successful_installs[@]} -gt 0 ]; then
        echo "Successfully installed on:"
        for server in "${successful_installs[@]}"; do
            echo "  ✅ $server"
        done
        echo
    fi

    if [ ${#failed_installs[@]} -gt 0 ]; then
        echo "Failed to install on:"
        for server in "${failed_installs[@]}"; do
            echo "  ❌ $server"
        done
        echo
    fi

    # Verify connections if requested
    if [ "$verify_after_install" = true ] && [ ${#successful_installs[@]} -gt 0 ]; then
        echo "======================================"
        echo "  Verifying Connections"
        echo "======================================"
        echo

        for server in "${successful_installs[@]}"; do
            # Extract hostname from SSH string (e.g., root@server.com -> server.com)
            local hostname
            hostname=$(echo "$server" | sed 's/.*@//' | sed 's/:.*//')

            verify_server_connection "$hostname"
        done
        echo
    fi

    # Final instructions
    echo "======================================"
    echo "  Next Steps"
    echo "======================================"
    echo "1. Open dashboard: ${HUB_URL}"
    echo "2. Servers will appear with their hostname"
    echo "3. Metrics should start flowing within 1 minute"
    echo
    echo "To verify connections later, run:"
    echo "  $0 --list"
    echo "======================================"
    echo
}

# Run main function
main "$@"
