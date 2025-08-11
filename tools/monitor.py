#!/usr/bin/env python3
"""
MTProxy Monitor - Real-time monitoring and statistics
"""

import os
import sys
import time
import json
import argparse
import threading
from pathlib import Path
from datetime import datetime, timedelta
from typing import Dict, List, Any, Optional

# Add project root to Python path
project_root = Path(__file__).parent.parent
sys.path.insert(0, str(project_root))

try:
    import psutil
    from mtproxy.utils import (
        get_process_info, format_bytes, format_duration,
        is_service_running, get_system_info
    )
except ImportError as e:
    print(f"Error importing modules: {e}")
    sys.exit(1)


class MTProxyMonitor:
    """Real-time MTProxy monitoring"""
    
    def __init__(self):
        self.running = False
        self.stats_history = []
        self.max_history = 100
        self.service_name = "python-mtproxy"
    
    def get_current_stats(self) -> Dict[str, Any]:
        """Get current system statistics"""
        stats = {
            'timestamp': time.time(),
            'datetime': datetime.now().strftime('%Y-%m-%d %H:%M:%S'),
            'service': {},
            'process': {},
            'system': {},
            'network': {},
        }
        
        try:
            # Service status
            stats['service']['running'] = is_service_running(self.service_name)
            
            # Process information
            process = self._find_mtproxy_process()
            if process:
                stats['process'] = {
                    'pid': process.pid,
                    'status': process.status(),
                    'cpu_percent': process.cpu_percent(),
                    'memory_percent': process.memory_percent(),
                    'memory_info': process.memory_info()._asdict(),
                    'create_time': process.create_time(),
                    'num_threads': process.num_threads(),
                    'open_files': len(process.open_files()),
                    'connections': len(process.connections()),
                }
            
            # System information
            stats['system'] = {
                'cpu_percent': psutil.cpu_percent(interval=1),
                'memory': psutil.virtual_memory()._asdict(),
                'disk': psutil.disk_usage('/')._asdict(),
                'load_average': os.getloadavg() if hasattr(os, 'getloadavg') else None,
                'boot_time': psutil.boot_time(),
            }
            
            # Network information
            try:
                network_io = psutil.net_io_counters()
                stats['network'] = {
                    'bytes_sent': network_io.bytes_sent,
                    'bytes_recv': network_io.bytes_recv,
                    'packets_sent': network_io.packets_sent,
                    'packets_recv': network_io.packets_recv,
                }
            except:
                stats['network'] = {}
                
        except Exception as e:
            stats['error'] = str(e)
        
        return stats
    
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
    
    def start_monitoring(self, interval: int = 5, duration: Optional[int] = None):
        """Start real-time monitoring"""
        self.running = True
        start_time = time.time()
        
        print("MTProxy Real-time Monitor")
        print("=" * 50)
        print(f"Update interval: {interval} seconds")
        if duration:
            print(f"Duration: {duration} seconds")
        print("Press Ctrl+C to stop")
        print()
        
        try:
            while self.running:
                stats = self.get_current_stats()
                self.stats_history.append(stats)
                
                # Keep only recent history
                if len(self.stats_history) > self.max_history:
                    self.stats_history.pop(0)
                
                # Display current stats
                self._display_stats(stats)
                
                # Check duration
                if duration and (time.time() - start_time) >= duration:
                    break
                
                time.sleep(interval)
                
        except KeyboardInterrupt:
            print("\nMonitoring stopped")
        finally:
            self.running = False
    
    def _display_stats(self, stats: Dict[str, Any]):
        """Display current statistics"""
        # Clear screen (works on most terminals)
        os.system('clear' if os.name == 'posix' else 'cls')
        
        print("MTProxy Monitor - " + stats['datetime'])
        print("=" * 60)
        
        # Service status
        service_status = "✓ RUNNING" if stats['service'].get('running') else "✗ STOPPED"
        print(f"Service Status: {service_status}")
        print()
        
        # Process information
        if stats.get('process'):
            process = stats['process']
            print("Process Information:")
            print(f"  PID: {process.get('pid', 'N/A')}")
            print(f"  Status: {process.get('status', 'N/A')}")
            print(f"  CPU: {process.get('cpu_percent', 0):.1f}%")
            print(f"  Memory: {process.get('memory_percent', 0):.1f}%")
            
            memory_info = process.get('memory_info', {})
            if memory_info:
                print(f"  RSS: {format_bytes(memory_info.get('rss', 0))}")
                print(f"  VMS: {format_bytes(memory_info.get('vms', 0))}")
            
            if process.get('create_time'):
                uptime = time.time() - process['create_time']
                print(f"  Uptime: {format_duration(uptime)}")
            
            print(f"  Threads: {process.get('num_threads', 0)}")
            print(f"  Open Files: {process.get('open_files', 0)}")
            print(f"  Connections: {process.get('connections', 0)}")
        else:
            print("Process Information: Not running")
        
        print()
        
        # System information
        if stats.get('system'):
            system = stats['system']
            print("System Information:")
            print(f"  CPU: {system.get('cpu_percent', 0):.1f}%")
            
            memory = system.get('memory', {})
            if memory:
                mem_total = memory.get('total', 0)
                mem_available = memory.get('available', 0)
                mem_percent = memory.get('percent', 0)
                print(f"  Memory: {mem_percent:.1f}% ({format_bytes(mem_total - mem_available)} / {format_bytes(mem_total)})")
            
            disk = system.get('disk', {})
            if disk:
                disk_total = disk.get('total', 0)
                disk_used = disk.get('used', 0)
                disk_percent = (disk_used / disk_total * 100) if disk_total > 0 else 0
                print(f"  Disk: {disk_percent:.1f}% ({format_bytes(disk_used)} / {format_bytes(disk_total)})")
            
            load_avg = system.get('load_average')
            if load_avg:
                print(f"  Load: {load_avg[0]:.2f}, {load_avg[1]:.2f}, {load_avg[2]:.2f}")
        
        print()
        
        # Network information (show delta if available)
        if stats.get('network') and len(self.stats_history) > 1:
            current_net = stats['network']
            previous_net = self.stats_history[-2].get('network', {})
            
            if previous_net:
                time_delta = stats['timestamp'] - self.stats_history[-2]['timestamp']
                
                bytes_sent_delta = current_net.get('bytes_sent', 0) - previous_net.get('bytes_sent', 0)
                bytes_recv_delta = current_net.get('bytes_recv', 0) - previous_net.get('bytes_recv', 0)
                
                if time_delta > 0:
                    sent_rate = bytes_sent_delta / time_delta
                    recv_rate = bytes_recv_delta / time_delta
                    
                    print("Network (Rate):")
                    print(f"  Upload: {format_bytes(sent_rate)}/s")
                    print(f"  Download: {format_bytes(recv_rate)}/s")
                    print()
        
        # Historical trend (simple)
        if len(self.stats_history) >= 2:
            print("Trends (last few measurements):")
            
            # CPU trend
            cpu_values = [s.get('process', {}).get('cpu_percent', 0) for s in self.stats_history[-5:]]
            if cpu_values:
                cpu_trend = "↑" if cpu_values[-1] > cpu_values[0] else "↓" if cpu_values[-1] < cpu_values[0] else "→"
                print(f"  CPU: {cpu_trend} {', '.join(f'{v:.1f}%' for v in cpu_values[-3:])}")
            
            # Memory trend
            mem_values = [s.get('process', {}).get('memory_percent', 0) for s in self.stats_history[-5:]]
            if mem_values:
                mem_trend = "↑" if mem_values[-1] > mem_values[0] else "↓" if mem_values[-1] < mem_values[0] else "→"
                print(f"  Memory: {mem_trend} {', '.join(f'{v:.1f}%' for v in mem_values[-3:])}")
        
        print()
        print("Press Ctrl+C to stop monitoring")
    
    def generate_report(self, output_file: Optional[str] = None) -> str:
        """Generate monitoring report"""
        if not self.stats_history:
            return "No monitoring data available"
        
        report_data = {
            'generated_at': datetime.now().isoformat(),
            'monitoring_period': {
                'start': datetime.fromtimestamp(self.stats_history[0]['timestamp']).isoformat(),
                'end': datetime.fromtimestamp(self.stats_history[-1]['timestamp']).isoformat(),
                'duration_seconds': self.stats_history[-1]['timestamp'] - self.stats_history[0]['timestamp'],
                'data_points': len(self.stats_history),
            },
            'summary': self._calculate_summary(),
            'raw_data': self.stats_history,
        }
        
        report_json = json.dumps(report_data, indent=2)
        
        if output_file:
            with open(output_file, 'w') as f:
                f.write(report_json)
            return f"Report saved to {output_file}"
        
        return report_json
    
    def _calculate_summary(self) -> Dict[str, Any]:
        """Calculate summary statistics"""
        if not self.stats_history:
            return {}
        
        # Extract metrics
        cpu_values = [s.get('process', {}).get('cpu_percent', 0) for s in self.stats_history]
        memory_values = [s.get('process', {}).get('memory_percent', 0) for s in self.stats_history]
        
        # Calculate statistics
        summary = {
            'process': {
                'cpu': {
                    'min': min(cpu_values) if cpu_values else 0,
                    'max': max(cpu_values) if cpu_values else 0,
                    'avg': sum(cpu_values) / len(cpu_values) if cpu_values else 0,
                },
                'memory': {
                    'min': min(memory_values) if memory_values else 0,
                    'max': max(memory_values) if memory_values else 0,
                    'avg': sum(memory_values) / len(memory_values) if memory_values else 0,
                },
            },
            'service': {
                'uptime_percentage': sum(1 for s in self.stats_history if s.get('service', {}).get('running', False)) / len(self.stats_history) * 100,
            }
        }
        
        return summary
    
    def export_csv(self, output_file: str):
        """Export monitoring data to CSV"""
        import csv
        
        if not self.stats_history:
            print("No data to export")
            return
        
        with open(output_file, 'w', newline='') as csvfile:
            fieldnames = [
                'timestamp', 'datetime', 'service_running',
                'process_pid', 'process_cpu_percent', 'process_memory_percent',
                'system_cpu_percent', 'system_memory_percent', 'system_disk_percent'
            ]
            
            writer = csv.DictWriter(csvfile, fieldnames=fieldnames)
            writer.writeheader()
            
            for stats in self.stats_history:
                row = {
                    'timestamp': stats['timestamp'],
                    'datetime': stats['datetime'],
                    'service_running': stats.get('service', {}).get('running', False),
                    'process_pid': stats.get('process', {}).get('pid', ''),
                    'process_cpu_percent': stats.get('process', {}).get('cpu_percent', 0),
                    'process_memory_percent': stats.get('process', {}).get('memory_percent', 0),
                    'system_cpu_percent': stats.get('system', {}).get('cpu_percent', 0),
                    'system_memory_percent': stats.get('system', {}).get('memory', {}).get('percent', 0),
                    'system_disk_percent': 0,  # Calculate if needed
                }
                
                # Calculate disk percentage
                disk = stats.get('system', {}).get('disk', {})
                if disk.get('total', 0) > 0:
                    row['system_disk_percent'] = (disk.get('used', 0) / disk['total']) * 100
                
                writer.writerow(row)
        
        print(f"Data exported to {output_file}")


def main():
    """Main entry point"""
    parser = argparse.ArgumentParser(description='MTProxy Monitor')
    parser.add_argument('--interval', '-i', type=int, default=5, help='Update interval in seconds')
    parser.add_argument('--duration', '-d', type=int, help='Monitoring duration in seconds')
    parser.add_argument('--stats', action='store_true', help='Show current stats only')
    parser.add_argument('--json', action='store_true', help='Output in JSON format')
    parser.add_argument('--report', type=str, help='Generate report and save to file')
    parser.add_argument('--csv', type=str, help='Export data to CSV file')
    
    args = parser.parse_args()
    
    monitor = MTProxyMonitor()
    
    try:
        if args.stats:
            # Show current stats only
            stats = monitor.get_current_stats()
            
            if args.json:
                print(json.dumps(stats, indent=2))
            else:
                monitor._display_stats(stats)
        
        elif args.report or args.csv:
            # Need to run monitoring first
            print("Collecting monitoring data...")
            monitor.start_monitoring(args.interval, args.duration or 60)
            
            if args.report:
                report = monitor.generate_report(args.report)
                print(report)
            
            if args.csv:
                monitor.export_csv(args.csv)
        
        else:
            # Real-time monitoring
            monitor.start_monitoring(args.interval, args.duration)
    
    except KeyboardInterrupt:
        print("\nMonitoring interrupted")
    except Exception as e:
        print(f"Error: {e}")
        sys.exit(1)


if __name__ == '__main__':
    main()
