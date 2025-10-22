# Custom Health Checks for Beszel Monitoring

## Overview

While Beszel doesn't natively support custom health check scripts, we can integrate custom checks through several approaches. This document provides solutions for adding custom health monitoring to your Beszel-monitored servers.

## Current Beszel Architecture

### What Beszel Currently Monitors
- CPU, Memory, Disk usage
- Network I/O statistics
- Temperature sensors
- GPU metrics (NVIDIA, AMD, Intel)
- Docker container statistics
- Load average
- Battery status

### How Beszel Works
1. **Agent collects metrics** every cache interval (default 1-3 seconds)
2. **WebSocket communication** sends data to hub
3. **Hub processes alerts** based on thresholds
4. **No custom script execution** in current design

## Solutions for Custom Health Checks

### Solution 1: External Health Check Service with Webhook Integration

Create a separate service that runs custom checks and sends alerts to Beszel's notification webhooks.

#### Architecture
```
Custom Health Check Service
    ↓ (runs checks)
    ↓ (evaluates results)
    ↓ (if alert needed)
Webhook → Beszel Notifications
```

### Solution 2: Metrics Exporter to System Stats

Export custom metrics to system files that Beszel already monitors.

#### Approach
- Write metrics to `/proc`-like files
- Use temperature sensor format
- Leverage existing disk/network monitoring

### Solution 3: Docker Container Health Checks

If using Docker, leverage container health checks that Beszel already monitors.

#### Implementation
```dockerfile
HEALTHCHECK --interval=30s --timeout=10s \
  CMD python /health_check.py || exit 1
```

### Solution 4: Custom Agent Extension (Recommended)

Extend the Beszel agent with a custom health check module that runs alongside the main agent.

## Implementation: Custom Health Check Service

### Architecture Design

```
┌─────────────────────────────────┐
│     Beszel Agent (existing)     │
│   - Collects system metrics     │
│   - WebSocket to hub            │
└─────────────────────────────────┘
                ↑
                │ (reads metrics file)
                │
┌─────────────────────────────────┐
│  Custom Health Check Service    │
│   - Runs Python/Bash scripts    │
│   - Writes to metrics file      │
│   - Sends alerts via webhook    │
└─────────────────────────────────┘
```

### Features
- **Script Execution**: Run any Python, Bash, or executable scripts
- **Scheduling**: Cron-like scheduling for different check intervals
- **Result Storage**: JSON file with metrics Beszel can read
- **Alert Integration**: Direct webhook alerts to Beszel notifications
- **Logging**: Structured logging for debugging

## File Structure

```
/opt/beszel-health-checks/
├── health_check_service.py      # Main service
├── config.yml                   # Configuration
├── checks/                       # Health check scripts
│   ├── disk_smart.py
│   ├── ssl_expiry.py
│   ├── database_health.py
│   └── custom_app.sh
├── metrics/                      # Output metrics
│   └── health_metrics.json
└── logs/                         # Service logs
    └── health_checks.log
```

## Configuration Format

```yaml
# /opt/beszel-health-checks/config.yml
service:
  interval: 60  # Default check interval in seconds
  metrics_file: /opt/beszel-health-checks/metrics/health_metrics.json
  log_level: INFO

# Notification settings (optional)
notifications:
  webhook_url: "https://monitoring.inproma.de/api/webhook/health"
  alert_cooldown: 3600  # Seconds between repeated alerts

# Health check definitions
checks:
  - name: "SSL Certificate Expiry"
    script: "checks/ssl_expiry.py"
    interval: 3600  # Check every hour
    timeout: 30
    alert_threshold: 7  # Alert if cert expires in 7 days
    
  - name: "Database Health"
    script: "checks/database_health.py"
    interval: 300  # Check every 5 minutes
    timeout: 10
    critical_threshold: 1  # Alert on any error
    
  - name: "Disk SMART Status"
    script: "checks/disk_smart.py"
    interval: 1800  # Check every 30 minutes
    timeout: 60
    
  - name: "Custom Application"
    script: "checks/custom_app.sh"
    interval: 120
    timeout: 15
    environment:
      APP_URL: "http://localhost:8080"
      EXPECTED_RESPONSE: "OK"
```

## Metrics Output Format

The service writes metrics in a format that can be consumed by monitoring systems:

```json
{
  "timestamp": "2024-10-22T10:30:00Z",
  "checks": {
    "ssl_certificate": {
      "status": "warning",
      "value": 5,
      "unit": "days",
      "message": "Certificate expires in 5 days",
      "last_check": "2024-10-22T10:30:00Z"
    },
    "database_health": {
      "status": "ok",
      "value": 1,
      "message": "All databases healthy",
      "metrics": {
        "connections": 45,
        "slow_queries": 2,
        "replication_lag": 0.5
      }
    },
    "disk_smart": {
      "status": "critical",
      "value": 0,
      "message": "Drive /dev/sda has 5 reallocated sectors",
      "details": {
        "sda": {"reallocated_sectors": 5, "temperature": 45},
        "sdb": {"reallocated_sectors": 0, "temperature": 38}
      }
    }
  }
}
```

## Alert Levels

- **ok**: Check passed, no issues
- **warning**: Non-critical issue detected
- **critical**: Immediate attention required
- **unknown**: Check failed to execute

## Integration with Beszel Alerts

### Via Webhook Notifications
1. Configure Beszel user settings with webhook URL
2. Health check service sends formatted alerts
3. Beszel processes and displays notifications

### Via System Metrics
1. Export critical metrics as system stats
2. Configure Beszel alerts on those metrics
3. Automatic integration with existing alerting

## Benefits

- **Flexible**: Run any script in any language
- **Isolated**: Doesn't modify Beszel agent
- **Scalable**: Add unlimited custom checks
- **Maintainable**: Separate configuration and scripts
- **Compatible**: Works with existing Beszel infrastructure