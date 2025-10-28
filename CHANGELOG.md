# Changelog

All notable changes to this monitoring deployment project will be documented in this file.

## [Unreleased]

### Fixed - 2025-10-28

#### Critical Bug: Systemd Service File Corruption in add-server-auto.sh

**Problem**: When using `add-server-auto.sh` to add new servers, the systemd service file on remote agents was created with corrupted environment variables containing ANSI color codes and log messages instead of the actual token and SSH key values.

**Symptoms**:
- Agent service failed to start
- `journalctl -u beszel-agent` showed: "Failed to load public keys: no key provided"
- Environment variables in `/etc/systemd/system/beszel-agent.service` contained log output like:
  ```
  Environment="BESZEL_AGENT_TOKEN=[0;34m[INFO][0m Regenerating universal token from hub...
  [0;32m[SUCCESS][0m Universal token generated: 0eb2e974...dd30c794
  0eb2e974-3d7d-4ff0-bfe5-d357dd30c794"
  ```

**Root Cause**:
The helper functions `regenerate_universal_token()` and `get_hub_ssh_key()` in `add-server-auto.sh` were outputting log messages to stdout along with the actual return values. When these functions were called with command substitution (`universal_token=$(regenerate_universal_token)`), all stdout output was captured, including the colored log messages.

**Solution**:
- Modified all log output calls in `add-server-auto.sh` to redirect to stderr using `>&2`
- Affected functions:
  - `regenerate_universal_token()` - All `log_info`, `log_success`, `log_error`, and debug `echo` statements
  - `get_hub_ssh_key()` - All logging statements
  - `install_agent_on_server()` - All logging statements
- This ensures only the actual token/key values are captured by command substitution

**Files Changed**:
- `scripts/add-server-auto.sh` - Fixed stdout/stderr separation in helper functions

**Documentation Updates**:
- `docs/WEBSOCKET_TROUBLESHOOTING.md` - Added new error case with manual recovery procedure
- `docs/NEW_SERVER_SETUP.md` - Added "Agent Service Fails to Start" troubleshooting section
- `docs/QUICK_REFERENCE.md` - Added quick fix for corrupted service files
- `docs/SERVERS.md` - Added kihub-demo.prodsgvo.de to monitored servers list

**Manual Recovery Procedure**:
For servers already affected by this bug, administrators can manually extract the actual token and key values (which are present at the end of the corrupted lines) and recreate the systemd service file. See `docs/WEBSOCKET_TROUBLESHOOTING.md` for detailed recovery steps.

### Added - 2025-10-28

- Added kihub-demo.prodsgvo.de to monitored servers (27 servers total)
- Added comprehensive troubleshooting documentation for systemd service file corruption
- Added quick reference commands for checking and fixing corrupted service files

## [1.0.0] - 2024-10-23

### Added
- Initial deployment of Beszel monitoring system
- Hub server setup at monitoring.inproma.de
- Automated server addition script (`add-server-auto.sh`)
- Agent installation script (`install-beszel-agent.sh`)
- Comprehensive documentation suite
- 26 servers initially added to monitoring

### Features
- WebSocket-based agent communication (no inbound firewall rules needed)
- Universal token system for agent registration
- Automatic agent updates (daily at 3 AM)
- Docker container monitoring support
- Real-time metrics collection and display
