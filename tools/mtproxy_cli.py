#!/usr/bin/env python3
"""
MTProxy Command Line Interface - Main management tool for SSH remote control
"""

import os
import sys
import json
import time
import subprocess
import argparse
from pathlib import Path
from typing import Dict, Any, Optional, List

# Add project root to Python path
project_root = Path(__file__).parent.parent
sys.path.insert(0, str(project_root))

try:
    from mtproxy.config import Config
    from mtproxy.logger import get_logger, setup_logging
    from mtproxy.utils import (
        is_service_running, get_service_status, format_bytes, 
        format_duration, get_process_info, get_system_info
    )
    from mtproxy.exceptions import ConfigError
except ImportError as e:
    print(f"Error importing modules: {e}")
    print("Make sure you're running this from the project directory")
    sys.exit(1)

# Setup basic logging for CLI
setup_logging({'level': 'INFO', 'file': '/tmp/mtproxy-cli.log'})
logger = get_logger(__name__)


class MTProxyCLI:
    """MTProxy command line interface"""
    
    def __init__(self):
        self.service_name = "python-mtproxy"
        self.project_dir = Path("/opt/python-mtproxy")
        self.pid_file = self.project_dir / "mtproxy.pid"
        
        # Try to load config
        try:
            self.config = Config()
        except Exception:
            self.config = None
    
    def status(self) -> Dict[str, Any]:
        """Get service status"""
        try:
            # Check systemd service status
            service_status = get_service_status(self.service_name)
            
            # Check process status
            pid = self._get_pid()
            process_info = get_process_info(pid) if pid else None
            
            # Get system info
            system_info = get_system_info()
            
            # Get config info
            config_info = {}
            if self.config:
                config_info = {
                    'host': self.config.get('server.host'),
                    'port': self.config.get('server.port'),
                    'secret': self.config.get('server.secret', '')[:8] + "..." if self.config.get('server.secret') else None,
                    'max_connections': self.config.get('server.max_connections'),
                }
            
            status = {
                'service': service_status,
                'process': process_info,
                'system': system_info,
                'config': config_info,
                'pid_file': str(self.pid_file),
                'project_dir': str(self.project_dir),
            }
            
            return status
            
        except Exception as e:
            logger.error(f"Failed to get status: {e}")
            return {'error': str(e)}
    
    def start(self) -> bool:
        """Start MTProxy service"""
        try:
            if is_service_running(self.service_name):
                print("MTProxy is already running")
                return True
            
            print("Starting MTProxy service...")
            
            # Try systemd first
            result = subprocess.run(
                ['sudo', 'systemctl', 'start', self.service_name],
                capture_output=True,
                text=True
            )
            
            if result.returncode == 0:
                time.sleep(2)  # Wait for service to start
                
                if is_service_running(self.service_name):
                    print("✓ MTProxy started successfully")
                    self._show_connection_info()
                    return True
                else:
                    print("✗ Service started but not running properly")
                    return False
            else:
                # Fallback to direct execution
                print("Systemd not available, starting directly...")
                return self._start_direct()
                
        except Exception as e:
            logger.error(f"Failed to start service: {e}")
            print(f"✗ Failed to start: {e}")
            return False
    
    def stop(self) -> bool:
        """Stop MTProxy service"""
        try:
            if not is_service_running(self.service_name):
                print("MTProxy is not running")
                return True
            
            print("Stopping MTProxy service...")
            
            # Try systemd first
            result = subprocess.run(
                ['sudo', 'systemctl', 'stop', self.service_name],
                capture_output=True,
                text=True
            )
            
            if result.returncode == 0:
                time.sleep(2)  # Wait for service to stop
                
                if not is_service_running(self.service_name):
                    print("✓ MTProxy stopped successfully")
                    return True
                else:
                    print("✗ Service stop command sent but still running")
                    return False
            else:
                # Fallback to direct termination
                return self._stop_direct()
                
        except Exception as e:
            logger.error(f"Failed to stop service: {e}")
            print(f"✗ Failed to stop: {e}")
            return False
    
    def restart(self) -> bool:
        """Restart MTProxy service"""
        print("Restarting MTProxy service...")
        
        if self.stop():
            time.sleep(1)
            return self.start()
        return False
    
    def logs(self, follow: bool = False, lines: int = 50, level: str = None) -> bool:
        """Show logs"""
        try:
            log_files = [
                "/opt/python-mtproxy/logs/mtproxy.log",
                "logs/mtproxy.log",
                "/var/log/python-mtproxy.log",
            ]
            
            log_file = None
            for lf in log_files:
                if os.path.exists(lf):
                    log_file = lf
                    break
            
            if not log_file:
                print("No log file found")
                return False
            
            if follow:
                # Follow logs
                cmd = ['tail', '-f', log_file]
            else:
                # Show last N lines
                cmd = ['tail', '-n', str(lines), log_file]
            
            # Filter by level if specified
            if level:
                cmd.append('|')
                cmd.extend(['grep', '-i', level])
            
            subprocess.run(cmd)
            return True
            
        except Exception as e:
            logger.error(f"Failed to show logs: {e}")
            print(f"✗ Failed to show logs: {e}")
            return False
    
    def config_show(self) -> bool:
        """Show current configuration"""
        try:
            if not self.config:
                print("Configuration not available")
                return False
            
            print("Current Configuration:")
            print("=" * 50)
            print(str(self.config))
            return True
            
        except Exception as e:
            logger.error(f"Failed to show config: {e}")
            print(f"✗ Failed to show config: {e}")
            return False
    
    def config_edit(self) -> bool:
        """Edit configuration interactively"""
        try:
            if not self.config:
                print("Configuration not available")
                return False
            
            print("Current configuration values:")
            print("=" * 40)
            
            # Show current values
            important_keys = [
                ('server.host', 'Host'),
                ('server.port', 'Port'),
                ('server.secret', 'Secret'),
                ('server.max_connections', 'Max Connections'),
                ('server.timeout', 'Timeout'),
                ('logging.level', 'Log Level'),
            ]
            
            for key, label in important_keys:
                value = self.config.get(key)
                if key == 'server.secret' and value:
                    value = value[:8] + "..."
                print(f"{label}: {value}")
            
            print("\nEnter new values (press Enter to keep current):")
            print("-" * 40)
            
            # Interactive editing
            for key, label in important_keys:
                if key == 'server.secret':
                    continue  # Skip secret for security
                
                current = self.config.get(key)
                new_value = input(f"{label} [{current}]: ").strip()
                
                if new_value:
                    # Type conversion
                    if key in ['server.port', 'server.max_connections', 'server.timeout']:
                        try:
                            new_value = int(new_value)
                        except ValueError:
                            print(f"Invalid integer value for {label}")
                            continue
                    
                    self.config.set(key, new_value)
                    print(f"Updated {label}")
            
            # Save configuration
            self.config.save()
            print("\n✓ Configuration saved successfully")
            print("Restart the service to apply changes: mtproxy-cli restart")
            
            return True
            
        except Exception as e:
            logger.error(f"Failed to edit config: {e}")
            print(f"✗ Failed to edit config: {e}")
            return False
    
    def health(self) -> bool:
        """Perform health check"""
        try:
            print("MTProxy Health Check")
            print("=" * 50)
            
            status = self.status()
            health_score = 0
            max_score = 10
            
            # Check service status
            if status.get('service', {}).get('active', False):
                print("✓ Service is active")
                health_score += 2
            else:
                print("✗ Service is not active")
            
            # Check process
            if status.get('process'):
                print("✓ Process is running")
                health_score += 2
                
                # Check memory usage
                memory_percent = status['process'].get('memory_percent', 0)
                if memory_percent < 80:
                    print(f"✓ Memory usage OK ({memory_percent:.1f}%)")
                    health_score += 1
                else:
                    print(f"⚠ High memory usage ({memory_percent:.1f}%)")
                
                # Check CPU usage
                cpu_percent = status['process'].get('cpu_percent', 0)
                if cpu_percent < 80:
                    print(f"✓ CPU usage OK ({cpu_percent:.1f}%)")
                    health_score += 1
                else:
                    print(f"⚠ High CPU usage ({cpu_percent:.1f}%)")
            else:
                print("✗ Process not found")
            
            # Check configuration
            if status.get('config'):
                print("✓ Configuration loaded")
                health_score += 1
                
                # Check port
                port = status['config'].get('port')
                if port and 1 <= port <= 65535:
                    print(f"✓ Port configuration OK ({port})")
                    health_score += 1
                else:
                    print(f"✗ Invalid port configuration ({port})")
                
                # Check secret
                secret = status['config'].get('secret')
                if secret:
                    print("✓ Secret is configured")
                    health_score += 1
                else:
                    print("✗ Secret not configured")
            else:
                print("✗ Configuration not available")
            
            # Check system resources
            system = status.get('system', {})
            if system:
                memory_total = system.get('memory_total', 0)
                memory_available = system.get('memory_available', 0)
                
                if memory_total > 0:
                    memory_percent_free = (memory_available / memory_total) * 100
                    if memory_percent_free > 20:
                        print(f"✓ System memory OK ({memory_percent_free:.1f}% free)")
                        health_score += 1
                    else:
                        print(f"⚠ Low system memory ({memory_percent_free:.1f}% free)")
                
                disk_usage = system.get('disk_usage', 0)
                if disk_usage < 90:
                    print(f"✓ Disk space OK ({disk_usage:.1f}% used)")
                    health_score += 1
                else:
                    print(f"⚠ Low disk space ({disk_usage:.1f}% used)")
            
            # Overall health
            health_percent = (health_score / max_score) * 100
            print(f"\nOverall Health: {health_score}/{max_score} ({health_percent:.1f}%)")
            
            if health_percent >= 80:
                print("✓ System is healthy")
                return True
            elif health_percent >= 60:
                print("⚠ System has some issues")
                return True
            else:
                print("✗ System has significant issues")
                return False
                
        except Exception as e:
            logger.error(f"Health check failed: {e}")
            print(f"✗ Health check failed: {e}")
            return False
    
    def stats(self) -> bool:
        """Show statistics"""
        try:
            status = self.status()
            
            print("MTProxy Statistics")
            print("=" * 50)
            
            # Service info
            if status.get('service', {}).get('active'):
                print("Status: ✓ Running")
            else:
                print("Status: ✗ Stopped")
            
            # Process info
            process = status.get('process')
            if process:
                print(f"PID: {process.get('pid')}")
                print(f"CPU Usage: {process.get('cpu_percent', 0):.1f}%")
                print(f"Memory Usage: {process.get('memory_percent', 0):.1f}%")
                
                memory_info = process.get('memory_info', {})
                if memory_info:
                    print(f"Memory (RSS): {format_bytes(memory_info.get('rss', 0))}")
                    print(f"Memory (VMS): {format_bytes(memory_info.get('vms', 0))}")
                
                create_time = process.get('create_time')
                if create_time:
                    uptime = time.time() - create_time
                    print(f"Uptime: {format_duration(uptime)}")
                
                print(f"Threads: {process.get('num_threads', 0)}")
                print(f"Connections: {process.get('connections', 0)}")
            
            # Configuration
            config = status.get('config')
            if config:
                print(f"\nConfiguration:")
                print(f"Host: {config.get('host')}")
                print(f"Port: {config.get('port')}")
                print(f"Max Connections: {config.get('max_connections')}")
            
            # System info
            system = status.get('system')
            if system:
                print(f"\nSystem:")
                print(f"Platform: {system.get('platform')}")
                print(f"Python: {system.get('python_version')}")
                print(f"CPU Cores: {system.get('cpu_count')}")
                
                memory_total = system.get('memory_total', 0)
                memory_available = system.get('memory_available', 0)
                if memory_total > 0:
                    print(f"Memory: {format_bytes(memory_available)} / {format_bytes(memory_total)}")
                
                disk_usage = system.get('disk_usage', 0)
                print(f"Disk Usage: {disk_usage:.1f}%")
            
            return True
            
        except Exception as e:
            logger.error(f"Failed to get stats: {e}")
            print(f"✗ Failed to get stats: {e}")
            return False
    
    def _get_pid(self) -> Optional[int]:
        """Get process PID"""
        try:
            if self.pid_file.exists():
                with open(self.pid_file, 'r') as f:
                    return int(f.read().strip())
        except Exception:
            pass
        
        # Try to find process by name
        try:
            result = subprocess.run(
                ['pgrep', '-f', 'mtproxy.server'],
                capture_output=True,
                text=True
            )
            if result.returncode == 0 and result.stdout.strip():
                return int(result.stdout.strip().split()[0])
        except Exception:
            pass
        
        return None
    
    def _start_direct(self) -> bool:
        """Start service directly (not via systemd)"""
        try:
            print("Starting MTProxy directly...")
            
            cmd = [
                sys.executable, '-m', 'mtproxy.server',
                '--daemon',
                '--pidfile', str(self.pid_file)
            ]
            
            # Change to project directory
            cwd = self.project_dir if self.project_dir.exists() else Path.cwd()
            
            result = subprocess.run(cmd, cwd=cwd, capture_output=True, text=True)
            
            if result.returncode == 0:
                time.sleep(2)
                if self._get_pid():
                    print("✓ MTProxy started successfully")
                    self._show_connection_info()
                    return True
                else:
                    print("✗ Failed to start")
                    if result.stderr:
                        print(f"Error: {result.stderr}")
                    return False
            else:
                print(f"✗ Start failed: {result.stderr}")
                return False
                
        except Exception as e:
            print(f"✗ Failed to start directly: {e}")
            return False
    
    def _stop_direct(self) -> bool:
        """Stop service directly (not via systemd)"""
        try:
            pid = self._get_pid()
            if not pid:
                print("MTProxy is not running")
                return True
            
            print(f"Stopping MTProxy (PID {pid})...")
            
            # Send SIGTERM
            os.kill(pid, 15)
            
            # Wait for process to stop
            for _ in range(10):
                time.sleep(1)
                if not self._get_pid():
                    print("✓ MTProxy stopped successfully")
                    return True
            
            # Force kill if still running
            try:
                os.kill(pid, 9)
                print("✓ MTProxy force stopped")
                return True
            except ProcessLookupError:
                print("✓ MTProxy stopped")
                return True
                
        except Exception as e:
            print(f"✗ Failed to stop directly: {e}")
            return False
    
    def _show_connection_info(self):
        """Show connection information"""
        try:
            if not self.config:
                return
            
            # Get public IP
            import requests
            try:
                server_ip = requests.get('https://ifconfig.me', timeout=5).text.strip()
            except:
                try:
                    server_ip = requests.get('https://ipinfo.io/ip', timeout=5).text.strip()
                except:
                    server_ip = self.config.get('server.host', '0.0.0.0')
            
            port = self.config.get('server.port', 8443)
            secret = self.config.get('server.secret', '')
            tls_secret = self.config.get('server.tls_secret', '')
            fake_domain = self.config.get('server.fake_domain', '')
            
            print("\n📱 连接信息:")
            print("-" * 30)
            print(f"🌐 服务器IP: {server_ip}")
            print(f"🔌 端口: {port}")
            if secret:
                print(f"🔐 基础密钥: {secret}")
            if tls_secret:
                print(f"🔒 TLS密钥: {tls_secret}")
            if fake_domain:
                print(f"🎭 伪装域名: {fake_domain}")
            
            print("\n📱 Telegram代理链接:")
            if secret:
                print(f"  普通模式: https://t.me/proxy?server={server_ip}&port={port}&secret={secret}")
            if tls_secret:
                print(f"  TLS模式:  https://t.me/proxy?server={server_ip}&port={port}&secret={tls_secret}")
            
        except Exception:
            pass
    
    def show_proxy(self) -> None:
        """Show detailed proxy connection information"""
        print("\n" + "=" * 50)
        print("📱 MTProxy 连接信息")
        print("=" * 50)
        
        if not self.config:
            print("❌ 无法加载配置文件")
            return
            
        try:
            # Get server IP
            import requests
            try:
                server_ip = requests.get('https://ifconfig.me', timeout=10).text.strip()
            except:
                try:
                    server_ip = requests.get('https://ipinfo.io/ip', timeout=10).text.strip()
                except:
                    server_ip = "YOUR_SERVER_IP"
            
            port = self.config.get('server.port', 8443)
            secret = self.config.get('server.secret', '')
            tls_secret = self.config.get('server.tls_secret', '')
            fake_domain = self.config.get('server.fake_domain', 'www.cloudflare.com')
            
            print(f"🌐 服务器IP: {server_ip}")
            print(f"🔌 端口: {port}")
            print(f"🔐 基础密钥: {secret}")
            print(f"🔒 TLS密钥: {tls_secret}")
            print(f"🎭 伪装域名: {fake_domain}")
            print()
            
            if secret:
                print("📱 Telegram代理链接:")
                print(f"  普通模式: https://t.me/proxy?server={server_ip}&port={port}&secret={secret}")
                if tls_secret:
                    print(f"  TLS模式:  https://t.me/proxy?server={server_ip}&port={port}&secret={tls_secret}")
                print()
                print("💡 使用方法:")
                print("  1. 复制上面的任一代理链接")
                print("  2. 在Telegram中打开链接")  
                print("  3. 点击'连接代理'即可使用")
                print("  （推荐使用TLS模式，连接更稳定）")
            else:
                print("❌ 未找到密钥信息")
                
        except Exception as e:
            print(f"❌ 获取代理信息失败: {e}")
        
        print("=" * 50)


def main():
    """Main CLI entry point"""
    parser = argparse.ArgumentParser(description='MTProxy CLI Management Tool')
    subparsers = parser.add_subparsers(dest='command', help='Available commands')
    
    # Status command
    status_parser = subparsers.add_parser('status', help='Show service status')
    status_parser.add_argument('--json', action='store_true', help='Output in JSON format')
    
    # Start command
    subparsers.add_parser('start', help='Start MTProxy service')
    
    # Stop command
    subparsers.add_parser('stop', help='Stop MTProxy service')
    
    # Restart command
    subparsers.add_parser('restart', help='Restart MTProxy service')
    
    # Proxy command
    subparsers.add_parser('proxy', help='Show proxy connection links')
    
    # Logs command
    logs_parser = subparsers.add_parser('logs', help='Show logs')
    logs_parser.add_argument('--follow', '-f', action='store_true', help='Follow log output')
    logs_parser.add_argument('--lines', '-n', type=int, default=50, help='Number of lines to show')
    logs_parser.add_argument('--level', type=str, help='Filter by log level')
    
    # Config commands
    config_parser = subparsers.add_parser('config', help='Configuration management')
    config_subparsers = config_parser.add_subparsers(dest='config_action')
    config_subparsers.add_parser('show', help='Show current configuration')
    config_subparsers.add_parser('edit', help='Edit configuration interactively')
    
    # Health command
    subparsers.add_parser('health', help='Perform health check')
    
    # Stats command
    subparsers.add_parser('stats', help='Show statistics')
    
    args = parser.parse_args()
    
    if not args.command:
        parser.print_help()
        return
    
    cli = MTProxyCLI()
    
    try:
        if args.command == 'status':
            status = cli.status()
            if args.json:
                print(json.dumps(status, indent=2))
            else:
                # Format status output
                print("MTProxy Status")
                print("=" * 30)
                
                service = status.get('service', {})
                if service.get('active'):
                    print("Status: ✓ Running")
                else:
                    print("Status: ✗ Stopped")
                
                if service.get('enabled'):
                    print("Autostart: ✓ Enabled")
                else:
                    print("Autostart: ✗ Disabled")
                
                process = status.get('process')
                if process:
                    print(f"PID: {process.get('pid')}")
                    create_time = process.get('create_time')
                    if create_time:
                        uptime = time.time() - create_time
                        print(f"Uptime: {format_duration(uptime)}")
                
                config = status.get('config')
                if config:
                    print(f"Host: {config.get('host')}")
                    print(f"Port: {config.get('port')}")
        
        elif args.command == 'start':
            cli.start()
        
        elif args.command == 'stop':
            cli.stop()
        
        elif args.command == 'restart':
            cli.restart()
        
        elif args.command == 'proxy':
            cli.show_proxy()
        
        elif args.command == 'logs':
            cli.logs(follow=args.follow, lines=args.lines, level=args.level)
        
        elif args.command == 'config':
            if args.config_action == 'show':
                cli.config_show()
            elif args.config_action == 'edit':
                cli.config_edit()
            else:
                config_parser.print_help()
        
        elif args.command == 'health':
            cli.health()
        
        elif args.command == 'stats':
            cli.stats()
        
    except KeyboardInterrupt:
        print("\nInterrupted by user")
    except Exception as e:
        logger.error(f"CLI error: {e}")
        print(f"Error: {e}")
        sys.exit(1)


if __name__ == '__main__':
    main()
