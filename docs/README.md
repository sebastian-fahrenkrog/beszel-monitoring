# Beszel Monitoring Documentation

Complete documentation for the Beszel monitoring system deployment at monitoring.inproma.de

## 📖 Documentation Structure

### Getting Started
- **[QUICK_REFERENCE.md](QUICK_REFERENCE.md)** - Start here! Quick commands and navigation map
- **[NEW_SERVER_SETUP.md](NEW_SERVER_SETUP.md)** - Complete guide for adding new servers

### Operations
- **[REMOVE_SERVER.md](REMOVE_SERVER.md)** - How to remove servers from monitoring
- **[SERVERS.md](SERVERS.md)** - Inventory of all monitored servers (26 servers)
- **[WEBSOCKET_TROUBLESHOOTING.md](WEBSOCKET_TROUBLESHOOTING.md)** - Fix connection issues

### Advanced Topics
- **[HEALTH_CHECK_CAPABILITIES.md](HEALTH_CHECK_CAPABILITIES.md)** - Monitoring capabilities, alerts, and strategies
- **[CONFIG_MANAGEMENT.md](CONFIG_MANAGEMENT.md)** - Infrastructure as Code with config.yml
- **[MONITORING_STRATEGY_COMPARISON.md](MONITORING_STRATEGY_COMPARISON.md)** - Beszel vs Uptime Kuma
- **[SECURITY.md](SECURITY.md)** - Security best practices

## 🚀 Quick Start

**Add a new server:**
```bash
./scripts/add-server-auto.sh root@new-server.com
```

**Access dashboard:**
https://monitoring.inproma.de

**View server inventory:**
See [SERVERS.md](SERVERS.md)

## 📊 System Overview

- **Hub**: monitoring.inproma.de
- **Monitored Servers**: 26 active agents
- **Connection**: Agent-initiated WebSocket (no firewall changes needed)
- **Features**: Auto-updates, auto-reconnection, permanent tokens

## 🔗 External Resources

- **Beszel GitHub**: https://github.com/henrygd/beszel
- **Installation Scripts**: `/scripts/` directory
- **Source Code Reference**: `/ai_docs/src/beszel/` directory

## 📝 Recent Changes

- **2024-10-24**: Documentation consolidation - removed 4 redundant files
- **2024-10-23**: Added 24 whistle-ranger.de servers
- **2024-10-22**: Added master.corespot-manager.com, backup01.inproma.de

## 🤝 Contributing

When adding or modifying documentation:
1. Keep it concise - avoid duplication
2. Update cross-references when changing file structure
3. Test all code examples
4. Update SERVERS.md when adding/removing servers
