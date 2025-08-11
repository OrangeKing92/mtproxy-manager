#!/usr/bin/env python3
"""
MTProxy Health Check Tool - Comprehensive system monitoring and diagnostics
"""

import os
import sys
import json
import time
import socket
import subprocess
import psutil
from pathlib import Path
from typing import Dict, List, Any, Optional, Tuple
import argparse

# Add project root to Python path
project_root = Path(__file__).parent.parent
sys.path.insert(0, str(project_root))


class HealthChecker:
    """Comprehensive health checking system"""
    
    def __init__(self):
        self.checks = []
        self.results = {}
        
    def run_all_checks(self) -> Dict[str, Any]:
        """Run all health checks"""
        
        self.results = {
            'timestamp': time.time(),
            'overall_status': 'unknown',
            'score': 0,
            'max_score': 0,
            'checks': {}
        }
        
        # Define all checks
        check_functions = [
            ('service_status', self._check_service_status),
            ('process_health', self._check_process_health),
            ('port_availability', self._check_port_availability),
            ('configuration', self._check_configuration),
            ('system_resources', self._check_system_resources),
            ('network_connectivity', self._check_network_connectivity),
            ('log_files', self._check_log_files),
            ('disk_space', self._check_disk_space),
            ('memory_usage', self._check_memory_usage),
            ('cpu_usage', self._check_cpu_usage),
        ]
        
        for check_name, check_func in check_functions:
            try:
                result = check_func()
                self.results['checks'][check_name] = result
                self.results['score'] += result.get('score', 0)
                self.results['max_score'] += result.get('max_score', 1)
            except Exception as e:
                self.results['checks'][check_name] = {
                    'status': 'error',
                    'message': f"Check failed: {e}",
                    'score': 0,
                    'max_score': 1
                }
                self.results['max_score'] += 1
        
        # Calculate overall status
        if self.results['max_score'] > 0:
            percentage = (self.results['score'] / self.results['max_score']) * 100
            
            if percentage >= 90:
                self.results['overall_status'] = 'excellent'
            elif percentage >= 80:
                self.results['overall_status'] = 'good'
            elif percentage >= 60:
                self.results['overall_status'] = 'warning'
            else:
                self.results['overall_status'] = 'critical'
        
        return self.results
    
    def _check_service_status(self) -> Dict[str, Any]:
        """Check if MTProxy service is running"""
        
        result = {
            'name': 'Service Status',
            'status': 'unknown',
            'message': '',
            'details': {},
            'score': 0,
            'max_score': 3
        }
        
        try:
            # Check systemd service
            systemd_result = subprocess.run(
                ['systemctl', 'is-active', 'python-mtproxy'],
                capture_output=True,
                text=True
            )
            
            systemd_active = systemd_result.returncode == 0
            result['details']['systemd_active'] = systemd_active
            
            if systemd_active:
                result['score'] += 1
                result['message'] = "Service is active"
            
            # Check if enabled
            enabled_result = subprocess.run(
                ['systemctl', 'is-enabled', 'python-mtproxy'],
                capture_output=True,
                text=True
            )
            
            systemd_enabled = enabled_result.returncode == 0
            result['details']['systemd_enabled'] = systemd_enabled
            
            if systemd_enabled:
                result['score'] += 1
            
            # Check process existence
            process_exists = self._find_mtproxy_process() is not None
            result['details']['process_exists'] = process_exists
            
            if process_exists:
                result['score'] += 1
            
            if result['score'] == 3:
                result['status'] = 'ok'
                result['message'] = "Service is running and enabled"
            elif result['score'] >= 1:
                result['status'] = 'warning'
                result['message'] = "Service has issues"
            else:
                result['status'] = 'critical'
                result['message'] = "Service is not running"
                
        except Exception as e:
            result['status'] = 'error'
            result['message'] = f"Cannot check service status: {e}"
        
        return result
    
    def _check_process_health(self) -> Dict[str, Any]:
        """Check MTProxy process health"""
        
        result = {
            'name': 'Process Health',
            'status': 'unknown',
            'message': '',
            'details': {},
            'score': 0,
            'max_score': 4
        }
        
        try:
            process = self._find_mtproxy_process()
            
            if not process:
                result['status'] = 'critical'
                result['message'] = "MTProxy process not found"
                return result
            
            result['score'] += 1  # Process exists
            result['details']['pid'] = process.pid
            result['details']['status'] = process.status()
            result['details']['create_time'] = process.create_time()
            
            # Check CPU usage
            cpu_percent = process.cpu_percent(interval=1)
            result['details']['cpu_percent'] = cpu_percent
            
            if cpu_percent < 80:
                result['score'] += 1
            
            # Check memory usage
            memory_info = process.memory_info()
            memory_percent = process.memory_percent()
            result['details']['memory_percent'] = memory_percent
            result['details']['memory_rss'] = memory_info.rss
            result['details']['memory_vms'] = memory_info.vms
            
            if memory_percent < 80:
                result['score'] += 1
            
            # Check file descriptors
            try:
                connections = process.connections()
                result['details']['open_files'] = process.num_fds()
                result['details']['connections'] = len(connections)
                result['score'] += 1
            except (psutil.AccessDenied, AttributeError):
                pass
            
            if result['score'] >= 3:
                result['status'] = 'ok'
                result['message'] = f"Process healthy (PID {process.pid})"
            elif result['score'] >= 2:
                result['status'] = 'warning'
                result['message'] = "Process has performance issues"
            else:
                result['status'] = 'critical'
                result['message'] = "Process is unhealthy"
                
        except Exception as e:
            result['status'] = 'error'
            result['message'] = f"Cannot check process health: {e}"
        
        return result
    
    def _check_port_availability(self) -> Dict[str, Any]:
        """Check if MTProxy port is available/listening"""
        
        result = {
            'name': 'Port Availability',
            'status': 'unknown',
            'message': '',
            'details': {},
            'score': 0,
            'max_score': 2
        }
        
        try:
            # Try to load config to get port
            try:
                from mtproxy.config import Config
                config = Config()
                host = config.get('server.host', '0.0.0.0')
                port = config.get('server.port', 8443)
            except:
                host = '0.0.0.0'
                port = 8443
            
            result['details']['host'] = host
            result['details']['port'] = port
            
            # Check if port is listening
            listening = self._is_port_listening(host, port)
            result['details']['listening'] = listening
            
            if listening:
                result['score'] += 1
                result['message'] = f"Port {port} is listening"
            else:
                result['message'] = f"Port {port} is not listening"
            
            # Check if port is accessible externally
            if listening:
                accessible = self._test_port_connection('127.0.0.1', port)
                result['details']['accessible'] = accessible
                
                if accessible:
                    result['score'] += 1
                    result['message'] += " and accessible"
                else:
                    result['message'] += " but not accessible"
            
            if result['score'] == 2:
                result['status'] = 'ok'
            elif result['score'] == 1:
                result['status'] = 'warning'
            else:
                result['status'] = 'critical'
                
        except Exception as e:
            result['status'] = 'error'
            result['message'] = f"Cannot check port: {e}"
        
        return result
    
    def _check_configuration(self) -> Dict[str, Any]:
        """Check configuration validity"""
        
        result = {
            'name': 'Configuration',
            'status': 'unknown',
            'message': '',
            'details': {},
            'score': 0,
            'max_score': 3
        }
        
        try:
            from mtproxy.config import Config
            
            config = Config()
            result['score'] += 1  # Config loads
            
            # Check required settings
            secret = config.get('server.secret')
            if secret and len(secret) == 32:
                result['score'] += 1
                result['details']['secret_valid'] = True
            else:
                result['details']['secret_valid'] = False
            
            port = config.get('server.port')
            if port and 1 <= port <= 65535:
                result['score'] += 1
                result['details']['port_valid'] = True
            else:
                result['details']['port_valid'] = False
            
            result['details']['config_file'] = config.config_file
            
            if result['score'] == 3:
                result['status'] = 'ok'
                result['message'] = "Configuration is valid"
            elif result['score'] >= 1:
                result['status'] = 'warning'
                result['message'] = "Configuration has issues"
            else:
                result['status'] = 'critical'
                result['message'] = "Configuration is invalid"
                
        except Exception as e:
            result['status'] = 'error'
            result['message'] = f"Cannot check configuration: {e}"
        
        return result
    
    def _check_system_resources(self) -> Dict[str, Any]:
        """Check system resource availability"""
        
        result = {
            'name': 'System Resources',
            'status': 'unknown',
            'message': '',
            'details': {},
            'score': 0,
            'max_score': 3
        }
        
        try:
            # CPU usage
            cpu_percent = psutil.cpu_percent(interval=1)
            result['details']['cpu_percent'] = cpu_percent
            
            if cpu_percent < 80:
                result['score'] += 1
            
            # Memory usage
            memory = psutil.virtual_memory()
            result['details']['memory_percent'] = memory.percent
            result['details']['memory_available'] = memory.available
            result['details']['memory_total'] = memory.total
            
            if memory.percent < 80:
                result['score'] += 1
            
            # Load average (if available)
            try:
                load_avg = os.getloadavg()
                result['details']['load_average'] = load_avg
                
                # Check if load is reasonable (less than CPU count)
                cpu_count = psutil.cpu_count()
                if load_avg[0] < cpu_count * 0.8:
                    result['score'] += 1
                else:
                    result['details']['high_load'] = True
            except (OSError, AttributeError):
                result['score'] += 1  # Give benefit of doubt if unavailable
            
            if result['score'] == 3:
                result['status'] = 'ok'
                result['message'] = "System resources are healthy"
            elif result['score'] >= 2:
                result['status'] = 'warning'
                result['message'] = "System resources under pressure"
            else:
                result['status'] = 'critical'
                result['message'] = "System resources critically low"
                
        except Exception as e:
            result['status'] = 'error'
            result['message'] = f"Cannot check system resources: {e}"
        
        return result
    
    def _check_network_connectivity(self) -> Dict[str, Any]:
        """Check network connectivity to Telegram servers"""
        
        result = {
            'name': 'Network Connectivity',
            'status': 'unknown',
            'message': '',
            'details': {},
            'score': 0,
            'max_score': 3
        }
        
        # Telegram data centers to test
        telegram_servers = [
            ("149.154.175.53", 443),  # DC1
            ("149.154.167.51", 443),  # DC2
            ("149.154.175.100", 443), # DC3
        ]
        
        successful_connections = 0
        
        for host, port in telegram_servers:
            try:
                reachable = self._test_port_connection(host, port, timeout=5)
                result['details'][f"{host}:{port}"] = reachable
                
                if reachable:
                    successful_connections += 1
                    
            except Exception as e:
                result['details'][f"{host}:{port}"] = f"Error: {e}"
        
        # Score based on successful connections
        if successful_connections >= 3:
            result['score'] = 3
            result['status'] = 'ok'
            result['message'] = "All Telegram servers reachable"
        elif successful_connections >= 2:
            result['score'] = 2
            result['status'] = 'warning'
            result['message'] = "Most Telegram servers reachable"
        elif successful_connections >= 1:
            result['score'] = 1
            result['status'] = 'warning'
            result['message'] = "Limited Telegram server connectivity"
        else:
            result['score'] = 0
            result['status'] = 'critical'
            result['message'] = "Cannot reach Telegram servers"
        
        return result
    
    def _check_log_files(self) -> Dict[str, Any]:
        """Check log file accessibility and recent activity"""
        
        result = {
            'name': 'Log Files',
            'status': 'unknown',
            'message': '',
            'details': {},
            'score': 0,
            'max_score': 2
        }
        
        log_locations = [
            "/opt/python-mtproxy/logs/mtproxy.log",
            "logs/mtproxy.log",
            "/var/log/python-mtproxy.log",
        ]
        
        log_file_found = False
        recent_activity = False
        
        for log_path in log_locations:
            if os.path.exists(log_path):
                log_file_found = True
                result['details']['log_file'] = log_path
                
                try:
                    # Check file size
                    size = os.path.getsize(log_path)
                    result['details']['log_size'] = size
                    
                    # Check modification time
                    mtime = os.path.getmtime(log_path)
                    age = time.time() - mtime
                    result['details']['log_age_seconds'] = age
                    
                    # Recent activity if modified within last hour
                    if age < 3600:
                        recent_activity = True
                    
                    break
                    
                except Exception as e:
                    result['details']['log_error'] = str(e)
        
        if log_file_found:
            result['score'] += 1
            
        if recent_activity:
            result['score'] += 1
        
        if result['score'] == 2:
            result['status'] = 'ok'
            result['message'] = "Log files are accessible and active"
        elif result['score'] == 1:
            result['status'] = 'warning'
            result['message'] = "Log files found but no recent activity"
        else:
            result['status'] = 'critical'
            result['message'] = "No log files found"
        
        return result
    
    def _check_disk_space(self) -> Dict[str, Any]:
        """Check disk space availability"""
        
        result = {
            'name': 'Disk Space',
            'status': 'unknown',
            'message': '',
            'details': {},
            'score': 0,
            'max_score': 1
        }
        
        try:
            disk_usage = psutil.disk_usage('/')
            usage_percent = (disk_usage.used / disk_usage.total) * 100
            
            result['details']['total'] = disk_usage.total
            result['details']['used'] = disk_usage.used
            result['details']['free'] = disk_usage.free
            result['details']['percent_used'] = usage_percent
            
            if usage_percent < 90:
                result['score'] = 1
                result['status'] = 'ok'
                result['message'] = f"Disk space OK ({usage_percent:.1f}% used)"
            else:
                result['status'] = 'critical'
                result['message'] = f"Low disk space ({usage_percent:.1f}% used)"
                
        except Exception as e:
            result['status'] = 'error'
            result['message'] = f"Cannot check disk space: {e}"
        
        return result
    
    def _check_memory_usage(self) -> Dict[str, Any]:
        """Check memory usage"""
        
        result = {
            'name': 'Memory Usage',
            'status': 'unknown',
            'message': '',
            'details': {},
            'score': 0,
            'max_score': 1
        }
        
        try:
            memory = psutil.virtual_memory()
            
            result['details']['total'] = memory.total
            result['details']['available'] = memory.available
            result['details']['percent'] = memory.percent
            result['details']['used'] = memory.used
            
            if memory.percent < 85:
                result['score'] = 1
                result['status'] = 'ok'
                result['message'] = f"Memory usage OK ({memory.percent:.1f}%)"
            else:
                result['status'] = 'warning'
                result['message'] = f"High memory usage ({memory.percent:.1f}%)"
                
        except Exception as e:
            result['status'] = 'error'
            result['message'] = f"Cannot check memory usage: {e}"
        
        return result
    
    def _check_cpu_usage(self) -> Dict[str, Any]:
        """Check CPU usage"""
        
        result = {
            'name': 'CPU Usage',
            'status': 'unknown',
            'message': '',
            'details': {},
            'score': 0,
            'max_score': 1
        }
        
        try:
            cpu_percent = psutil.cpu_percent(interval=2)
            cpu_count = psutil.cpu_count()
            
            result['details']['percent'] = cpu_percent
            result['details']['count'] = cpu_count
            
            if cpu_percent < 80:
                result['score'] = 1
                result['status'] = 'ok'
                result['message'] = f"CPU usage OK ({cpu_percent:.1f}%)"
            else:
                result['status'] = 'warning'
                result['message'] = f"High CPU usage ({cpu_percent:.1f}%)"
                
        except Exception as e:
            result['status'] = 'error'
            result['message'] = f"Cannot check CPU usage: {e}"
        
        return result
    
    def _find_mtproxy_process(self) -> Optional[psutil.Process]:
        """Find MTProxy process"""
        
        for process in psutil.process_iter(['pid', 'name', 'cmdline']):
            try:
                if 'mtproxy' in process.info['name'].lower():
                    return process
                
                cmdline = ' '.join(process.info['cmdline'] or [])
                if 'mtproxy' in cmdline.lower():
                    return process
                    
            except (psutil.NoSuchProcess, psutil.AccessDenied):
                continue
        
        return None
    
    def _is_port_listening(self, host: str, port: int) -> bool:
        """Check if port is listening"""
        
        try:
            for conn in psutil.net_connections(kind='inet'):
                if conn.laddr.port == port:
                    if host == '0.0.0.0' or conn.laddr.ip == host:
                        return True
            return False
        except:
            return False
    
    def _test_port_connection(self, host: str, port: int, timeout: int = 3) -> bool:
        """Test if we can connect to a port"""
        
        try:
            sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            sock.settimeout(timeout)
            result = sock.connect_ex((host, port))
            sock.close()
            return result == 0
        except:
            return False


def format_health_report(results: Dict[str, Any], json_format: bool = False) -> str:
    """Format health check results"""
    
    if json_format:
        return json.dumps(results, indent=2)
    
    output = []
    
    # Header
    timestamp = time.strftime('%Y-%m-%d %H:%M:%S', time.localtime(results['timestamp']))
    score_pct = (results['score'] / results['max_score']) * 100 if results['max_score'] > 0 else 0
    
    output.append("MTProxy Health Check Report")
    output.append("=" * 50)
    output.append(f"Timestamp: {timestamp}")
    output.append(f"Overall Status: {results['overall_status'].upper()}")
    output.append(f"Health Score: {results['score']}/{results['max_score']} ({score_pct:.1f}%)")
    output.append("")
    
    # Individual checks
    for check_name, check_result in results['checks'].items():
        status_symbol = {
            'ok': '✓',
            'warning': '⚠',
            'critical': '✗',
            'error': '!',
            'unknown': '?'
        }.get(check_result['status'], '?')
        
        output.append(f"{status_symbol} {check_result['name']}: {check_result['message']}")
        
        # Show details for failed checks
        if check_result['status'] in ['warning', 'critical', 'error'] and check_result.get('details'):
            for key, value in check_result['details'].items():
                if isinstance(value, (int, float)):
                    if 'byte' in key.lower() or 'size' in key.lower():
                        value = f"{value / (1024**3):.1f} GB"
                    elif 'percent' in key.lower():
                        value = f"{value:.1f}%"
                output.append(f"  {key}: {value}")
    
    return '\n'.join(output)


def main():
    """Main entry point"""
    parser = argparse.ArgumentParser(description='MTProxy Health Check Tool')
    parser.add_argument('--json', action='store_true', help='Output in JSON format')
    parser.add_argument('--network', action='store_true', help='Run network connectivity tests only')
    parser.add_argument('--performance', action='store_true', help='Run performance checks only')
    
    args = parser.parse_args()
    
    checker = HealthChecker()
    
    try:
        if args.network:
            # Only network checks
            result = checker._check_network_connectivity()
            results = {
                'timestamp': time.time(),
                'checks': {'network_connectivity': result}
            }
        elif args.performance:
            # Only performance checks
            results = {
                'timestamp': time.time(),
                'checks': {
                    'system_resources': checker._check_system_resources(),
                    'memory_usage': checker._check_memory_usage(),
                    'cpu_usage': checker._check_cpu_usage(),
                    'disk_space': checker._check_disk_space(),
                }
            }
        else:
            # All checks
            results = checker.run_all_checks()
        
        # Output results
        report = format_health_report(results, json_format=args.json)
        print(report)
        
        # Exit with appropriate code
        if not args.json:
            overall_status = results.get('overall_status', 'unknown')
            if overall_status in ['critical', 'error']:
                sys.exit(1)
            elif overall_status == 'warning':
                sys.exit(2)
            else:
                sys.exit(0)
    
    except KeyboardInterrupt:
        print("\nHealth check interrupted")
        sys.exit(1)
    except Exception as e:
        print(f"Health check failed: {e}")
        sys.exit(1)


if __name__ == '__main__':
    main()
