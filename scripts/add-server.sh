#!/bin/bash

# ==============================================================================
# Add New Server to Beszel Monitoring
# ==============================================================================
# This script adds a new server to the Beszel monitoring system
# It uses your own hosted installation script for better security
# ==============================================================================

set -euo pipefail

# ==============================================================================
# CONFIGURATION - Adjust these variables for your setup
# ==============================================================================

# Your GitHub repository where the install script is hosted
readonly GITHUB_USER="${GITHUB_USER:-sebastianfahrenkrog}"
readonly GITHUB_REPO="${GITHUB_REPO:-beszel-monitoring}"
readonly GITHUB_BRANCH="${GITHUB_BRANCH:-main}"

# Hub Configuration (your Beszel hub)
readonly HUB_URL="${BESZEL_HUB_URL:-https://monitoring.inproma.de}"

# Universal Token (permanent - auto-renews on use)
# This token allows automatic server registration - MUST be provided via environment
readonly UNIVERSAL_TOKEN="${BESZEL_TOKEN:-}"

# Hub's SSH Public Key (from /beszel_data/id_ed25519)
# This is used for cryptographic verification - MUST be provided via environment
readonly HUB_SSH_PUBLIC_KEY="${BESZEL_KEY:-}"

# Installation script URL (your hosted version)
readonly INSTALL_SCRIPT_URL="https://raw.githubusercontent.com/${GITHUB_USER}/${GITHUB_REPO}/${GITHUB_BRANCH}/scripts/install-beszel-agent.sh"

# Enable auto-updates for the agent
readonly ENABLE_AUTO_UPDATE="true"

# ==============================================================================
# Color Output
# ==============================================================================

readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# ==============================================================================
# Validation and Functions
# ==============================================================================

validate_environment() {
    local missing_vars=()
    
    if [ -z "$UNIVERSAL_TOKEN" ]; then
        missing_vars+=("BESZEL_TOKEN")
    fi
    
    if [ -z "$HUB_SSH_PUBLIC_KEY" ]; then
        missing_vars+=("BESZEL_KEY")
    fi
    
    if [ ${#missing_vars[@]} -gt 0 ]; then
        echo -e "${RED}❌ Error: Missing required environment variables:${NC}"
        for var in "${missing_vars[@]}"; do
            echo -e "   ${YELLOW}$var${NC}"
        done
        echo
        echo -e "${BLUE}Please set these variables or source a .env file:${NC}"
        echo "   export BESZEL_TOKEN=\"your-universal-token\""
        echo "   export BESZEL_KEY=\"ssh-ed25519 your-public-key\""
        echo
        exit 1
    fi
}

print_banner() {
    echo
    echo "======================================"
    echo "   Add Server to Beszel Monitoring"
    echo "======================================"
    echo -e "${BLUE}Hub:${NC} ${HUB_URL}"
    echo -e "${BLUE}Script:${NC} ${INSTALL_SCRIPT_URL}"
    echo "======================================"
    echo
}

print_usage() {
    echo "Usage: $0 [SERVER_ADDRESS]"
    echo
    echo "Examples:"
    echo "  $0 root@192.168.1.100         # Add server via SSH"
    echo "  $0                             # Run on current server"
    echo
    echo "Environment Variables:"
    echo "  GITHUB_USER    Your GitHub username (default: ${GITHUB_USER})"
    echo "  GITHUB_REPO    Repository name (default: ${GITHUB_REPO})"
    echo "  GITHUB_BRANCH  Branch name (default: ${GITHUB_BRANCH})"
    echo
}

install_local() {
    echo -e "${YELLOW}Installing on local server...${NC}"
    echo
    
    # Export variables for the installation script
    export BESZEL_HUB_URL="${HUB_URL}"
    export BESZEL_TOKEN="${UNIVERSAL_TOKEN}"
    export BESZEL_KEY="${HUB_SSH_PUBLIC_KEY}"
    export BESZEL_AUTO_UPDATE="${ENABLE_AUTO_UPDATE}"
    
    # Download and run installation script
    echo -e "${BLUE}Downloading installation script...${NC}"
    if curl -fsSL "${INSTALL_SCRIPT_URL}" -o /tmp/install-beszel.sh; then
        echo -e "${GREEN}✓ Script downloaded${NC}"
        
        # Make executable
        chmod +x /tmp/install-beszel.sh
        
        # Show script info
        echo
        echo "Script size: $(wc -c < /tmp/install-beszel.sh) bytes"
        echo "Script lines: $(wc -l < /tmp/install-beszel.sh)"
        echo
        
        # Ask for confirmation
        read -p "Review the script first? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            less /tmp/install-beszel.sh
        fi
        
        # Run installation
        echo -e "${BLUE}Running installation...${NC}"
        sudo bash /tmp/install-beszel.sh install
        
        # Cleanup
        rm -f /tmp/install-beszel.sh
        
        echo -e "${GREEN}✓ Installation complete!${NC}"
    else
        echo -e "${RED}Failed to download installation script${NC}"
        exit 1
    fi
}

install_remote() {
    local server="$1"
    echo -e "${YELLOW}Installing on remote server: ${server}${NC}"
    echo
    
    # Create remote installation command
    local remote_cmd="
        export BESZEL_HUB_URL='${HUB_URL}'
        export BESZEL_TOKEN='${UNIVERSAL_TOKEN}'
        export BESZEL_KEY='${HUB_SSH_PUBLIC_KEY}'
        export BESZEL_AUTO_UPDATE='${ENABLE_AUTO_UPDATE}'
        
        echo 'Downloading installation script...'
        curl -fsSL '${INSTALL_SCRIPT_URL}' -o /tmp/install-beszel.sh && \
        chmod +x /tmp/install-beszel.sh && \
        bash /tmp/install-beszel.sh install && \
        rm -f /tmp/install-beszel.sh
    "
    
    # Execute on remote server
    echo -e "${BLUE}Connecting to ${server}...${NC}"
    ssh "$server" "$remote_cmd"
    
    if [ $? -eq 0 ]; then
        echo
        echo -e "${GREEN}✓ Remote installation complete!${NC}"
        echo -e "${BLUE}The server should now appear in your dashboard at:${NC}"
        echo "  ${HUB_URL}"
    else
        echo -e "${RED}Remote installation failed${NC}"
        exit 1
    fi
}

# ==============================================================================
# Alternative: Direct command for manual use
# ==============================================================================

print_manual_command() {
    echo
    echo "======================================"
    echo "Manual Installation Command"
    echo "======================================"
    echo "Run this command on your server:"
    echo
    echo "export BESZEL_HUB_URL='${HUB_URL}'"
    echo "export BESZEL_TOKEN='${UNIVERSAL_TOKEN}'"
    echo "export BESZEL_KEY='${HUB_SSH_PUBLIC_KEY}'"
    echo "export BESZEL_AUTO_UPDATE='${ENABLE_AUTO_UPDATE}'"
    echo
    echo "curl -fsSL '${INSTALL_SCRIPT_URL}' | sudo -E bash -s -- install"
    echo
    echo "======================================"
    echo
}

# ==============================================================================
# Main Logic
# ==============================================================================

main() {
    # Validate environment variables first
    validate_environment
    
    print_banner
    
    # Check if server address was provided
    if [ $# -eq 0 ]; then
        # No arguments - install on local server
        echo "No server specified, installing on current server"
        echo
        
        # Check if we're root
        if [[ $EUID -eq 0 ]]; then
            install_local
        else
            echo "This script needs root privileges for local installation."
            echo "Please run: sudo $0"
            echo
            echo "Or specify a remote server: $0 root@server.example.com"
            print_manual_command
            exit 1
        fi
    elif [[ "$1" == "help" ]] || [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]]; then
        print_usage
        print_manual_command
    else
        # Server address provided - install remotely
        install_remote "$1"
    fi
    
    echo
    echo "======================================"
    echo "Next Steps:"
    echo "1. Check the dashboard: ${HUB_URL}"
    echo "2. Server will appear with its hostname"
    echo "3. Metrics will start flowing immediately"
    echo "======================================"
}

# Run main function
main "$@"