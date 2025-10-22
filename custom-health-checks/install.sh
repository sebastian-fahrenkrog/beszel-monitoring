#!/bin/bash

# ==============================================================================
# Beszel Custom Health Checks Installation Script
# ==============================================================================
# Installs custom health check service alongside Beszel agent
# ==============================================================================

set -euo pipefail

# Configuration
readonly INSTALL_DIR="/opt/beszel-health"
readonly SERVICE_USER="beszel"  # Use same user as Beszel agent
readonly SERVICE_NAME="beszel-health-checks"

# Colors
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly RED='\033[0;31m'
readonly NC='\033[0m'

# Functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root"
        exit 1
    fi
}

check_dependencies() {
    log_info "Checking dependencies..."
    
    # Check Python 3
    if ! command -v python3 &> /dev/null; then
        log_error "Python 3 is required but not installed"
        exit 1
    fi
    
    # Check pip
    if ! command -v pip3 &> /dev/null; then
        log_warn "pip3 not found, installing..."
        apt-get update && apt-get install -y python3-pip
    fi
    
    # Check smartctl for disk checks (optional)
    if ! command -v smartctl &> /dev/null; then
        log_warn "smartctl not found, installing smartmontools..."
        apt-get update && apt-get install -y smartmontools
    fi
}

install_python_packages() {
    log_info "Installing Python packages..."
    pip3 install -q pyyaml requests schedule psutil
}

create_directories() {
    log_info "Creating directories..."
    
    mkdir -p "$INSTALL_DIR"/{checks,metrics,logs}
    
    # Set ownership
    chown -R "$SERVICE_USER:$SERVICE_USER" "$INSTALL_DIR"
}

copy_files() {
    log_info "Copying files..."
    
    # Get script directory
    SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
    
    # Copy main runner
    cp "$SCRIPT_DIR/health_check_runner.py" "$INSTALL_DIR/"
    chmod +x "$INSTALL_DIR/health_check_runner.py"
    
    # Copy health check scripts
    cp "$SCRIPT_DIR/checks/"*.py "$INSTALL_DIR/checks/"
    chmod +x "$INSTALL_DIR/checks/"*.py
    
    # Copy config if it doesn't exist
    if [[ ! -f "$INSTALL_DIR/config.yml" ]]; then
        cp "$SCRIPT_DIR/config.yml" "$INSTALL_DIR/"
    else
        log_warn "Config file already exists, not overwriting"
        cp "$SCRIPT_DIR/config.yml" "$INSTALL_DIR/config.yml.new"
        log_info "New config saved as config.yml.new"
    fi
    
    # Set ownership
    chown -R "$SERVICE_USER:$SERVICE_USER" "$INSTALL_DIR"
}

create_systemd_service() {
    log_info "Creating systemd service..."
    
    cat > "/etc/systemd/system/${SERVICE_NAME}.service" << EOF
[Unit]
Description=Beszel Custom Health Checks Service
Documentation=https://github.com/sebastian-fahrenkrog/beszel-monitoring
After=network.target beszel-agent.service
Wants=beszel-agent.service

[Service]
Type=simple
User=${SERVICE_USER}
Group=${SERVICE_USER}
WorkingDirectory=${INSTALL_DIR}

# Python unbuffered output
Environment="PYTHONUNBUFFERED=1"

# Execution
ExecStart=/usr/bin/python3 ${INSTALL_DIR}/health_check_runner.py --config ${INSTALL_DIR}/config.yml
Restart=on-failure
RestartSec=30

# Security
PrivateTmp=yes
NoNewPrivileges=yes
ProtectSystem=strict
ProtectHome=yes
ReadWritePaths=${INSTALL_DIR}

# Resource limits
MemoryLimit=256M
CPUQuota=10%

[Install]
WantedBy=multi-user.target
EOF
    
    # Add sudoers rule for smartctl (if needed)
    if command -v smartctl &> /dev/null; then
        echo "${SERVICE_USER} ALL=(ALL) NOPASSWD: /usr/sbin/smartctl" > /etc/sudoers.d/beszel-health
        chmod 440 /etc/sudoers.d/beszel-health
    fi
}

setup_log_rotation() {
    log_info "Setting up log rotation..."
    
    cat > /etc/logrotate.d/beszel-health << EOF
${INSTALL_DIR}/logs/*.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    create 0644 ${SERVICE_USER} ${SERVICE_USER}
    postrotate
        systemctl reload ${SERVICE_NAME} 2>/dev/null || true
    endscript
}
EOF
}

start_service() {
    log_info "Starting service..."
    
    systemctl daemon-reload
    systemctl enable "${SERVICE_NAME}.service"
    systemctl restart "${SERVICE_NAME}.service"
    
    sleep 3
    
    if systemctl is-active "${SERVICE_NAME}.service" &>/dev/null; then
        log_info "Service started successfully"
    else
        log_error "Failed to start service"
        log_info "Check logs: journalctl -u ${SERVICE_NAME} -n 50"
        exit 1
    fi
}

test_checks() {
    log_info "Testing health checks..."
    
    # Run test mode
    sudo -u "$SERVICE_USER" python3 "$INSTALL_DIR/health_check_runner.py" \
        --config "$INSTALL_DIR/config.yml" --test
}

print_summary() {
    echo
    echo "========================================"
    echo "   Installation Complete!"
    echo "========================================"
    echo
    echo "Service: ${SERVICE_NAME}"
    echo "Config: ${INSTALL_DIR}/config.yml"
    echo "Logs: ${INSTALL_DIR}/logs/health_checks.log"
    echo "Metrics: ${INSTALL_DIR}/metrics/health_metrics.json"
    echo
    echo "Commands:"
    echo "  systemctl status ${SERVICE_NAME}"
    echo "  journalctl -u ${SERVICE_NAME} -f"
    echo "  vi ${INSTALL_DIR}/config.yml"
    echo
    echo "To add custom checks:"
    echo "1. Create script in ${INSTALL_DIR}/checks/"
    echo "2. Add entry to ${INSTALL_DIR}/config.yml"
    echo "3. Restart service: systemctl restart ${SERVICE_NAME}"
    echo
}

uninstall() {
    log_warn "Uninstalling Beszel Health Checks..."
    
    # Stop service
    systemctl stop "${SERVICE_NAME}" 2>/dev/null || true
    systemctl disable "${SERVICE_NAME}" 2>/dev/null || true
    
    # Remove files
    rm -f "/etc/systemd/system/${SERVICE_NAME}.service"
    rm -f "/etc/sudoers.d/beszel-health"
    rm -f "/etc/logrotate.d/beszel-health"
    
    # Optional: remove install directory
    read -p "Remove ${INSTALL_DIR}? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -rf "$INSTALL_DIR"
    fi
    
    systemctl daemon-reload
    
    log_info "Uninstall complete"
}

# Main
main() {
    local action="${1:-install}"
    
    case "$action" in
        install)
            check_root
            check_dependencies
            install_python_packages
            create_directories
            copy_files
            create_systemd_service
            setup_log_rotation
            start_service
            print_summary
            ;;
        
        test)
            check_root
            test_checks
            ;;
        
        uninstall)
            check_root
            uninstall
            ;;
        
        *)
            echo "Usage: $0 {install|test|uninstall}"
            exit 1
            ;;
    esac
}

main "$@"