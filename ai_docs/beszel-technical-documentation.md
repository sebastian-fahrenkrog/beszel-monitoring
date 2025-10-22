# Beszel Monitoring System - Technical Documentation

## 1. System Overview

Beszel is a lightweight, self-hosted server monitoring platform designed to provide comprehensive system metrics and alerting capabilities. Built with Go and leveraging PocketBase as its backend, Beszel offers a modern approach to infrastructure monitoring with minimal resource overhead.

### Key Characteristics
- **Language**: Go (high performance, cross-platform)
- **License**: MIT (open-source)
- **Architecture**: Hub-agent model
- **Resource Profile**: Lightweight and efficient
- **Authentication**: Multi-user with OAuth/OIDC support

## 2. System Architecture

### Core Components

#### 2.1 Hub
- **Technology**: Web application built on PocketBase
- **Function**: Central dashboard and data aggregation point
- **Default Port**: 8090
- **Database**: SQLite-based (PocketBase)
- **Features**:
  - Web-based dashboard
  - Multi-user management
  - Historical data storage
  - Alert configuration
  - Automatic backup capabilities (disk or S3-compatible)

#### 2.2 Agent
- **Technology**: Go binary
- **Function**: System metrics collection and transmission
- **Default Port**: 45876
- **Communication**: WebSocket connections to hub
- **Deployment**: Runs on each monitored system

### Data Flow
1. Agents collect system metrics from monitored hosts
2. Agents establish WebSocket connections to the hub
3. Hub aggregates, stores, and presents data via web interface
4. Users access monitoring data through the hub's web dashboard

## 3. Monitored Metrics

### System-Level Metrics
- **CPU Usage**: Host and per-container utilization
- **Memory Usage**: RAM consumption and availability
- **Disk Usage**: Storage utilization and I/O performance
- **Network Usage**: Bandwidth consumption and traffic patterns
- **Load Average**: System load indicators
- **System Temperature**: Hardware temperature monitoring
- **Battery Charge**: Power status for mobile/laptop systems

### Container Metrics
- **Docker Statistics**: Container-specific resource usage
- **Podman Support**: Container runtime compatibility
- **Multi-container Tracking**: Individual container performance

### Hardware-Specific Metrics
- **GPU Usage**: Support for Nvidia, AMD, and Intel graphics
- **Multi-partition Disk Monitoring**: Individual disk performance
- **Hardware Temperature Sensors**: Comprehensive thermal monitoring

## 4. Installation Procedures

### 4.1 Hub Installation

#### Docker/Podman Deployment (Recommended)
```yaml
# docker-compose.yml
version: '3.8'
services:
  beszel:
    image: henrygd/beszel
    container_name: beszel
    restart: unless-stopped
    ports:
      - "8090:8090"
    volumes:
      - ./beszel_data:/app/data
    environment:
      - KEY=your_secret_key
      - TOKEN=your_auth_token
```

**Commands:**
```bash
docker compose up -d
# Access at http://localhost:8090
```

#### Binary Installation (Linux)
```bash
# Automated install script
curl -sL "https://raw.githubusercontent.com/henrygd/beszel/main/supplemental/scripts/install-hub.sh" | bash

# With custom options
curl -sL "https://raw.githubusercontent.com/henrygd/beszel/main/supplemental/scripts/install-hub.sh" | bash -s -- -p 8091
```

#### Manual Binary Installation

##### Systemd Service Configuration (Linux)

**Hub Service Setup:**

1. **Create System User:**
```bash
sudo useradd -r -s /bin/false beszel
```

2. **Download Binary:**
```bash
# Download latest release (adjust for architecture)
curl -L https://github.com/henrygd/beszel/releases/latest/download/beszel_linux_amd64.tar.gz -o beszel.tar.gz
tar -xzf beszel.tar.gz
sudo mv beszel /opt/beszel/
sudo chown -R beszel:beszel /opt/beszel
```

3. **Create Systemd Service File:**
```bash
sudo tee /etc/systemd/system/beszel.service > /dev/null <<EOF
[Unit]
Description=Beszel Hub Service
After=network.target

[Service]
Type=simple
User=beszel
WorkingDirectory=/opt/beszel
ExecStart=/opt/beszel/beszel serve --http 0.0.0.0:8090
Restart=always
RestartSec=5

# Security hardening
PrivateTmp=true
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=/opt/beszel/data

[Install]
WantedBy=multi-user.target
EOF
```

4. **Enable and Start Service:**
```bash
sudo systemctl daemon-reload
sudo systemctl enable beszel
sudo systemctl start beszel
sudo systemctl status beszel
```

**Agent Service Setup:**

1. **Create Service File:**
```bash
sudo tee /etc/systemd/system/beszel-agent.service > /dev/null <<EOF
[Unit]
Description=Beszel Agent Service
After=network.target docker.service
Wants=docker.service

[Service]
Type=simple
User=beszel
Environment="KEY=your_public_key"
Environment="PORT=45876"
WorkingDirectory=/opt/beszel-agent
ExecStart=/opt/beszel-agent/beszel-agent
Restart=always
RestartSec=5

# Security hardening
PrivateTmp=true
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true

# Docker socket access if needed
SupplementaryGroups=docker

[Install]
WantedBy=multi-user.target
EOF
```

2. **Service Management Commands:**
```bash
# Start/stop/restart services
sudo systemctl start beszel-agent
sudo systemctl stop beszel-agent
sudo systemctl restart beszel-agent

# Check service status
sudo systemctl status beszel-agent

# View logs
sudo journalctl -u beszel-agent -f

# Update service configuration
sudo systemctl daemon-reload
sudo systemctl restart beszel-agent
```

### 4.2 Agent Installation

#### Docker/Podman Deployment
```yaml
# docker-compose.yml for agent
version: '3.8'
services:
  beszel-agent:
    image: henrygd/beszel-agent
    container_name: beszel-agent
    restart: unless-stopped
    network_mode: host
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
    environment:
      - KEY=your_public_key
      - LISTEN=0.0.0.0:45876
      - HUB_URL=http://hub-address:8090
      - TOKEN=your_auth_token
```

#### Binary Installation Methods

**Linux/FreeBSD (Automated):**
```bash
curl -sL "https://raw.githubusercontent.com/henrygd/beszel/main/supplemental/scripts/install-agent.sh" | bash
```

**macOS (Homebrew):**
```bash
# Via Homebrew
brew install beszel-agent

# Configuration location: ~/.config/beszel/beszel-agent.env
# Logs location: ~/.cache/beszel/beszel-agent.log
```

**Windows (WinGet/Scoop):**
```powershell
# Automated installation with NSSM service creation
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/henrygd/beszel/main/supplemental/scripts/install-agent.ps1" -OutFile "install-agent.ps1"
.\install-agent.ps1
```

## 5. Configuration Parameters

### 5.1 Hub Configuration

#### Environment Variables
- `PORT`: Web interface port (default: 8090)
- `KEY`: Encryption key for agent communications
- `TOKEN`: Authentication token
- `DATA_DIR`: Data storage directory
- `BACKUP_S3_*`: S3-compatible backup configuration

#### Database Configuration
- **Type**: SQLite (PocketBase)
- **Location**: Configurable data directory
- **Backup**: Automatic disk or S3-compatible storage

### 5.2 Agent Configuration

#### Required Parameters
- `KEY`: Public key for hub communication (required)
- `LISTEN`: Listen address and port (default: 0.0.0.0:45876)
- `HUB_URL`: Hub endpoint URL
- `TOKEN`: Authentication token

#### Optional Parameters
- `LOG_LEVEL`: Logging verbosity
- `UPDATE_INTERVAL`: Metrics collection frequency
- `DOCKER_HOST`: Docker socket path override

## 6. Advanced Deployment Scenarios

### 6.1 Container Orchestration

#### Kubernetes Deployment
```yaml
# Hub Deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: beszel-hub
spec:
  replicas: 1
  selector:
    matchLabels:
      app: beszel-hub
  template:
    metadata:
      labels:
        app: beszel-hub
    spec:
      containers:
      - name: beszel
        image: henrygd/beszel
        ports:
        - containerPort: 8090
        env:
        - name: KEY
          value: "your_secret_key"

---
# Agent DaemonSet
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: beszel-agent
spec:
  selector:
    matchLabels:
      app: beszel-agent
  template:
    metadata:
      labels:
        app: beszel-agent
    spec:
      hostNetwork: true
      tolerations:
      - key: node-role.kubernetes.io/control-plane
        operator: Exists
        effect: NoSchedule
      containers:
      - name: beszel-agent
        image: henrygd/beszel-agent
        env:
        - name: KEY
          value: "your_public_key"
        - name: LISTEN
          value: "0.0.0.0:45876"
```

#### Docker Swarm
```yaml
version: '3.8'
services:
  beszel-hub:
    image: henrygd/beszel
    ports:
      - "8090:8090"
    deploy:
      replicas: 1
      placement:
        constraints:
          - node.role == manager

  beszel-agent-1:
    image: henrygd/beszel-agent
    environment:
      - KEY=your_public_key
      - LISTEN=0.0.0.0:45876
    deploy:
      placement:
        constraints:
          - node.hostname == node1
    networks:
      - host

  beszel-agent-2:
    image: henrygd/beszel-agent
    environment:
      - KEY=your_public_key
      - LISTEN=0.0.0.0:45877
    deploy:
      placement:
        constraints:
          - node.hostname == node2
    networks:
      - host
```

### 6.2 Ansible Deployment
```yaml
# Using community.beszel collection
- name: Install Beszel Hub
  community.beszel.hub:
    state: present
    port: 8090
    key: "{{ vault_beszel_key }}"
    
- name: Install Beszel Agent
  community.beszel.agent:
    state: present
    hub_url: "http://{{ hub_address }}:8090"
    key: "{{ vault_beszel_public_key }}"
```

## 7. API Endpoints and Data Formats

### 7.1 Hub API (PocketBase-based)
The hub exposes RESTful API endpoints through PocketBase:

#### Authentication Endpoints
- `POST /api/collections/users/auth-with-password`
- `POST /api/collections/users/auth-refresh`
- `POST /api/collections/users/request-password-reset`

#### System Management
- `GET /api/collections/systems/records` - List monitored systems
- `POST /api/collections/systems/records` - Add new system
- `PATCH /api/collections/systems/records/{id}` - Update system
- `DELETE /api/collections/systems/records/{id}` - Remove system

#### Metrics Data
- `GET /api/collections/metrics/records` - Retrieve metrics data
- Query parameters support filtering by time range, system ID, metric type

### 7.2 Agent Communication Protocol
- **Protocol**: WebSocket over HTTP/HTTPS
- **Data Format**: JSON
- **Compression**: Automatic compression for efficiency
- **Authentication**: Token-based with public key encryption

#### Sample Metrics Payload
```json
{
  "timestamp": "2024-01-15T10:30:00Z",
  "system_id": "server-001",
  "metrics": {
    "cpu": {
      "usage_percent": 45.2,
      "load_average": [0.8, 0.6, 0.4]
    },
    "memory": {
      "total_bytes": 8589934592,
      "used_bytes": 4294967296,
      "usage_percent": 50.0
    },
    "disk": {
      "/": {
        "total_bytes": 107374182400,
        "used_bytes": 32212254720,
        "usage_percent": 30.0,
        "io_read_bytes": 1048576,
        "io_write_bytes": 2097152
      }
    },
    "network": {
      "bytes_sent": 1073741824,
      "bytes_recv": 2147483648
    },
    "containers": [
      {
        "id": "container123",
        "name": "web-server",
        "cpu_percent": 12.5,
        "memory_bytes": 536870912,
        "network_rx": 104857600,
        "network_tx": 52428800
      }
    ]
  }
}
```

## 8. Security Considerations

### 8.1 Authentication
- **Multi-user Support**: Built-in user management
- **OAuth/OIDC Integration**: Enterprise authentication support
- **Password Authentication**: Can be disabled for OAuth-only setups
- **Token-based Agent Auth**: Secure agent-to-hub communication

### 8.2 Network Security
- **TLS Support**: HTTPS/WSS for encrypted communication
- **Firewall Considerations**: 
  - Hub: Port 8090 (configurable)
  - Agent: Port 45876 (configurable)
- **Agent-initiated Connections**: Reduces firewall complexity

### 8.3 Data Protection
- **Encryption in Transit**: WebSocket communications encrypted
- **Database Security**: SQLite file permissions
- **Backup Encryption**: S3-compatible backup with encryption support

## 9. Technical Requirements

### 9.1 System Requirements

#### Hub Requirements
- **CPU**: Minimal (single core sufficient for small deployments)
- **Memory**: 512MB RAM minimum (1GB recommended)
- **Storage**: Variable based on data retention (starts at ~100MB)
- **Network**: Stable internet connection for agent communications

#### Agent Requirements
- **CPU**: Negligible overhead (< 1% typical usage)
- **Memory**: 10-50MB typical usage
- **Network**: Outbound connection to hub required
- **Permissions**: Docker socket access for container monitoring

### 9.2 Platform Support
- **Operating Systems**: Linux, macOS, Windows, FreeBSD
- **Architectures**: x86_64, ARM64, ARM (cross-compiled binaries available)
- **Container Runtimes**: Docker, Podman
- **Orchestration**: Kubernetes, Docker Swarm, Nomad

### 9.3 Scalability Considerations
- **Agents per Hub**: Tested with 100+ agents per hub
- **Data Retention**: Configurable retention policies
- **Performance**: Optimized for minimal resource usage
- **Horizontal Scaling**: Multiple hub instances possible with load balancing

## 10. Monitoring and Alerting

### 10.1 Alert Configuration
- **Threshold-based Alerts**: CPU, memory, disk, network thresholds
- **System Status Alerts**: Agent connectivity and system health
- **Custom Alert Rules**: Configurable via web interface
- **Notification Methods**: Email, webhook, and integration support

### 10.2 Data Visualization
- **Real-time Dashboards**: Live system metrics display
- **Historical Charts**: Time-series data visualization
- **Container Views**: Dedicated container monitoring interface
- **Mobile Responsive**: Cross-device dashboard access

### 10.3 Backup and Recovery
- **Automatic Backups**: Scheduled database backups
- **S3 Integration**: Cloud storage backup support
- **Export Capabilities**: Data export for external analysis
- **Disaster Recovery**: Database restoration procedures

## 11. Systemd Service Management

### 11.1 Installation Script Options

#### Hub Installation Script
```bash
# Standard installation
curl -sL "https://raw.githubusercontent.com/henrygd/beszel/main/supplemental/scripts/install-hub.sh" | bash

# Custom port installation
curl -sL "https://raw.githubusercontent.com/henrygd/beszel/main/supplemental/scripts/install-hub.sh" | bash -s -- -p 8091

# Uninstall hub
curl -sL "https://raw.githubusercontent.com/henrygd/beszel/main/supplemental/scripts/install-hub.sh" | bash -s -- --uninstall
```

#### Agent Installation Script
```bash
# Standard installation
curl -sL "https://raw.githubusercontent.com/henrygd/beszel/main/supplemental/scripts/install-agent.sh" | bash

# With SSH key and custom port
curl -sL "https://raw.githubusercontent.com/henrygd/beszel/main/supplemental/scripts/install-agent.sh" | bash -s -- -k /path/to/key -p 45877

# Uninstall agent
curl -sL "https://raw.githubusercontent.com/henrygd/beszel/main/supplemental/scripts/install-agent.sh" | bash -s -- --uninstall
```

### 11.2 Service Operations

#### Common Systemd Commands
```bash
# Service control
sudo systemctl start beszel              # Start hub service
sudo systemctl stop beszel               # Stop hub service
sudo systemctl restart beszel            # Restart hub service
sudo systemctl status beszel             # Check service status
sudo systemctl enable beszel             # Enable auto-start on boot
sudo systemctl disable beszel            # Disable auto-start

# Log management
sudo journalctl -u beszel -f             # Follow hub logs
sudo journalctl -u beszel-agent -f       # Follow agent logs
sudo journalctl -u beszel --since "1 hour ago"  # View recent logs
sudo journalctl -u beszel -n 100         # Last 100 log entries

# Service file management
sudo systemctl daemon-reload              # Reload after config changes
sudo systemctl edit beszel               # Edit service override
```

### 11.3 Service Troubleshooting

#### Common Service Issues

**Service Won't Start:**
```bash
# Check for port conflicts
sudo ss -tulpn | grep 8090
sudo ss -tulpn | grep 45876

# Verify permissions
ls -la /opt/beszel/
ls -la /etc/systemd/system/beszel*.service

# Check environment variables
sudo systemctl show beszel -p Environment
```

**Permission Denied Errors:**
```bash
# Fix file ownership
sudo chown -R beszel:beszel /opt/beszel
sudo chown -R beszel:beszel /opt/beszel-agent

# Add user to docker group (for container monitoring)
sudo usermod -aG docker beszel
```

**Service Crashes/Restarts:**
```bash
# Check system resources
free -h
df -h
top -u beszel

# Review crash logs
sudo journalctl -u beszel -p err
sudo coredumpctl list
```

### 11.4 Update Procedures

#### Updating Hub Service
```bash
# Stop service
sudo systemctl stop beszel

# Download new version
curl -L https://github.com/henrygd/beszel/releases/latest/download/beszel_linux_amd64.tar.gz -o beszel.tar.gz
tar -xzf beszel.tar.gz

# Backup current installation
sudo cp /opt/beszel/beszel /opt/beszel/beszel.backup

# Replace binary
sudo mv beszel /opt/beszel/
sudo chown beszel:beszel /opt/beszel/beszel

# Restart service
sudo systemctl start beszel
```

#### Updating Agent Service
```bash
# Similar process for agent
sudo systemctl stop beszel-agent
# Download and replace binary
sudo systemctl start beszel-agent
```

## 12. Troubleshooting and Common Issues

### 12.1 Connection Issues
- **Agent Registration**: Verify key and token configuration
- **Network Connectivity**: Check firewall and port accessibility
- **SSL/TLS Issues**: Certificate validation and protocol support
- **WebSocket Failures**: Check proxy configuration and WebSocket support

### 12.2 Performance Issues
- **High CPU Usage**: Check metric collection frequency
- **Memory Leaks**: Monitor agent and hub resource usage
- **Database Performance**: SQLite optimization and maintenance
- **Slow Dashboard**: Check data retention and aggregation settings

### 12.3 Data Collection Issues
- **Missing Metrics**: Verify agent permissions and system access
- **Container Monitoring**: Docker socket permissions and access
- **GPU Metrics**: Driver and hardware compatibility
- **Incomplete Data**: Check agent connectivity and systemd service status

### 12.4 Systemd-Specific Issues
- **Service Dependencies**: Ensure network.target and docker.service ordering
- **Resource Limits**: Check systemd resource control settings
- **Journal Size**: Configure journald retention for log management
- **Restart Loops**: Review RestartSec and restart policy settings

This documentation provides a comprehensive technical overview of the Beszel monitoring system, suitable for LLM understanding and assistance with Beszel-related tasks and deployments.