#!/usr/bin/env python3
"""
SSL Certificate Expiry Check
Checks SSL certificates for upcoming expiration
"""

import json
import ssl
import socket
import sys
from datetime import datetime
import os

def check_ssl_expiry(hostname, port=443):
    """Check SSL certificate expiration for a given host"""
    try:
        # Create SSL context
        context = ssl.create_default_context()
        
        # Connect and get certificate
        with socket.create_connection((hostname, port), timeout=10) as sock:
            with context.wrap_socket(sock, server_hostname=hostname) as ssock:
                cert = ssock.getpeercert()
        
        # Parse expiry date
        expiry_date_str = cert['notAfter']
        expiry_date = datetime.strptime(expiry_date_str, '%b %d %H:%M:%S %Y %Z')
        
        # Calculate days until expiry
        days_remaining = (expiry_date - datetime.now()).days
        
        # Determine status based on days remaining
        if days_remaining < 7:
            status = 'critical'
        elif days_remaining < 30:
            status = 'warning'
        else:
            status = 'ok'
        
        return {
            'status': status,
            'value': days_remaining,
            'unit': 'days',
            'message': f'Certificate for {hostname} expires in {days_remaining} days',
            'details': {
                'hostname': hostname,
                'expiry_date': expiry_date.isoformat(),
                'days_remaining': days_remaining,
                'subject': dict(x[0] for x in cert['subject']),
                'issuer': dict(x[0] for x in cert['issuer'])
            }
        }
        
    except Exception as e:
        return {
            'status': 'critical',
            'message': f'Failed to check SSL certificate for {hostname}: {str(e)}',
            'details': {
                'hostname': hostname,
                'error': str(e)
            }
        }

def main():
    """Main entry point"""
    # Get hosts from environment or use defaults
    hosts_str = os.environ.get('SSL_HOSTS', 'monitoring.inproma.de,ai.content-optimizer.de')
    hosts = [h.strip() for h in hosts_str.split(',')]
    
    all_results = []
    worst_status = 'ok'
    min_days = float('inf')
    
    for host in hosts:
        # Parse host:port if port is specified
        if ':' in host:
            hostname, port = host.split(':')
            port = int(port)
        else:
            hostname = host
            port = 443
        
        result = check_ssl_expiry(hostname, port)
        all_results.append(result)
        
        # Track worst status
        if result['status'] == 'critical':
            worst_status = 'critical'
        elif result['status'] == 'warning' and worst_status != 'critical':
            worst_status = 'warning'
        
        # Track minimum days
        if 'value' in result:
            min_days = min(min_days, result['value'])
    
    # Aggregate results
    output = {
        'status': worst_status,
        'value': min_days if min_days != float('inf') else 0,
        'unit': 'days',
        'message': f'Checked {len(hosts)} SSL certificates',
        'certificates': all_results
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