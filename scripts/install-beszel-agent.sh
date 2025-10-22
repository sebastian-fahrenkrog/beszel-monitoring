#!/bin/bash

# ==============================================================================
# Beszel Agent Installation Script - Secure Local Version
# ==============================================================================
# Purpose: Install Beszel monitoring agent with WebSocket connection
# Author: Sebastian Fahrenkrog
# Version: 1.0.0
# ==============================================================================

set -euo pipefail  # Exit on error, undefined variables, pipe failures

# ==============================================================================
# Configuration Variables - EDIT THESE FOR YOUR SETUP
# ==============================================================================

# Hub Configuration - MUST be provided via environment variables or command line
readonly HUB_URL="${BESZEL_HUB_URL:-}"
readonly UNIVERSAL_TOKEN="${BESZEL_TOKEN:-}"
readonly HUB_PUBLIC_KEY="${BESZEL_KEY:-}"

# Agent Configuration
readonly AGENT_VERSION="${BESZEL_AGENT_VERSION:-latest}"
readonly INSTALL_DIR="${BESZEL_INSTALL_DIR:-/opt/beszel-agent}"
readonly DATA_DIR="${BESZEL_DATA_DIR:-/var/lib/beszel-agent}"
readonly SERVICE_USER="${BESZEL_SERVICE_USER:-beszel}"
readonly AUTO_UPDATE="${BESZEL_AUTO_UPDATE:-true}"

# GitHub Configuration (for downloading agent)
readonly GITHUB_REPO="henrygd/beszel"
readonly GITHUB_API="https://api.github.com/repos/${GITHUB_REPO}"

# System Detection
readonly OS=$(uname -s | tr '[:upper:]' '[:lower:]')
readonly ARCH=$(uname -m | sed 's/x86_64/amd64/' | sed 's/aarch64/arm64/')

# ==============================================================================
# Color Output Functions
# ==============================================================================

readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

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
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

# ==============================================================================
# Prerequisite Checks
# ==============================================================================

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root"
        log_info "Please run: sudo $0"
        exit 1
    fi
}

check_system() {
    log_info "Checking system compatibility..."
    
    # Check OS
    if [[ "$OS" != "linux" ]]; then
        log_error "This script only supports Linux systems"
        exit 1
    fi
    
    # Check systemd
    if ! command -v systemctl &> /dev/null; then
        log_error "systemd is required but not found"
        exit 1
    fi
    
    # Check required commands
    local required_commands=("curl" "tar")
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            log_error "Required command '$cmd' is not installed"
            exit 1
        fi
    done
    
    log_success "System compatibility check passed"
}

# ==============================================================================
# Installation Functions
# ==============================================================================

create_user() {
    if id "$SERVICE_USER" &>/dev/null; then
        log_info "User '$SERVICE_USER' already exists"
    else
        log_info "Creating service user '$SERVICE_USER'..."
        useradd --system --home-dir /nonexistent --shell /bin/false "$SERVICE_USER"
        log_success "User '$SERVICE_USER' created"
    fi
    
    # Add to docker group if Docker is installed
    if getent group docker &>/dev/null; then
        log_info "Adding '$SERVICE_USER' to docker group for container monitoring..."
        usermod -aG docker "$SERVICE_USER" 2>/dev/null || true
    fi
}

download_agent() {
    log_info "Downloading Beszel agent..."
    
    local download_url
    if [[ "$AGENT_VERSION" == "latest" ]]; then
        download_url="https://github.com/${GITHUB_REPO}/releases/latest/download/beszel-agent_${OS}_${ARCH}.tar.gz"
    else
        download_url="https://github.com/${GITHUB_REPO}/releases/download/${AGENT_VERSION}/beszel-agent_${OS}_${ARCH}.tar.gz"
    fi
    
    log_info "Download URL: $download_url"
    
    # Create installation directory
    mkdir -p "$INSTALL_DIR"
    
    # Download and extract with verification
    local temp_file="/tmp/beszel-agent-$$.tar.gz"
    
    if curl -fsSL "$download_url" -o "$temp_file"; then
        # Verify download
        if [[ -f "$temp_file" ]] && [[ -s "$temp_file" ]]; then
            tar -xzf "$temp_file" -C "$INSTALL_DIR"
            rm -f "$temp_file"
            
            # Make executable
            chmod 755 "$INSTALL_DIR/beszel-agent"
            
            # Set ownership
            chown -R "$SERVICE_USER:$SERVICE_USER" "$INSTALL_DIR"
            
            log_success "Agent downloaded and installed to $INSTALL_DIR"
        else
            log_error "Downloaded file is empty or corrupt"
            rm -f "$temp_file"
            exit 1
        fi
    else
        log_error "Failed to download agent"
        exit 1
    fi
}

create_systemd_service() {
    log_info "Creating systemd service..."
    
    # Create data directory
    mkdir -p "$DATA_DIR"
    chown "$SERVICE_USER:$SERVICE_USER" "$DATA_DIR"
    
    # Create systemd service file
    cat > /etc/systemd/system/beszel-agent.service << EOF
[Unit]
Description=Beszel Monitoring Agent (WebSocket Mode)
Documentation=https://github.com/henrygd/beszel
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=${SERVICE_USER}
Group=${SERVICE_USER}
WorkingDirectory=${DATA_DIR}

# WebSocket Configuration - Agent connects to hub
Environment="BESZEL_AGENT_HUB_URL=${HUB_URL}"
Environment="BESZEL_AGENT_TOKEN=${UNIVERSAL_TOKEN}"
Environment="BESZEL_AGENT_KEY=${HUB_PUBLIC_KEY}"

# Optional Configuration
Environment="BESZEL_AGENT_LOG_LEVEL=info"
# Environment="BESZEL_AGENT_SYSTEM_NAME=custom-name"  # Uncomment to override hostname

# Execution
ExecStart=${INSTALL_DIR}/beszel-agent
Restart=always
RestartSec=10
RestartPreventExitStatus=0

# Security Hardening
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
NoNewPrivileges=true
ReadWritePaths=${DATA_DIR} /tmp
ProtectKernelTunables=true
ProtectKernelModules=true
ProtectControlGroups=true
RestrictSUIDSGID=true
LockPersonality=true
RestrictRealtime=true

# Resource Limits
LimitNOFILE=65536
TasksMax=4096

[Install]
WantedBy=multi-user.target
EOF

    log_success "Systemd service created"
}

setup_auto_update() {
    if [[ "$AUTO_UPDATE" != "true" ]]; then
        log_info "Auto-update is disabled"
        return
    fi
    
    log_info "Setting up automatic updates..."
    
    # Create update service
    cat > /etc/systemd/system/beszel-agent-update.service << 'EOF'
[Unit]
Description=Update Beszel Agent
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/opt/beszel-agent/beszel-agent update
User=root
StandardOutput=journal
StandardError=journal
EOF

    # Create update timer (daily at 3 AM)
    cat > /etc/systemd/system/beszel-agent-update.timer << 'EOF'
[Unit]
Description=Daily Beszel Agent Update
Persistent=true

[Timer]
OnCalendar=daily
OnCalendar=03:00
RandomizedDelaySec=1h

[Install]
WantedBy=timers.target
EOF

    systemctl daemon-reload
    systemctl enable beszel-agent-update.timer
    systemctl start beszel-agent-update.timer
    
    log_success "Auto-update configured (daily at 3 AM)"
}

start_service() {
    log_info "Starting Beszel agent service..."
    
    systemctl daemon-reload
    systemctl enable beszel-agent.service
    systemctl restart beszel-agent.service
    
    # Wait for service to start
    sleep 3
    
    if systemctl is-active beszel-agent.service &>/dev/null; then
        log_success "Beszel agent service is running"
    else
        log_error "Failed to start Beszel agent service"
        log_info "Check logs with: journalctl -u beszel-agent -n 50"
        exit 1
    fi
}

verify_connection() {
    log_info "Verifying WebSocket connection..."
    
    # Check logs for successful connection
    if journalctl -u beszel-agent --since "1 minute ago" | grep -q "WebSocket connected"; then
        log_success "Agent connected to hub successfully!"
        log_info "Hub URL: ${HUB_URL}"
        log_info "Agent will appear in dashboard with hostname: $(hostname)"
    else
        log_warning "WebSocket connection not verified yet"
        log_info "Agent may still be connecting. Check status with:"
        log_info "  journalctl -u beszel-agent -f"
    fi
}

# ==============================================================================
# Uninstall Function
# ==============================================================================

uninstall() {
    log_warning "Uninstalling Beszel agent..."
    
    # Stop and disable services
    systemctl stop beszel-agent.service 2>/dev/null || true
    systemctl disable beszel-agent.service 2>/dev/null || true
    systemctl stop beszel-agent-update.timer 2>/dev/null || true
    systemctl disable beszel-agent-update.timer 2>/dev/null || true
    
    # Remove service files
    rm -f /etc/systemd/system/beszel-agent.service
    rm -f /etc/systemd/system/beszel-agent-update.service
    rm -f /etc/systemd/system/beszel-agent-update.timer
    
    # Remove installation directory
    rm -rf "$INSTALL_DIR"
    
    # Remove data directory (optional - contains state)
    read -p "Remove data directory ${DATA_DIR}? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -rf "$DATA_DIR"
    fi
    
    # Remove user (optional)
    read -p "Remove user ${SERVICE_USER}? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        userdel "$SERVICE_USER" 2>/dev/null || true
    fi
    
    systemctl daemon-reload
    
    log_success "Beszel agent uninstalled"
}

# ==============================================================================
# Main Script Logic
# ==============================================================================

print_banner() {
    echo "======================================"
    echo "   Beszel Agent Installer v1.0.0"
    echo "======================================"
    echo "Hub URL: ${HUB_URL}"
    echo "Mode: WebSocket (Agent-Initiated)"
    echo "======================================"
    echo
}

print_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "Options:"
    echo "  install    Install Beszel agent (default)"
    echo "  uninstall  Remove Beszel agent"
    echo "  help       Show this help message"
    echo
    echo "Environment Variables:"
    echo "  BESZEL_HUB_URL       Hub URL (default: $HUB_URL)"
    echo "  BESZEL_TOKEN         Universal token"
    echo "  BESZEL_KEY           Hub's SSH public key"
    echo "  BESZEL_AUTO_UPDATE   Enable auto-updates (default: true)"
    echo
}

main() {
    local action="${1:-install}"
    
    case "$action" in
        install)
            print_banner
            check_root
            check_system
            create_user
            download_agent
            create_systemd_service
            setup_auto_update
            start_service
            verify_connection
            
            echo
            log_success "Installation complete!"
            echo
            echo "Next steps:"
            echo "1. Check agent status: systemctl status beszel-agent"
            echo "2. View logs: journalctl -u beszel-agent -f"
            echo "3. Open dashboard: ${HUB_URL}"
            echo
            ;;
            
        uninstall)
            check_root
            uninstall
            ;;
            
        help|--help|-h)
            print_usage
            ;;
            
        *)
            log_error "Unknown action: $action"
            print_usage
            exit 1
            ;;
    esac
}

# Run main function
main "$@"