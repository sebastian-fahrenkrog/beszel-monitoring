# Beszel Custom Health Checks

A flexible health check service that runs alongside Beszel monitoring agents to provide custom health monitoring capabilities.

## Features

- 🔧 **Flexible Script Execution**: Run health checks in Python, Bash, or any executable
- ⏰ **Scheduled Checks**: Configure different intervals for each check
- 📊 **Metrics Export**: JSON metrics file for integration with monitoring systems
- 🔔 **Alert Integration**: Webhook notifications for critical issues
- 📝 **Structured Logging**: Detailed logs for debugging
- 🔒 **Secure Execution**: Runs with limited privileges

## Quick Start

### Installation

```bash
# Clone or download the health check files
git clone https://github.com/sebastian-fahrenkrog/beszel-monitoring.git
cd beszel-monitoring/custom-health-checks

# Run installation script
sudo ./install.sh install
```

### Test Health Checks

```bash
# Run all checks once in test mode
sudo ./install.sh test
```

### View Status

```bash
# Service status
systemctl status beszel-health-checks

# View logs
journalctl -u beszel-health-checks -f

# Check metrics file
cat /opt/beszel-health/metrics/health_metrics.json | jq
```

## Included Health Checks

### 1. SSL Certificate Expiry (`ssl_expiry.py`)
Monitors SSL certificates for upcoming expiration.

**Features:**
- Checks multiple hosts
- Configurable warning thresholds
- Certificate details in output

**Configuration:**
```yaml
environment:
  SSL_HOSTS: "example.com,api.example.com:8443"
```

### 2. Disk SMART Status (`disk_smart.py`)
Monitors disk health using SMART data.

**Features:**
- Auto-detects all disks
- Checks critical SMART attributes
- Temperature monitoring

**Requirements:**
- `smartmontools` package
- Sudo access for `smartctl`

### 3. Service Health (`service_health.py`)
Monitors systemd services, processes, and network ports.

**Features:**
- Systemd service status
- Process monitoring with resource usage
- Port availability checks

**Configuration:**
```yaml
environment:
  CHECK_SERVICES: "nginx,docker,mysql"
  CHECK_PROCESSES: "python,node"
  CHECK_PORTS: "80,443,3306"
```

## Writing Custom Health Checks

### Script Requirements

1. **Output Format**: Must output valid JSON to stdout
2. **Exit Codes**:
   - 0 = OK
   - 1 = Warning
   - 2 = Critical
3. **JSON Structure**:
```json
{
  "status": "ok|warning|critical",
  "message": "Human readable message",
  "value": 123,
  "unit": "units",
  "details": {}
}
```

### Python Example

```python
#!/usr/bin/env python3
import json
import sys

def check_something():
    # Your check logic here
    result = perform_check()
    
    output = {
        "status": "ok" if result else "critical",
        "message": "Check passed" if result else "Check failed",
        "value": 1 if result else 0
    }
    
    print(json.dumps(output))
    sys.exit(0 if result else 2)

if __name__ == '__main__':
    check_something()
```

### Bash Example

```bash
#!/bin/bash

# Perform check
if [ -f /var/run/myapp.pid ]; then
    status="ok"
    message="Application is running"
    exit_code=0
else
    status="critical"
    message="Application PID file not found"
    exit_code=2
fi

# Output JSON
echo "{\"status\": \"$status\", \"message\": \"$message\"}"
exit $exit_code
```

## Configuration

Edit `/opt/beszel-health/config.yml`:

```yaml
checks:
  - name: "My Custom Check"
    script: "checks/my_check.py"
    interval: 300  # seconds
    timeout: 30
    environment:
      MY_VAR: "value"
```

After adding a check:
```bash
systemctl restart beszel-health-checks
```

## Integration with Beszel

### Option 1: Webhook Alerts

Configure webhook in `config.yml`:
```yaml
notifications:
  webhook_url: "https://monitoring.inproma.de/api/webhook/health"
```

### Option 2: Metrics File Monitoring

The service writes to `/opt/beszel-health/metrics/health_metrics.json`:
```json
{
  "timestamp": "2024-10-22T10:30:00Z",
  "server": "hostname",
  "checks": {
    "ssl_certificate": {
      "status": "ok",
      "value": 45,
      "unit": "days"
    }
  }
}
```

Monitor this file with your existing monitoring tools.

### Option 3: Docker Health Check

If running in Docker, use as a health check:
```dockerfile
HEALTHCHECK --interval=60s --timeout=10s \
  CMD python3 /opt/beszel-health/checks/my_check.py || exit 1
```

## Troubleshooting

### Check Not Running

```bash
# View service logs
journalctl -u beszel-health-checks -n 100

# Test check manually
cd /opt/beszel-health
sudo -u beszel python3 health_check_runner.py --test
```

### Permission Issues

For checks requiring elevated privileges (like SMART):
```bash
# Check sudoers rule
cat /etc/sudoers.d/beszel-health
```

### Debug Mode

Enable debug logging in `config.yml`:
```yaml
service:
  log_level: DEBUG
```

## Security Considerations

- Runs as non-root user (beszel)
- Limited sudo access only for specific commands
- Systemd security restrictions
- No network access except for configured endpoints

## Uninstall

```bash
sudo ./install.sh uninstall
```

## Examples Directory

See the `checks/` directory for example implementations:
- `ssl_expiry.py` - SSL certificate monitoring
- `disk_smart.py` - Disk health monitoring
- `service_health.py` - Service and process monitoring
- `example_custom.sh` - Simple bash example

## Contributing

To add new health checks:
1. Create script in `/opt/beszel-health/checks/`
2. Add configuration to `config.yml`
3. Test with `--test` flag
4. Submit PR with documentation

## License

MIT License - See LICENSE file