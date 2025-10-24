# Beszel Health Check and Monitoring Capabilities

## Quick Reference

### What Beszel Monitors Automatically

**System Level:**
- CPU usage (%), Memory (%), Disk usage (%)
- Disk I/O (MB/s), Network bandwidth (MB/s)
- Load average (1m, 5m, 15m)
- Temperature sensors, GPU usage, Battery status

**Docker Containers:**
- Container status (running, exited, paused)
- Container health status (healthy, unhealthy, starting, none)
- CPU and memory usage per container
- Network I/O per container

### Alert Types Available

| Alert | Trigger | Example |
|-------|---------|---------|
| **CPU** | Exceeds % threshold | Alert if CPU > 85% |
| **Memory** | Exceeds % threshold | Alert if Memory > 90% |
| **Disk** | Exceeds % threshold | Alert if Disk > 85% |
| **Temperature** | Exceeds °C threshold | Alert if Temp > 80°C |
| **LoadAvg** | Exceeds threshold | Alert if Load > 8 |
| **Bandwidth** | Exceeds MB/s threshold | Alert if Network > 500 MB/s |
| **Status** | System up or down | Alert on disconnection |

**Alert Configuration:**
- Threshold value (numeric)
- Min duration (1-60 minutes) - delay before alerting
- Notification channels: Email, Webhooks (Discord, Slack, Telegram, Teams, etc.)

---

## Built-in Health Check System

### Agent Health Check (Lightweight)

**Location**: `agent/health/health.go`

The agent has a simple built-in health check:
- **File**: `/tmp/beszel_health` (timestamp file)
- **Check**: Verifies agent connectivity within 90 seconds
- **Purpose**: External health monitoring

```bash
# External health check script example
if /opt/beszel-agent/beszel-agent health > /dev/null 2>&1; then
    echo "Agent is healthy"
else
    echo "Agent is unhealthy"
fi
```

### Container Health Status Detection

**File**: `agent/docker.go` (lines 309-342)

Beszel automatically monitors Docker container health:

```go
type DockerHealth = uint8

const (
    DockerHealthNone       = iota  // No health check configured
    DockerHealthStarting          // Health check not yet completed
    DockerHealthHealthy           // Passing health check
    DockerHealthUnhealthy         // Failed health check
)
```

**How It Works:**
1. No configuration required - if container has HEALTHCHECK, Beszel automatically monitors it
2. Container health status visible in dashboard
3. Can trigger alerts on health status changes
4. Health is read-only from Docker API (no custom hooks)

**Example Dockerfile with Health Check:**
```dockerfile
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD curl -f http://localhost:8080/health || exit 1
```

---

## System Metrics Collected

### Real-time Metrics (per agent collection)

**File**: `agent/system.go` (lines 77-202)

```
✓ CPU percentage (all cores)
✓ Memory (total, used, cached, swap)
✓ Disk usage (total, used, percentage per filesystem)
✓ Disk I/O (read/write bytes per second)
✓ Network bandwidth (send/receive per second)
✓ Load averages (1m, 5m, 15m)
✓ Temperature sensors (if available)
✓ GPU usage and temperature (NVIDIA, AMD, Intel)
✓ Battery status (laptops)
✓ Uptime
✓ ZFS ARC cache (if applicable)
```

### Container Metrics Tracked

Each container has these metrics monitored:

```go
type Stats struct {
    Name        string       // Container name
    Cpu         float64      // CPU percentage
    Mem         float64      // Memory usage (MB)
    NetworkSent float64      // Network sent (MB)
    NetworkRecv float64      // Network received (MB)
    Health      DockerHealth // Health status (built-in support)
    Status      string       // Container status text
    Id          string       // Container short ID
    Image       string       // Container image
}
```

---

## Alert System Capabilities

### Alert Processing

**Files**: `internal/alerts/alerts.go` and `internal/alerts/alerts_status.go`

Alert worker runs every 15 seconds:
1. Process alert tasks (schedule/cancel)
2. Check pending alerts for expiration
3. Send notifications when conditions met
4. Update alert triggered state in database

**Status Alert Workflow:**
```
System Status Changes (up/down)
    ↓
Check for configured "Status" alerts
    ↓
If DOWN: Schedule delayed alert (respects min duration)
    ↓
If threshold time exceeded: Send alert notification
    ↓
If UP: Cancel pending alert OR send "system recovered" alert
```

### Alert Configuration

Alerts are configured with:
- **Threshold Value**: Numeric value to trigger alert
- **Minimum Duration**: How long threshold must be exceeded (1-60 minutes)
- **Triggered State**: Tracks if alert is currently active
- **Notification Channels**: Email, webhook (multiple providers via Shoutrrr)

---

## Data Storage and History

### Record Types

**File**: `internal/records/records.go`

Metrics stored at different time granularities:

| Type | Duration | Purpose |
|------|----------|---------|
| **1m** | 1 minute | Real-time monitoring, alert evaluation |
| **10m** | 10 minutes | Short-term trends |
| **20m** | 20 minutes | Medium-term trends |
| **120m** | 2 hours | Longer-term patterns |
| **480m** | 8 hours | Daily patterns |

Metrics are automatically aggregated from shorter to longer periods for historical analysis.

---

## What's NOT Built-In: Service/Process Monitoring

### Limitations

Beszel does **NOT** have native support for:

```
✗ Systemd service status monitoring
✗ Process-level monitoring (CPU/memory per process)
✗ Custom service restart detection
✗ Port/TCP connection status
✗ Custom command/script execution
```

### Why No Service Monitoring?

1. **Scope**: Beszel focuses on system-level metrics (CPU, memory, disk, network)
2. **Simplicity**: Minimal agent complexity for reliability
3. **Security**: No arbitrary command execution prevents vulnerabilities
4. **Consistency**: All metrics derive from standard OS APIs, not custom scripts

---

## Practical Monitoring Strategies

### Strategy 1: Docker Container with Health Check (Recommended)

**Best for**: Services that can be containerized

```yaml
# docker-compose.yml
services:
  myapp:
    image: myapp:latest
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/health"]
      interval: 30s
      timeout: 5s
      retries: 3
      start_period: 10s
```

**Result**: Beszel monitors container health automatically
**Alert**: Set alert on status change (up/down)

### Strategy 2: Monitor via System Metrics

**Best for**: Systemd services that can't be containerized

Monitor the application indirectly through its resource impact:
- Alert on CPU threshold (high load = application issue)
- Alert on Memory threshold (memory leak detection)
- Alert on Disk usage (application generating logs)
- Alert on Network bandwidth (abnormal traffic pattern)

### Strategy 3: External Monitoring (Outside Beszel)

**Best for**: HTTP endpoints and external availability

Use complementary tools:
- **Uptime Kuma** for endpoint monitoring
- **Custom alerting system** for specific checks
- **Integration with Beszel** via webhooks

See [MONITORING_STRATEGY_COMPARISON.md](MONITORING_STRATEGY_COMPARISON.md) for detailed comparison.

---

## Example Alert Configurations

### High CPU Alert
- **Type**: CPU
- **Threshold**: 85%
- **Min Duration**: 5 minutes
- **Notify**: Email + Slack
- **Reason**: Alert only on sustained high CPU, not spikes

### Disk Capacity Alert
- **Type**: Disk
- **Threshold**: 85%
- **Min Duration**: 1 minute
- **Notify**: Email
- **Reason**: Prevent disk full situation

### Service Health Alert (Docker)
- **Type**: Status
- **Threshold**: System down
- **Min Duration**: 2 minutes
- **Notify**: SMS + Email
- **Reason**: Delayed alert prevents flapping

### Container Unhealthy Alert
- **Type**: Status (for container)
- **Threshold**: System down
- **Min Duration**: 1 minute
- **Notify**: Discord webhook
- **Reason**: Alert when container health check fails

---

## Handler System Architecture

### Available Handlers

**File**: `agent/handlers.go`

Beszel agents support these built-in request handlers:

```go
handlers := map[action]Handler{
    "GetData":              GetDataHandler{},
    "CheckFingerprint":     CheckFingerprintHandler{},
    "GetContainerLogs":     GetContainerLogsHandler{},
    "GetContainerInfo":     GetContainerInfoHandler{},
}
```

**Key Point**: Handlers are pre-defined and not extensible without code changes. No arbitrary command execution is possible.

---

## Summary: Capabilities

### Built-In Monitoring ✓
- Docker container health status
- System metrics (CPU, memory, disk, network, temp, GPU)
- Load averages
- Alert triggers on metric thresholds
- Multiple notification channels
- Historical data aggregation

### Not Available ✗
- Systemd service status monitoring
- Process-level monitoring
- Custom command/script execution on agent
- TCP port status monitoring
- Custom health check scripts

### Possible Workarounds ✓
- Monitor Docker containers with HEALTHCHECK
- Monitor via system metrics (CPU/memory impact)
- Use external monitoring (Uptime Kuma, custom solution)
- Modify agent code to add custom handlers

---

## Source Code References

### Key Files for Implementation Details

- **Health Check**: `ai_docs/src/beszel/agent/health/health.go`
- **System Metrics**: `ai_docs/src/beszel/agent/system.go`
- **Docker Monitoring**: `ai_docs/src/beszel/agent/docker.go`
- **Alert System**: `ai_docs/src/beszel/internal/alerts/`
- **Handlers**: `ai_docs/src/beszel/agent/handlers.go`
- **Data Entities**: `ai_docs/src/beszel/internal/entities/`
