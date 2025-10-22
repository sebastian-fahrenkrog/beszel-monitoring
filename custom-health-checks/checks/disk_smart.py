#!/usr/bin/env python3
"""
Disk SMART Health Check
Monitors disk SMART status and critical attributes
"""

import json
import subprocess
import sys
import re
import os

def get_smart_status(device):
    """Get SMART status for a disk device"""
    try:
        # Run smartctl command
        cmd = ['sudo', 'smartctl', '-H', '-A', '-j', device]
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=10)
        
        if result.returncode not in [0, 4]:  # 4 = SMART command failed but device exists
            return None
        
        # Parse JSON output
        try:
            data = json.loads(result.stdout)
        except json.JSONDecodeError:
            # Fallback to text parsing
            return parse_smart_text(result.stdout, device)
        
        # Extract health status
        health_passed = data.get('smart_status', {}).get('passed', False)
        
        # Extract critical attributes
        attributes = {}
        ata_attributes = data.get('ata_smart_attributes', {}).get('table', [])
        
        critical_attrs = {
            5: 'Reallocated_Sectors',
            187: 'Reported_Uncorrectable',
            188: 'Command_Timeout',
            197: 'Current_Pending_Sectors',
            198: 'Offline_Uncorrectable'
        }
        
        for attr in ata_attributes:
            attr_id = attr.get('id')
            if attr_id in critical_attrs:
                attributes[critical_attrs[attr_id]] = attr.get('raw', {}).get('value', 0)
        
        # Get temperature if available
        temperature = data.get('temperature', {}).get('current')
        
        return {
            'device': device,
            'health_passed': health_passed,
            'attributes': attributes,
            'temperature': temperature
        }
        
    except subprocess.TimeoutExpired:
        return {'device': device, 'error': 'Timeout'}
    except Exception as e:
        return {'device': device, 'error': str(e)}

def parse_smart_text(output, device):
    """Fallback text parser for smartctl output"""
    health_passed = 'PASSED' in output or 'OK' in output
    
    attributes = {}
    # Simple regex patterns for common attributes
    patterns = {
        'Reallocated_Sectors': r'Reallocated_Sector_Ct.*\s+(\d+)\s*$',
        'Current_Pending_Sectors': r'Current_Pending_Sector.*\s+(\d+)\s*$',
        'Offline_Uncorrectable': r'Offline_Uncorrectable.*\s+(\d+)\s*$'
    }
    
    for attr_name, pattern in patterns.items():
        match = re.search(pattern, output, re.MULTILINE)
        if match:
            attributes[attr_name] = int(match.group(1))
    
    return {
        'device': device,
        'health_passed': health_passed,
        'attributes': attributes
    }

def evaluate_disk_health(disk_info):
    """Evaluate disk health based on SMART data"""
    if disk_info is None:
        return 'unknown', 'Unable to get SMART data'
    
    if 'error' in disk_info:
        return 'unknown', f"Error: {disk_info['error']}"
    
    # Check overall health
    if not disk_info.get('health_passed', False):
        return 'critical', 'SMART health check failed'
    
    # Check critical attributes
    attributes = disk_info.get('attributes', {})
    warnings = []
    critical = []
    
    if attributes.get('Reallocated_Sectors', 0) > 0:
        warnings.append(f"Reallocated sectors: {attributes['Reallocated_Sectors']}")
    
    if attributes.get('Current_Pending_Sectors', 0) > 0:
        critical.append(f"Pending sectors: {attributes['Current_Pending_Sectors']}")
    
    if attributes.get('Offline_Uncorrectable', 0) > 0:
        critical.append(f"Uncorrectable sectors: {attributes['Offline_Uncorrectable']}")
    
    # Check temperature
    temp = disk_info.get('temperature')
    if temp and temp > 50:
        warnings.append(f"High temperature: {temp}°C")
    elif temp and temp > 60:
        critical.append(f"Critical temperature: {temp}°C")
    
    if critical:
        return 'critical', '; '.join(critical)
    elif warnings:
        return 'warning', '; '.join(warnings)
    else:
        return 'ok', 'All SMART parameters within limits'

def main():
    """Main entry point"""
    # Get list of disks to check from environment or auto-detect
    disks_str = os.environ.get('SMART_DISKS', '')
    
    if disks_str:
        disks = [d.strip() for d in disks_str.split(',')]
    else:
        # Auto-detect disks using lsblk
        try:
            result = subprocess.run(
                ['lsblk', '-d', '-n', '-o', 'NAME,TYPE'],
                capture_output=True,
                text=True
            )
            disks = []
            for line in result.stdout.strip().split('\n'):
                parts = line.split()
                if len(parts) >= 2 and parts[1] == 'disk':
                    disks.append(f"/dev/{parts[0]}")
        except:
            disks = ['/dev/sda', '/dev/sdb']  # Fallback
    
    # Check each disk
    all_results = []
    worst_status = 'ok'
    messages = []
    
    for disk in disks:
        disk_info = get_smart_status(disk)
        status, message = evaluate_disk_health(disk_info)
        
        all_results.append({
            'device': disk,
            'status': status,
            'message': message,
            'data': disk_info
        })
        
        if message != 'All SMART parameters within limits':
            messages.append(f"{disk}: {message}")
        
        # Track worst status
        if status == 'critical':
            worst_status = 'critical'
        elif status == 'warning' and worst_status != 'critical':
            worst_status = 'warning'
        elif status == 'unknown' and worst_status == 'ok':
            worst_status = 'unknown'
    
    # Build output
    output = {
        'status': worst_status,
        'message': '; '.join(messages) if messages else f'All {len(disks)} disks healthy',
        'value': len([d for d in all_results if d['status'] != 'ok']),
        'unit': 'disks with issues',
        'disks': all_results
    }
    
    # Print JSON output
    print(json.dumps(output))
    
    # Exit with appropriate code
    if worst_status == 'critical':
        sys.exit(2)
    elif worst_status == 'warning':
        sys.exit(1)
    else:
        sys.exit(0)

if __name__ == '__main__':
    main()