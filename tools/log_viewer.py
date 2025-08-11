#!/usr/bin/env python3
"""
MTProxy Log Viewer - Real-time log monitoring and analysis tool
"""

import os
import sys
import time
import re
import argparse
from pathlib import Path
from datetime import datetime, timedelta
from typing import List, Dict, Optional, Iterator
import subprocess

# Add project root to Python path
project_root = Path(__file__).parent.parent
sys.path.insert(0, str(project_root))


class LogViewer:
    """Real-time log viewer with filtering and search capabilities"""
    
    def __init__(self, log_file: Optional[str] = None):
        self.log_files = self._find_log_files(log_file)
        self.colors = {
            'DEBUG': '\033[36m',    # Cyan
            'INFO': '\033[32m',     # Green
            'WARNING': '\033[33m',  # Yellow
            'ERROR': '\033[31m',    # Red
            'CRITICAL': '\033[35m', # Magenta
            'RESET': '\033[0m',     # Reset
            'BOLD': '\033[1m',      # Bold
            'DIM': '\033[2m',       # Dim
        }
    
    def _find_log_files(self, preferred: Optional[str] = None) -> List[str]:
        """Find available log files"""
        possible_files = []
        
        if preferred and os.path.exists(preferred):
            return [preferred]
        
        # Standard locations
        locations = [
            "/opt/python-mtproxy/logs/mtproxy.log",
            "/opt/python-mtproxy/logs/mtproxy-main.log",
            "/opt/python-mtproxy/logs/mtproxy-server.log",
            "logs/mtproxy.log",
            "logs/mtproxy-main.log",
            "/var/log/python-mtproxy.log",
            "/var/log/mtproxy.log",
        ]
        
        for location in locations:
            if os.path.exists(location):
                possible_files.append(location)
        
        return possible_files
    
    def follow(self, level_filter: Optional[str] = None, 
               grep_pattern: Optional[str] = None,
               colored: bool = True) -> None:
        """Follow log file in real-time (like tail -f)"""
        
        if not self.log_files:
            print("No log files found")
            return
        
        log_file = self.log_files[0]
        print(f"Following log file: {log_file}")
        print("Press Ctrl+C to stop")
        print("-" * 60)
        
        try:
            # Use tail -f for following
            cmd = ['tail', '-f', log_file]
            
            process = subprocess.Popen(
                cmd,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                universal_newlines=True,
                bufsize=1
            )
            
            for line in iter(process.stdout.readline, ''):
                # Apply filters
                if self._should_show_line(line, level_filter, grep_pattern):
                    if colored:
                        line = self._colorize_line(line)
                    print(line.rstrip())
                    
        except KeyboardInterrupt:
            print("\nStopped following log")
        except Exception as e:
            print(f"Error following log: {e}")
        finally:
            try:
                process.terminate()
            except:
                pass
    
    def view(self, lines: int = 100, 
             level_filter: Optional[str] = None,
             grep_pattern: Optional[str] = None,
             date_filter: Optional[str] = None,
             colored: bool = True) -> None:
        """View last N lines of log file"""
        
        if not self.log_files:
            print("No log files found")
            return
        
        log_file = self.log_files[0]
        
        try:
            # Read last N lines
            with open(log_file, 'r', encoding='utf-8', errors='ignore') as f:
                all_lines = f.readlines()
            
            # Apply date filter if specified
            if date_filter:
                all_lines = self._filter_by_date(all_lines, date_filter)
            
            # Get last N lines
            recent_lines = all_lines[-lines:] if len(all_lines) > lines else all_lines
            
            print(f"Showing last {len(recent_lines)} lines from: {log_file}")
            print("-" * 60)
            
            for line in recent_lines:
                if self._should_show_line(line, level_filter, grep_pattern):
                    if colored:
                        line = self._colorize_line(line)
                    print(line.rstrip())
                    
        except Exception as e:
            print(f"Error reading log file: {e}")
    
    def search(self, pattern: str, 
               context_lines: int = 2,
               case_sensitive: bool = False,
               colored: bool = True) -> None:
        """Search for pattern in log files"""
        
        if not self.log_files:
            print("No log files found")
            return
        
        flags = 0 if case_sensitive else re.IGNORECASE
        regex = re.compile(pattern, flags)
        
        for log_file in self.log_files:
            print(f"\nSearching in: {log_file}")
            print("-" * 60)
            
            try:
                with open(log_file, 'r', encoding='utf-8', errors='ignore') as f:
                    lines = f.readlines()
                
                matches = []
                for i, line in enumerate(lines):
                    if regex.search(line):
                        # Get context lines
                        start = max(0, i - context_lines)
                        end = min(len(lines), i + context_lines + 1)
                        
                        matches.append({
                            'line_num': i + 1,
                            'context': lines[start:end],
                            'match_idx': i - start
                        })
                
                if matches:
                    print(f"Found {len(matches)} matches:")
                    
                    for match in matches:
                        print(f"\nLine {match['line_num']}:")
                        
                        for j, context_line in enumerate(match['context']):
                            line_num = match['line_num'] - match['match_idx'] + j
                            prefix = ">" if j == match['match_idx'] else " "
                            
                            if colored and j == match['match_idx']:
                                # Highlight the match
                                highlighted = regex.sub(
                                    f"{self.colors['BOLD']}{self.colors['ERROR']}\\g<0>{self.colors['RESET']}", 
                                    context_line.rstrip()
                                )
                                print(f"{prefix} {line_num:6d}: {highlighted}")
                            else:
                                print(f"{prefix} {line_num:6d}: {context_line.rstrip()}")
                else:
                    print("No matches found")
                    
            except Exception as e:
                print(f"Error searching in {log_file}: {e}")
    
    def analyze(self) -> None:
        """Analyze log files and show statistics"""
        
        if not self.log_files:
            print("No log files found")
            return
        
        print("Log File Analysis")
        print("=" * 50)
        
        total_stats = {
            'total_lines': 0,
            'levels': {'DEBUG': 0, 'INFO': 0, 'WARNING': 0, 'ERROR': 0, 'CRITICAL': 0},
            'dates': {},
            'ips': {},
            'errors': [],
        }
        
        for log_file in self.log_files:
            print(f"\nAnalyzing: {log_file}")
            
            try:
                file_stats = self._analyze_file(log_file)
                
                # Merge stats
                total_stats['total_lines'] += file_stats['total_lines']
                for level, count in file_stats['levels'].items():
                    total_stats['levels'][level] += count
                
                for date, count in file_stats['dates'].items():
                    total_stats['dates'][date] = total_stats['dates'].get(date, 0) + count
                
                for ip, count in file_stats['ips'].items():
                    total_stats['ips'][ip] = total_stats['ips'].get(ip, 0) + count
                
                total_stats['errors'].extend(file_stats['errors'])
                
                # Show file-specific stats
                print(f"  Lines: {file_stats['total_lines']}")
                print(f"  Size: {self._get_file_size(log_file)}")
                print(f"  Errors: {file_stats['levels']['ERROR'] + file_stats['levels']['CRITICAL']}")
                
            except Exception as e:
                print(f"  Error: {e}")
        
        # Show overall statistics
        print(f"\nOverall Statistics:")
        print(f"Total Lines: {total_stats['total_lines']}")
        print(f"Log Levels:")
        for level, count in total_stats['levels'].items():
            if count > 0:
                percentage = (count / total_stats['total_lines']) * 100 if total_stats['total_lines'] > 0 else 0
                print(f"  {level}: {count} ({percentage:.1f}%)")
        
        # Show top IPs
        if total_stats['ips']:
            print(f"\nTop Client IPs:")
            sorted_ips = sorted(total_stats['ips'].items(), key=lambda x: x[1], reverse=True)
            for ip, count in sorted_ips[:10]:
                print(f"  {ip}: {count} connections")
        
        # Show recent errors
        if total_stats['errors']:
            print(f"\nRecent Errors ({len(total_stats['errors'])}):")
            for error in total_stats['errors'][-5:]:  # Last 5 errors
                print(f"  {error}")
    
    def clean(self, days: int = 7, dry_run: bool = False) -> None:
        """Clean old log files"""
        
        log_dirs = [
            "/opt/python-mtproxy/logs",
            "logs",
            "/var/log",
        ]
        
        cleaned_count = 0
        cleaned_size = 0
        
        for log_dir in log_dirs:
            if not os.path.exists(log_dir):
                continue
            
            print(f"Checking directory: {log_dir}")
            
            try:
                for file_path in Path(log_dir).glob("*.log*"):
                    if self._is_old_file(file_path, days):
                        size = file_path.stat().st_size
                        
                        if dry_run:
                            print(f"  Would delete: {file_path} ({self._format_size(size)})")
                        else:
                            file_path.unlink()
                            print(f"  Deleted: {file_path} ({self._format_size(size)})")
                        
                        cleaned_count += 1
                        cleaned_size += size
                        
            except Exception as e:
                print(f"Error cleaning {log_dir}: {e}")
        
        action = "Would clean" if dry_run else "Cleaned"
        print(f"\n{action} {cleaned_count} files, {self._format_size(cleaned_size)}")
    
    def _should_show_line(self, line: str, level_filter: Optional[str], grep_pattern: Optional[str]) -> bool:
        """Check if line should be shown based on filters"""
        
        # Level filter
        if level_filter:
            if level_filter.upper() not in line:
                return False
        
        # Grep pattern
        if grep_pattern:
            if not re.search(grep_pattern, line, re.IGNORECASE):
                return False
        
        return True
    
    def _colorize_line(self, line: str) -> str:
        """Add colors to log line"""
        
        # Color by log level
        for level, color in self.colors.items():
            if level == 'RESET' or level == 'BOLD' or level == 'DIM':
                continue
            
            if f" {level} " in line or f"-{level}-" in line:
                return f"{color}{line}{self.colors['RESET']}"
        
        return line
    
    def _filter_by_date(self, lines: List[str], date_filter: str) -> List[str]:
        """Filter lines by date"""
        
        if date_filter.lower() == 'today':
            target_date = datetime.now().strftime('%Y-%m-%d')
        elif date_filter.lower() == 'yesterday':
            target_date = (datetime.now() - timedelta(days=1)).strftime('%Y-%m-%d')
        else:
            target_date = date_filter
        
        filtered_lines = []
        for line in lines:
            if target_date in line:
                filtered_lines.append(line)
        
        return filtered_lines
    
    def _analyze_file(self, file_path: str) -> Dict:
        """Analyze a single log file"""
        
        stats = {
            'total_lines': 0,
            'levels': {'DEBUG': 0, 'INFO': 0, 'WARNING': 0, 'ERROR': 0, 'CRITICAL': 0},
            'dates': {},
            'ips': {},
            'errors': [],
        }
        
        ip_pattern = re.compile(r'\b(?:[0-9]{1,3}\.){3}[0-9]{1,3}\b')
        date_pattern = re.compile(r'\d{4}-\d{2}-\d{2}')
        
        with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
            for line in f:
                stats['total_lines'] += 1
                
                # Count log levels
                for level in stats['levels']:
                    if f" {level} " in line or f"-{level}-" in line:
                        stats['levels'][level] += 1
                        break
                
                # Extract dates
                date_match = date_pattern.search(line)
                if date_match:
                    date = date_match.group()
                    stats['dates'][date] = stats['dates'].get(date, 0) + 1
                
                # Extract IPs
                ip_matches = ip_pattern.findall(line)
                for ip in ip_matches:
                    stats['ips'][ip] = stats['ips'].get(ip, 0) + 1
                
                # Collect errors
                if 'ERROR' in line or 'CRITICAL' in line:
                    stats['errors'].append(line.strip())
        
        return stats
    
    def _get_file_size(self, file_path: str) -> str:
        """Get human-readable file size"""
        try:
            size = os.path.getsize(file_path)
            return self._format_size(size)
        except:
            return "Unknown"
    
    def _format_size(self, size: int) -> str:
        """Format size in human-readable format"""
        for unit in ['B', 'KB', 'MB', 'GB']:
            if size < 1024:
                return f"{size:.1f} {unit}"
            size /= 1024
        return f"{size:.1f} TB"
    
    def _is_old_file(self, file_path: Path, days: int) -> bool:
        """Check if file is older than specified days"""
        try:
            file_time = file_path.stat().st_mtime
            cutoff_time = time.time() - (days * 24 * 3600)
            return file_time < cutoff_time
        except:
            return False


def main():
    """Main entry point"""
    parser = argparse.ArgumentParser(description='MTProxy Log Viewer')
    parser.add_argument('--file', '-f', type=str, help='Specific log file to view')
    parser.add_argument('--follow', action='store_true', help='Follow log file (like tail -f)')
    parser.add_argument('--lines', '-n', type=int, default=100, help='Number of lines to show')
    parser.add_argument('--level', type=str, choices=['DEBUG', 'INFO', 'WARNING', 'ERROR', 'CRITICAL'], 
                       help='Filter by log level')
    parser.add_argument('--grep', type=str, help='Filter by pattern')
    parser.add_argument('--date', type=str, help='Filter by date (YYYY-MM-DD, today, yesterday)')
    parser.add_argument('--search', type=str, help='Search for pattern in logs')
    parser.add_argument('--context', '-C', type=int, default=2, help='Context lines for search')
    parser.add_argument('--case-sensitive', action='store_true', help='Case sensitive search')
    parser.add_argument('--analyze', action='store_true', help='Analyze log files')
    parser.add_argument('--clean', type=int, metavar='DAYS', help='Clean logs older than N days')
    parser.add_argument('--dry-run', action='store_true', help='Show what would be deleted (with --clean)')
    parser.add_argument('--no-color', action='store_true', help='Disable colored output')
    
    args = parser.parse_args()
    
    viewer = LogViewer(args.file)
    colored = not args.no_color
    
    try:
        if args.follow:
            viewer.follow(level_filter=args.level, grep_pattern=args.grep, colored=colored)
        
        elif args.search:
            viewer.search(args.search, context_lines=args.context, 
                         case_sensitive=args.case_sensitive, colored=colored)
        
        elif args.analyze:
            viewer.analyze()
        
        elif args.clean is not None:
            viewer.clean(days=args.clean, dry_run=args.dry_run)
        
        else:
            viewer.view(lines=args.lines, level_filter=args.level, 
                       grep_pattern=args.grep, date_filter=args.date, colored=colored)
    
    except KeyboardInterrupt:
        print("\nInterrupted by user")
    except Exception as e:
        print(f"Error: {e}")
        sys.exit(1)


if __name__ == '__main__':
    main()
