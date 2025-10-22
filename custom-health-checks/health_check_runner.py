#!/usr/bin/env python3
"""
Beszel Custom Health Check Runner
Executes custom health check scripts and integrates with Beszel monitoring.
"""

import os
import sys
import json
import yaml
import time
import logging
import subprocess
import threading
import schedule
from pathlib import Path
from datetime import datetime, timedelta
from typing import Dict, Any, List, Optional
import requests

class HealthCheckRunner:
    def __init__(self, config_path: str = "/opt/beszel-health/config.yml"):
        self.config_path = Path(config_path)
        self.config = self.load_config()
        self.setup_logging()
        self.metrics_file = Path(self.config['service']['metrics_file'])
        self.metrics_file.parent.mkdir(parents=True, exist_ok=True)
        self.alert_history = {}  # Track last alert times
        self.check_results = {}  # Store latest check results
        
    def load_config(self) -> dict:
        """Load configuration from YAML file"""
        if not self.config_path.exists():
            raise FileNotFoundError(f"Config file not found: {self.config_path}")
        
        with open(self.config_path, 'r') as f:
            return yaml.safe_load(f)
    
    def setup_logging(self):
        """Setup logging configuration"""
        log_level = self.config['service'].get('log_level', 'INFO')
        log_file = Path(self.config['service'].get('log_file', '/opt/beszel-health/logs/health_checks.log'))
        log_file.parent.mkdir(parents=True, exist_ok=True)
        
        logging.basicConfig(
            level=getattr(logging, log_level),
            format='%(asctime)s - %(levelname)s - [%(name)s] - %(message)s',
            handlers=[
                logging.FileHandler(log_file),
                logging.StreamHandler(sys.stdout)
            ]
        )
        self.logger = logging.getLogger('HealthCheckRunner')
        
    def run_check(self, check_config: dict) -> dict:
        """Execute a single health check script"""
        name = check_config['name']
        script_path = Path(check_config['script'])
        timeout = check_config.get('timeout', 30)
        
        if not script_path.is_absolute():
            script_path = Path('/opt/beszel-health') / script_path
        
        if not script_path.exists():
            self.logger.error(f"Script not found: {script_path}")
            return {
                'status': 'unknown',
                'message': f'Script not found: {script_path}',
                'timestamp': datetime.now().isoformat()
            }
        
        try:
            # Prepare environment variables
            env = os.environ.copy()
            env.update(check_config.get('environment', {}))
            
            # Execute the script
            self.logger.debug(f"Running check: {name}")
            result = subprocess.run(
                [str(script_path)],
                capture_output=True,
                text=True,
                timeout=timeout,
                env=env
            )
            
            # Parse the output (expecting JSON)
            if result.returncode == 0:
                try:
                    output = json.loads(result.stdout)
                    output['timestamp'] = datetime.now().isoformat()
                    output['exit_code'] = 0
                    self.logger.info(f"Check {name} completed successfully")
                    return output
                except json.JSONDecodeError:
                    # Fallback for non-JSON output
                    return {
                        'status': 'ok',
                        'message': result.stdout.strip(),
                        'timestamp': datetime.now().isoformat(),
                        'exit_code': 0
                    }
            else:
                self.logger.warning(f"Check {name} failed with exit code {result.returncode}")
                return {
                    'status': 'critical',
                    'message': result.stderr.strip() or f"Check failed with exit code {result.returncode}",
                    'timestamp': datetime.now().isoformat(),
                    'exit_code': result.returncode
                }
                
        except subprocess.TimeoutExpired:
            self.logger.error(f"Check {name} timed out after {timeout} seconds")
            return {
                'status': 'unknown',
                'message': f'Check timed out after {timeout} seconds',
                'timestamp': datetime.now().isoformat()
            }
        except Exception as e:
            self.logger.error(f"Error running check {name}: {e}")
            return {
                'status': 'unknown',
                'message': str(e),
                'timestamp': datetime.now().isoformat()
            }
    
    def evaluate_alert(self, check_name: str, result: dict, check_config: dict) -> bool:
        """Determine if an alert should be sent based on check results"""
        status = result.get('status', 'unknown')
        
        # Check if alert is needed
        if status in ['critical', 'warning']:
            # Check cooldown period
            cooldown = self.config['notifications'].get('alert_cooldown', 3600)
            last_alert = self.alert_history.get(check_name)
            
            if last_alert:
                time_since_last = (datetime.now() - last_alert).total_seconds()
                if time_since_last < cooldown:
                    self.logger.debug(f"Alert for {check_name} in cooldown ({time_since_last:.0f}s < {cooldown}s)")
                    return False
            
            return True
        return False
    
    def send_alert(self, check_name: str, result: dict):
        """Send alert via webhook"""
        if 'notifications' not in self.config:
            return
        
        webhook_url = self.config['notifications'].get('webhook_url')
        if not webhook_url:
            return
        
        status = result.get('status', 'unknown')
        message = result.get('message', 'No message provided')
        
        # Format alert message
        alert_data = {
            'title': f"Health Check Alert: {check_name}",
            'message': f"Status: {status.upper()}\n{message}",
            'timestamp': result.get('timestamp'),
            'server': os.uname().nodename,
            'check': check_name,
            'status': status
        }
        
        try:
            response = requests.post(
                webhook_url,
                json=alert_data,
                timeout=10,
                headers={'Content-Type': 'application/json'}
            )
            
            if response.status_code == 200:
                self.logger.info(f"Alert sent for {check_name}")
                self.alert_history[check_name] = datetime.now()
            else:
                self.logger.error(f"Failed to send alert: {response.status_code}")
                
        except Exception as e:
            self.logger.error(f"Error sending alert: {e}")
    
    def update_metrics_file(self):
        """Write current check results to metrics file"""
        metrics = {
            'timestamp': datetime.now().isoformat(),
            'server': os.uname().nodename,
            'checks': self.check_results
        }
        
        try:
            with open(self.metrics_file, 'w') as f:
                json.dump(metrics, f, indent=2)
            self.logger.debug(f"Updated metrics file: {self.metrics_file}")
        except Exception as e:
            self.logger.error(f"Failed to update metrics file: {e}")
    
    def schedule_check(self, check_config: dict):
        """Schedule a health check to run at specified intervals"""
        name = check_config['name']
        interval = check_config.get('interval', self.config['service']['interval'])
        
        def run_and_evaluate():
            result = self.run_check(check_config)
            self.check_results[name] = result
            
            if self.evaluate_alert(name, result, check_config):
                self.send_alert(name, result)
            
            self.update_metrics_file()
        
        # Run immediately on startup
        run_and_evaluate()
        
        # Schedule for future runs
        schedule.every(interval).seconds.do(run_and_evaluate)
        self.logger.info(f"Scheduled check '{name}' to run every {interval} seconds")
    
    def run(self):
        """Main run loop"""
        self.logger.info("Starting Beszel Custom Health Check Runner")
        
        # Schedule all checks
        for check in self.config.get('checks', []):
            try:
                self.schedule_check(check)
            except Exception as e:
                self.logger.error(f"Failed to schedule check {check.get('name', 'unknown')}: {e}")
        
        # Run the schedule loop
        self.logger.info("Health check runner started successfully")
        while True:
            try:
                schedule.run_pending()
                time.sleep(1)
            except KeyboardInterrupt:
                self.logger.info("Shutting down health check runner")
                break
            except Exception as e:
                self.logger.error(f"Error in main loop: {e}")
                time.sleep(5)

def main():
    """Main entry point"""
    import argparse
    
    parser = argparse.ArgumentParser(description='Beszel Custom Health Check Runner')
    parser.add_argument(
        '--config',
        default='/opt/beszel-health/config.yml',
        help='Path to configuration file'
    )
    parser.add_argument(
        '--test',
        action='store_true',
        help='Test mode - run all checks once and exit'
    )
    
    args = parser.parse_args()
    
    try:
        runner = HealthCheckRunner(args.config)
        
        if args.test:
            # Test mode - run all checks once
            for check in runner.config.get('checks', []):
                print(f"\nTesting check: {check['name']}")
                result = runner.run_check(check)
                print(json.dumps(result, indent=2))
        else:
            # Normal operation
            runner.run()
            
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)

if __name__ == '__main__':
    main()