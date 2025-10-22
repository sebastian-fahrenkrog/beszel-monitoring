#!/usr/bin/env python3
"""
Service Health Check
Monitors systemd services and critical processes
"""

import json
import subprocess
import sys
import os
import psutil

def check_systemd_service(service_name):
    """Check if a systemd service is running"""
    try:
        result = subprocess.run(
            ['systemctl', 'is-active', service_name],
            capture_output=True,
            text=True,
            timeout=5
        )
        
        is_active = result.stdout.strip() == 'active'
        
        # Get more details
        result = subprocess.run(
            ['systemctl', 'status', service_name, '--no-pager', '-n', '0'],
            capture_output=True,
            text=True,
            timeout=5
        )
        
        # Parse status output
        status_lines = result.stdout.split('\n')
        details = {}
        
        for line in status_lines:
            if 'Active:' in line:
                details['state'] = line.strip()
            elif 'Main PID:' in line:
                details['pid'] = line.strip()
            elif 'Memory:' in line:
                details['memory'] = line.strip()
        
        return {
            'service': service_name,
            'active': is_active,
            'details': details
        }
        
    except Exception as e:
        return {
            'service': service_name,
            'active': False,
            'error': str(e)
        }

def check_process(process_name):
    """Check if a process is running"""
    try:
        processes = []
        for proc in psutil.process_iter(['pid', 'name', 'cpu_percent', 'memory_info']):
            try:
                if process_name.lower() in proc.info['name'].lower():
                    processes.append({
                        'pid': proc.info['pid'],
                        'name': proc.info['name'],
                        'cpu_percent': proc.cpu_percent(interval=0.1),
                        'memory_mb': proc.info['memory_info'].rss / 1024 / 1024
                    })
            except (psutil.NoSuchProcess, psutil.AccessDenied):
                continue
        
        return {
            'process': process_name,
            'running': len(processes) > 0,
            'count': len(processes),
            'instances': processes
        }
        
    except Exception as e:
        return {
            'process': process_name,
            'running': False,
            'error': str(e)
        }

def check_port(port, host='127.0.0.1'):
    """Check if a port is listening"""
    import socket
    
    try:
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.settimeout(2)
        result = sock.connect_ex((host, port))
        sock.close()
        
        return {
            'port': port,
            'host': host,
            'listening': result == 0
        }
        
    except Exception as e:
        return {
            'port': port,
            'host': host,
            'listening': False,
            'error': str(e)
        }

def main():
    """Main entry point"""
    # Get configuration from environment
    services = os.environ.get('CHECK_SERVICES', 'beszel-agent,docker,nginx').split(',')
    processes = os.environ.get('CHECK_PROCESSES', '').split(',') if os.environ.get('CHECK_PROCESSES') else []
    ports = os.environ.get('CHECK_PORTS', '').split(',') if os.environ.get('CHECK_PORTS') else []
    
    all_checks = []
    failed_checks = []
    warning_checks = []
    
    # Check systemd services
    for service in services:
        service = service.strip()
        if not service:
            continue
            
        result = check_systemd_service(service)
        all_checks.append({
            'type': 'service',
            'name': service,
            'result': result
        })
        
        if not result.get('active', False):
            failed_checks.append(f"Service {service} is not active")
    
    # Check processes
    for process in processes:
        process = process.strip()
        if not process:
            continue
            
        result = check_process(process)
        all_checks.append({
            'type': 'process',
            'name': process,
            'result': result
        })
        
        if not result.get('running', False):
            warning_checks.append(f"Process {process} is not running")
    
    # Check ports
    for port_spec in ports:
        port_spec = port_spec.strip()
        if not port_spec:
            continue
            
        # Parse host:port or just port
        if ':' in port_spec:
            host, port = port_spec.rsplit(':', 1)
            port = int(port)
        else:
            host = '127.0.0.1'
            port = int(port_spec)
        
        result = check_port(port, host)
        all_checks.append({
            'type': 'port',
            'name': f"{host}:{port}",
            'result': result
        })
        
        if not result.get('listening', False):
            warning_checks.append(f"Port {host}:{port} is not listening")
    
    # Determine overall status
    if failed_checks:
        status = 'critical'
        message = '; '.join(failed_checks)
    elif warning_checks:
        status = 'warning'
        message = '; '.join(warning_checks)
    else:
        status = 'ok'
        message = f"All {len(all_checks)} checks passed"
    
    # Build output
    output = {
        'status': status,
        'message': message,
        'value': len(failed_checks) + len(warning_checks),
        'unit': 'failed checks',
        'checks': all_checks,
        'summary': {
            'total': len(all_checks),
            'passed': len(all_checks) - len(failed_checks) - len(warning_checks),
            'failed': len(failed_checks),
            'warnings': len(warning_checks)
        }
    }
    
    # Print JSON output
    print(json.dumps(output))
    
    # Exit with appropriate code
    if status == 'critical':
        sys.exit(2)
    elif status == 'warning':
        sys.exit(1)
    else:
        sys.exit(0)

if __name__ == '__main__':
    main()