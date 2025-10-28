# Monitored Servers

This document tracks all servers currently monitored by the Beszel monitoring system.

**Quick Actions**:
- **Add Server**: See [NEW_SERVER_SETUP.md](NEW_SERVER_SETUP.md)
- **Remove Server**: See [REMOVE_SERVER.md](REMOVE_SERVER.md)
- **Troubleshoot**: See [WEBSOCKET_TROUBLESHOOTING.md](WEBSOCKET_TROUBLESHOOTING.md)

## Hub Server

| Server | URL | Type | Status | Notes |
|--------|-----|------|--------|-------|
| monitoring.inproma.de | https://monitoring.inproma.de | Hub | ✅ Active | Docker deployment with nginx proxy |

## Monitored Agents (27 servers)

| Hostname | IP/Domain | Added | Status | Specs | Notes |
|----------|-----------|-------|--------|-------|-------|
| hosting.dev.testserver.online | m.dev.testserver.online | 2024-10-21 | ✅ Active | Linux | First agent, testing WebSocket mode |
| master.corespot-manager.com | inproma.dataguide.de | 2024-10-22 | ✅ Active | 16 CPU, 61GB RAM, Docker | Production server |
| backup | backup01.inproma.de | 2024-10-22 | ✅ Active | 6 CPU (AMD Ryzen 5 3600), 62GB RAM | Backup server |
| kihub-demo | kihub-demo.prodsgvo.de | 2025-10-28 | ✅ Active | Linux | Demo server
| mangal | mangal.whistle-ranger.de | 2024-10-23 | ✅ Active | Linux | Production server |
| foodstar | foodstar.whistle-ranger.de | 2024-10-23 | ✅ Active | Linux | Production server |
| samtgemeinde-spelle | samtgemeinde-spelle.whistle-ranger.de | 2024-10-23 | ✅ Active | Linux | Production server |
| just | just.whistle-ranger.de | 2024-10-23 | ✅ Active | Linux | Production server |
| dama | dama.whistle-ranger.de | 2024-10-23 | ✅ Active | Linux | Production server |
| gekko | gekko.whistle-ranger.de | 2024-10-23 | ✅ Active | Linux | Production server |
| rebo | rebo.whistle-ranger.de | 2024-10-23 | ✅ Active | Linux | Production server |
| r-und-s | r-und-s.whistle-ranger.de | 2024-10-23 | ✅ Active | Linux | Production server |
| lampe | lampe.whistle-ranger.de | 2024-10-23 | ✅ Active | Linux | Production server |
| bl-kms | bl-kms.whistle-ranger.de | 2024-10-23 | ✅ Active | Linux | Production server |
| shaffi-group | shaffi-group.whistle-ranger.de | 2024-10-23 | ✅ Active | Linux | Production server |
| why | why.whistle-ranger.de | 2024-10-23 | ✅ Active | Linux | Production server |
| rp-timing | rp-timing.whistle-ranger.de | 2024-10-23 | ✅ Active | Linux | Production server |
| rp-jessinghaus | rp-jessinghaus.whistle-ranger.de | 2024-10-23 | ✅ Active | Linux | Production server |
| rp-leipzig | rp-leipzig.whistle-ranger.de | 2024-10-23 | ✅ Active | Linux | Production server |
| rp-dortmund | rp-dortmund.whistle-ranger.de | 2024-10-23 | ✅ Active | Linux | Production server |
| rp | rp.whistle-ranger.de | 2024-10-23 | ✅ Active | Linux | Production server |
| esslust | esslust.whistle-ranger.de | 2024-10-23 | ✅ Active | Linux | Production server |
| hecking | hecking.whistle-ranger.de | 2024-10-23 | ✅ Active | Linux | Production server |
| stage | stage.whistle-ranger.de | 2024-10-23 | ✅ Active | Linux | Staging server |
| whistleblower-bk | whistleblower-bk.de | 2024-10-23 | ✅ Active | Linux | Production server |
| whistleblower | prodsgvo-whistle.de | 2024-10-23 | ✅ Active | Linux | Production server |
| monitoring | monitoring.inproma.de | 2024-10-23 | ✅ Active | Linux | Hub self-monitoring |
| dataguide.sigor.de | dataguide.sigor.de | 2024-10-23 | ✅ Active | Linux | Production server |

### Removed Servers

| Hostname | IP/Domain | Removed | Reason |
|----------|-----------|---------|--------|
| ai.content-optimizer.de | ai.content-optimizer.de | 2024-10-22 | No longer needed for monitoring |

## System Capabilities Summary

### GPU Monitoring
- **Previous**: ai.content-optimizer.de had NVIDIA RTX 4000 SFF Ada Generation
- **Current**: No GPU-equipped servers in monitoring

### Docker Monitoring
- master.corespot-manager.com: Docker installed, container monitoring enabled
- backup: Docker installed, container monitoring enabled

## Installation History

### Bulk Installation - whistle-ranger.de + additional (2024-10-23)
- **Servers Added**: 24 servers (see table above)
- **Method**: Parallel installation via `add-server-auto.sh`
- **Status**: All successfully connected

### Individual Additions
- **2024-10-22**: master.corespot-manager.com, backup01.inproma.de
- **2024-10-21**: hosting.dev.testserver.online (first agent, testing)

### Removals
- **2024-10-22**: ai.content-optimizer.de

## Maintenance Notes

- Universal tokens are regenerated before each bulk installation
- All agents configured with auto-update (daily at 3 AM)
- WebSocket connection mode (no inbound firewall rules needed)
- Agents appear with their actual hostname from `/etc/hostname`

## Related Documentation

- [NEW_SERVER_SETUP.md](NEW_SERVER_SETUP.md) - How to add new servers
- [REMOVE_SERVER.md](REMOVE_SERVER.md) - How to remove servers
- [MONITORING_STRATEGY_COMPARISON.md](MONITORING_STRATEGY_COMPARISON.md) - Monitoring strategy overview
