"""
Utility functions for MTProxy
"""

import os
import socket
import struct
import time
import hashlib
import secrets
from typing import Optional, Tuple, Union, List
from pathlib import Path

from .logger import get_logger

logger = get_logger(__name__)


def generate_secret() -> str:
    """Generate a random secret for MTProxy"""
    return secrets.token_hex(16)


def validate_secret(secret: str) -> bool:
    """Validate MTProxy secret format"""
    if not secret:
        return False
    
    try:
        # Remove any whitespace and convert to lowercase
        secret = secret.strip().lower()
        
        # Check if it's a valid hex string
        if len(secret) != 32:
            return False
        
        int(secret, 16)
        return True
    except ValueError:
        return False


def format_secret(secret: str) -> str:
    """Format secret for display"""
    if not secret:
        return "NOT_SET"
    
    if len(secret) > 8:
        return f"{secret[:4]}...{secret[-4:]}"
    return secret


def get_local_ip() -> str:
    """Get local IP address"""
    try:
        # Connect to a remote address to determine local IP
        with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as s:
            s.connect(("8.8.8.8", 80))
            return s.getsockname()[0]
    except Exception:
        return "127.0.0.1"


def check_port_available(host: str, port: int) -> bool:
    """Check if port is available"""
    try:
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
            s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
            s.bind((host, port))
            return True
    except OSError:
        return False


def find_free_port(host: str = "localhost", start_port: int = 8443, max_attempts: int = 100) -> Optional[int]:
    """Find a free port starting from start_port"""
    for port in range(start_port, start_port + max_attempts):
        if check_port_available(host, port):
            return port
    return None


def format_bytes(bytes_count: int) -> str:
    """Format bytes to human readable format"""
    for unit in ['B', 'KB', 'MB', 'GB', 'TB']:
        if bytes_count < 1024.0:
            return f"{bytes_count:.1f} {unit}"
        bytes_count /= 1024.0
    return f"{bytes_count:.1f} PB"


def format_duration(seconds: float) -> str:
    """Format duration to human readable format"""
    if seconds < 60:
        return f"{seconds:.1f}s"
    elif seconds < 3600:
        minutes = seconds / 60
        return f"{minutes:.1f}m"
    elif seconds < 86400:
        hours = seconds / 3600
        return f"{hours:.1f}h"
    else:
        days = seconds / 86400
        return f"{days:.1f}d"


def calculate_crc32(data: bytes) -> int:
    """Calculate CRC32 checksum"""
    import zlib
    return zlib.crc32(data) & 0xffffffff


def xor_bytes(data1: bytes, data2: bytes) -> bytes:
    """XOR two byte arrays"""
    return bytes(a ^ b for a, b in zip(data1, data2))


def int_to_bytes(value: int, length: int = 4, byteorder: str = 'little') -> bytes:
    """Convert integer to bytes"""
    return value.to_bytes(length, byteorder)


def bytes_to_int(data: bytes, byteorder: str = 'little') -> int:
    """Convert bytes to integer"""
    return int.from_bytes(data, byteorder)


def md5_hash(data: bytes) -> bytes:
    """Calculate MD5 hash"""
    return hashlib.md5(data).digest()


def sha1_hash(data: bytes) -> bytes:
    """Calculate SHA1 hash"""
    return hashlib.sha1(data).digest()


def sha256_hash(data: bytes) -> bytes:
    """Calculate SHA256 hash"""
    return hashlib.sha256(data).digest()


def create_directory(path: Union[str, Path], mode: int = 0o755) -> bool:
    """Create directory with proper permissions"""
    try:
        Path(path).mkdir(parents=True, exist_ok=True, mode=mode)
        return True
    except Exception as e:
        logger.error(f"Failed to create directory {path}: {e}")
        return False


def safe_file_write(filepath: Union[str, Path], content: Union[str, bytes], mode: str = 'w') -> bool:
    """Safely write content to file with atomic operation"""
    filepath = Path(filepath)
    temp_filepath = filepath.with_suffix(filepath.suffix + '.tmp')
    
    try:
        # Write to temporary file first
        with open(temp_filepath, mode, encoding='utf-8' if 'b' not in mode else None) as f:
            f.write(content)
        
        # Atomic move
        temp_filepath.replace(filepath)
        return True
        
    except Exception as e:
        logger.error(f"Failed to write file {filepath}: {e}")
        # Cleanup temp file
        if temp_filepath.exists():
            temp_filepath.unlink()
        return False


def read_file_safe(filepath: Union[str, Path], mode: str = 'r') -> Optional[Union[str, bytes]]:
    """Safely read file content"""
    try:
        with open(filepath, mode, encoding='utf-8' if 'b' not in mode else None) as f:
            return f.read()
    except Exception as e:
        logger.error(f"Failed to read file {filepath}: {e}")
        return None


def get_file_size(filepath: Union[str, Path]) -> int:
    """Get file size in bytes"""
    try:
        return Path(filepath).stat().st_size
    except Exception:
        return 0


def get_system_info() -> dict:
    """Get system information"""
    import platform
    import psutil
    
    try:
        return {
            'platform': platform.platform(),
            'python_version': platform.python_version(),
            'cpu_count': os.cpu_count(),
            'memory_total': psutil.virtual_memory().total,
            'memory_available': psutil.virtual_memory().available,
            'disk_usage': psutil.disk_usage('/').percent,
            'load_average': os.getloadavg() if hasattr(os, 'getloadavg') else None,
        }
    except Exception as e:
        logger.error(f"Failed to get system info: {e}")
        return {}


def validate_ip_address(ip: str) -> bool:
    """Validate IP address format"""
    try:
        socket.inet_aton(ip)
        return True
    except socket.error:
        return False


def validate_port(port: Union[str, int]) -> bool:
    """Validate port number"""
    try:
        port_int = int(port)
        return 1 <= port_int <= 65535
    except ValueError:
        return False


def parse_size_string(size_str: str) -> int:
    """Parse size string like '100MB' to bytes"""
    size_str = size_str.strip().upper()
    
    multipliers = {
        'B': 1,
        'KB': 1024,
        'MB': 1024 ** 2,
        'GB': 1024 ** 3,
        'TB': 1024 ** 4,
    }
    
    for suffix, multiplier in multipliers.items():
        if size_str.endswith(suffix):
            try:
                number = float(size_str[:-len(suffix)])
                return int(number * multiplier)
            except ValueError:
                break
    
    # Try parsing as plain number
    try:
        return int(size_str)
    except ValueError:
        raise ValueError(f"Invalid size format: {size_str}")


def get_process_info(pid: Optional[int] = None) -> dict:
    """Get process information"""
    import psutil
    
    try:
        if pid is None:
            pid = os.getpid()
        
        process = psutil.Process(pid)
        
        return {
            'pid': process.pid,
            'name': process.name(),
            'status': process.status(),
            'cpu_percent': process.cpu_percent(),
            'memory_percent': process.memory_percent(),
            'memory_info': process.memory_info()._asdict(),
            'create_time': process.create_time(),
            'num_threads': process.num_threads(),
            'connections': len(process.connections()),
        }
    except Exception as e:
        logger.error(f"Failed to get process info: {e}")
        return {}


def timestamp_to_str(timestamp: float, format_str: str = "%Y-%m-%d %H:%M:%S") -> str:
    """Convert timestamp to formatted string"""
    return time.strftime(format_str, time.localtime(timestamp))


def str_to_timestamp(time_str: str, format_str: str = "%Y-%m-%d %H:%M:%S") -> float:
    """Convert formatted string to timestamp"""
    return time.mktime(time.strptime(time_str, format_str))


def cleanup_old_files(directory: Union[str, Path], max_age_days: int = 7, pattern: str = "*") -> int:
    """Cleanup old files in directory"""
    directory = Path(directory)
    current_time = time.time()
    max_age_seconds = max_age_days * 24 * 3600
    deleted_count = 0
    
    try:
        for file_path in directory.glob(pattern):
            if file_path.is_file():
                file_age = current_time - file_path.stat().st_mtime
                if file_age > max_age_seconds:
                    file_path.unlink()
                    deleted_count += 1
                    logger.debug(f"Deleted old file: {file_path}")
    except Exception as e:
        logger.error(f"Failed to cleanup files in {directory}: {e}")
    
    return deleted_count


def is_service_running(service_name: str) -> bool:
    """Check if systemd service is running"""
    try:
        import subprocess
        result = subprocess.run(
            ['systemctl', 'is-active', service_name],
            capture_output=True,
            text=True
        )
        return result.returncode == 0 and result.stdout.strip() == 'active'
    except Exception:
        return False


def get_service_status(service_name: str) -> dict:
    """Get detailed service status"""
    try:
        import subprocess
        
        # Get service status
        result = subprocess.run(
            ['systemctl', 'status', service_name],
            capture_output=True,
            text=True
        )
        
        status_info = {
            'active': 'active' in result.stdout,
            'enabled': False,
            'output': result.stdout,
            'error': result.stderr,
        }
        
        # Check if enabled
        result = subprocess.run(
            ['systemctl', 'is-enabled', service_name],
            capture_output=True,
            text=True
        )
        status_info['enabled'] = result.returncode == 0 and result.stdout.strip() == 'enabled'
        
        return status_info
        
    except Exception as e:
        logger.error(f"Failed to get service status: {e}")
        return {'active': False, 'enabled': False, 'error': str(e)}
