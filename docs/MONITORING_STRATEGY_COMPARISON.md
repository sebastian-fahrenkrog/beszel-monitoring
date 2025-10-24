# Monitoring Strategy Comparison: Beszel vs Uptime Kuma

## Executive Summary

For complete GlobaLeaks monitoring on whistle-ranger.de servers, use **both tools together**:

- **Beszel**: System-level monitoring (infrastructure)
- **Uptime Kuma**: Application-level monitoring (GlobaLeaks service)

## Side-by-Side Comparison

| Feature | Beszel | Uptime Kuma |
|---------|--------|-------------|
| **Primary Purpose** | System resource monitoring | HTTP/service availability monitoring |
| **What It Monitors** | CPU, RAM, Disk, Network, Docker stats | HTTP endpoints, response codes, uptime |
| **Architecture** | Hub + Agent (WebSocket) | Centralized HTTP polling |
| **Installation** | Agent on each server | No agent needed |
| **Network Requirements** | Agent initiates connection to hub | Hub polls servers via HTTP |
| **Metrics Storage** | Multiple granularities (1m to 8h) | Heartbeat history (configurable) |
| **Alerts** | CPU, Memory, Disk, Status, etc. | Up/Down, Response time |
| **Dashboard** | System metrics graphs | Status grid with uptime % |
| **Best For** | Infrastructure monitoring | Application health checks |

## What Each Tool Detects

### Beszel Can Detect

✅ Server is offline/unreachable
✅ High CPU usage (>90%)
✅ High memory usage (>95%)
✅ Disk space running out
✅ High network traffic
✅ Docker container status (if HEALTHCHECK configured)
✅ System load average
✅ Temperature issues
✅ GPU problems (if present)

❌ Cannot detect: GlobaLeaks service crashed (if running as systemd)
❌ Cannot detect: Application-level errors
❌ Cannot detect: HTTP endpoint failures

### Uptime Kuma Can Detect

✅ HTTP endpoint returning error (502, 503, etc.)
✅ Service not responding (timeout)
✅ Slow response times (>5s)
✅ SSL certificate issues
✅ Status code changes (200 → 500)
✅ Service uptime % over time

❌ Cannot detect: Why service failed (CPU, memory, disk?)
❌ Cannot detect: System-level resource exhaustion
❌ Cannot detect: Infrastructure issues

### Together They Detect Everything

✅ **Infrastructure failures** (Beszel)
✅ **Application failures** (Uptime Kuma)
✅ **Performance degradation** (both)
✅ **Root cause analysis** (correlation)

## Real-World Scenarios

### Scenario 1: GlobaLeaks Service Crashes

| Tool | What It Shows | Interpretation |
|------|---------------|----------------|
| Beszel | 🟢 System healthy, low CPU/RAM | Server is fine |
| Uptime Kuma | 🔴 Service DOWN (timeout) | Application crashed |
| **Root Cause** | **GlobaLeaks process terminated** | → Restart service |

**Without Uptime Kuma**: You wouldn't know GlobaLeaks is down (server metrics look fine)

### Scenario 2: Server Completely Down

| Tool | What It Shows | Interpretation |
|------|---------------|----------------|
| Beszel | 🔴 Server offline | Cannot connect |
| Uptime Kuma | 🔴 Service DOWN (timeout) | Cannot connect |
| **Root Cause** | **Infrastructure issue** | → Check power/network |

**Both tools alert**: High priority, server completely unreachable

### Scenario 3: High Load But Still Running

| Tool | What It Shows | Interpretation |
|------|---------------|----------------|
| Beszel | 🟡 High CPU (95%), high memory | Under heavy load |
| Uptime Kuma | 🟢 Service UP (slow response) | Still responding |
| **Root Cause** | **Performance degradation** | → Investigate load source |

**Beszel catches it first**: Can alert before service fails

### Scenario 4: Network/Firewall Issue

| Tool | What It Shows | Interpretation |
|------|---------------|----------------|
| Beszel | 🟢 System healthy | Agent can reach hub |
| Uptime Kuma | 🔴 Service DOWN | Cannot reach :8443 |
| **Root Cause** | **Firewall blocking port 8443** | → Check firewall rules |

**Uptime Kuma alerts**: External connectivity issue

### Scenario 5: Out of Disk Space

| Tool | What It Shows | Interpretation |
|------|---------------|----------------|
| Beszel | 🔴 Disk usage 100% | Out of space |
| Uptime Kuma | 🔴 Service DOWN (500 error) | Database write failed |
| **Root Cause** | **Disk full → GlobaLeaks cannot write logs** | → Free disk space |

**Beszel shows root cause**: Disk space issue → application fails

## Implementation Strategies

### Strategy 1: Uptime Kuma Only (Not Recommended)

```
✅ Pros:
- Simple setup (no agent)
- Easy to add monitors
- Good for basic availability

❌ Cons:
- No infrastructure visibility
- Cannot diagnose root cause
- Misses performance issues
- No resource trending
```

**Use case**: Small deployments, non-critical systems

### Strategy 2: Beszel Only (Limited)

```
✅ Pros:
- Excellent infrastructure monitoring
- Resource trending
- System alerts

❌ Cons:
- Misses application-level failures (systemd services)
- Only catches Docker health if HEALTHCHECK configured
- No external endpoint monitoring
```

**Use case**: Only if GlobaLeaks runs in Docker with HEALTHCHECK

### Strategy 3: Both Tools (RECOMMENDED)

```
✅ Pros:
- Complete visibility (infrastructure + application)
- Root cause analysis (correlate data)
- Catch issues at both layers
- Redundant monitoring (belt + suspenders)

❌ Cons:
- Two systems to maintain
- Slightly more complex setup
```

**Use case**: Production environments (whistle-ranger.de servers)

## Decision Matrix

**Choose monitoring strategy based on deployment type**:

| GlobaLeaks Deployment | Recommended Strategy | Rationale |
|----------------------|---------------------|-----------|
| **Docker with HEALTHCHECK** | Beszel only (or + Uptime Kuma for redundancy) | Docker health check handles application monitoring |
| **Systemd service** | Beszel + Uptime Kuma | Beszel can't monitor systemd services directly |
| **Mixed (some Docker, some systemd)** | Beszel + Uptime Kuma | Unified monitoring across all deployments |
| **External availability critical** | Must include Uptime Kuma | Tests from outside, catches network issues |

## Cost Analysis

### Resource Usage

| Tool | CPU | Memory | Disk | Network |
|------|-----|--------|------|---------|
| **Beszel Hub** | ~50MB RAM | ~100MB disk | Minimal | Agent WebSocket |
| **Beszel Agent** (per server) | ~10MB RAM | ~20MB disk | Minimal | Metrics every 1m |
| **Uptime Kuma** | ~100MB RAM | ~200MB disk | Minimal | HTTP polls every 60s |
| **Total (22 servers)** | ~350MB RAM | ~650MB disk | Negligible | ~1 req/sec |

**Verdict**: Very lightweight, negligible impact

### Maintenance Time

| Task | Beszel | Uptime Kuma | Both |
|------|--------|-------------|------|
| **Initial Setup** | 30 min | 30 min | 1 hour |
| **Add New Server** | 5 min (run script) | 2 min (manual) or script | 7 min |
| **Daily Checks** | 1 min (dashboard review) | 1 min (dashboard review) | 2 min |
| **Alert Response** | Depends on issue | Depends on issue | Faster (better diagnosis) |
| **Monthly Maintenance** | 15 min | 15 min | 30 min |

**Verdict**: Minimal overhead, significant value

## Recommended Setup for whistle-ranger.de Servers

### Phase 1: Already Complete ✅

- [x] Beszel hub running at monitoring.inproma.de
- [x] Beszel agents installed on all 22 servers
- [x] System metrics being collected
- [x] Uptime Kuma running at uptime.inproma.de

### Phase 2: Add GlobaLeaks Monitors (Next Step)

```bash
# Run the automated script
cd /Users/sebastianfahrenkrog/Documents/projekte/monitoring.inproma.de/scripts/
./add-globaleaks-monitors-uptime-kuma.sh
```

This adds HTTP health checks for all 22 GlobaLeaks instances.

### Phase 3: Configure Alerts

**Beszel Alerts** (already configured or configure now):
- System offline → Critical alert
- CPU > 90% for 10m → Warning alert
- Memory > 95% for 10m → Warning alert
- Disk > 90% → Warning alert

**Uptime Kuma Alerts** (configure after adding monitors):
- Service DOWN (3 failed checks) → Critical alert
- Response time > 5s → Warning alert

### Phase 4: Document Response Procedures

Create runbook for common scenarios:
1. GlobaLeaks service down → Check logs, restart service
2. Server offline → Check power, network
3. High load → Investigate CPU/memory usage
4. Disk full → Clean up logs, expand disk

## Monitoring Dashboard Workflow

### Daily Operations

**Morning Check (2 minutes)**:
1. Open Beszel dashboard (monitoring.inproma.de)
   - Scan for red indicators
   - Check for yellow (warning) indicators
2. Open Uptime Kuma dashboard (uptime.inproma.de)
   - Verify all monitors green
   - Check uptime % (should be >99.5%)

**If Issues Found**:
1. Note which server(s) affected
2. Check both dashboards for correlation
3. SSH to server for investigation
4. Follow incident response runbook

### Alert Response

**Critical Alert Received**:
1. **Acknowledge alert** (stop alert spam)
2. **Check both dashboards**:
   - Beszel: Infrastructure status
   - Uptime Kuma: Application status
3. **Determine priority**:
   - Both red = Critical (server down)
   - Only Uptime Kuma red = High (app crashed)
   - Only Beszel yellow = Medium (performance issue)
4. **Investigate and resolve**
5. **Document incident**

## Migration Path

### Current State
- ✅ Beszel fully deployed (22 servers)
- ✅ Uptime Kuma running (no GlobaLeaks monitors yet)

### To Complete Setup

```bash
# Step 1: Add GlobaLeaks monitors to Uptime Kuma
./scripts/add-globaleaks-monitors-uptime-kuma.sh

# Step 2: Configure notifications in Uptime Kuma
# (via Web UI: Settings → Notifications)

# Step 3: Test on staging server
ssh root@stage.whistle-ranger.de 'systemctl stop globaleaks'
# Wait for alerts from Uptime Kuma
ssh root@stage.whistle-ranger.de 'systemctl start globaleaks'

# Step 4: Document procedures
# Create team runbook based on docs/UPTIME_KUMA_GLOBALEAKS_INTEGRATION.md
```

**Time to complete**: ~1 hour

## Long-Term Optimization

### After 1 Month

**Review metrics**:
- Alert frequency (too many false positives?)
- Response times (any trends?)
- Uptime % per server (identify problem servers)

**Optimize**:
- Adjust alert thresholds
- Increase check intervals if needed (60s → 120s)
- Add auto-remediation scripts

### After 3 Months

**Evaluate**:
- Which alerts were actionable?
- Which alerts were noise?
- Are both tools still needed?

**Decide**:
- Keep both (recommended for production)
- Consolidate if one tool proves sufficient
- Add additional monitoring (logs, APM)

## Conclusion

**For whistle-ranger.de GlobaLeaks servers, use both tools**:

| Tool | Purpose | Critical? |
|------|---------|-----------|
| **Beszel** | Infrastructure monitoring | ✅ Yes |
| **Uptime Kuma** | Application monitoring | ✅ Yes |

**Why both?**
- Beszel can't detect systemd service crashes
- Uptime Kuma can't diagnose infrastructure issues
- Together: Complete visibility + faster incident resolution

**Total effort**: ~1 hour setup, ~2 minutes daily maintenance

**ROI**: Early detection of issues, faster resolution, better uptime

**Next step**: Run `./add-globaleaks-monitors-uptime-kuma.sh`

---

## Quick Reference

### When to Check Beszel
- System down alerts
- High resource usage
- Performance degradation
- Infrastructure issues

### When to Check Uptime Kuma
- Service availability alerts
- Application-level failures
- External connectivity
- Uptime % reporting

### When to Check Both
- Any alert received (correlation)
- Root cause analysis
- Incident response
- Daily/weekly reviews
