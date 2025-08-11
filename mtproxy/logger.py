"""
Logging configuration and utilities for MTProxy
"""

import logging
import logging.handlers
import os
import sys
from pathlib import Path
from typing import Optional

from .exceptions import ConfigError


class ColoredFormatter(logging.Formatter):
    """Colored console formatter"""
    
    COLORS = {
        'DEBUG': '\033[36m',     # Cyan
        'INFO': '\033[32m',      # Green
        'WARNING': '\033[33m',   # Yellow
        'ERROR': '\033[31m',     # Red
        'CRITICAL': '\033[35m',  # Magenta
    }
    RESET = '\033[0m'
    
    def format(self, record):
        log_color = self.COLORS.get(record.levelname, '')
        record.levelname = f"{log_color}{record.levelname}{self.RESET}"
        return super().format(record)


def setup_logging(config: Optional[dict] = None):
    """Setup logging configuration"""
    if config is None:
        config = {
            'level': 'INFO',
            'file': '/opt/python-mtproxy/logs/mtproxy.log',
            'max_size': '100MB',
            'backup_count': 7,
            'format': '%(asctime)s - %(name)s - %(levelname)s - %(message)s',
        }
    
    # Create logs directory
    log_file = config.get('file', '/opt/python-mtproxy/logs/mtproxy.log')
    log_dir = Path(log_file).parent
    log_dir.mkdir(parents=True, exist_ok=True)
    
    # Parse log level
    level = getattr(logging, config.get('level', 'INFO').upper(), logging.INFO)
    
    # Parse max size
    max_size = config.get('max_size', '100MB')
    if isinstance(max_size, str):
        if max_size.endswith('MB'):
            max_bytes = int(max_size[:-2]) * 1024 * 1024
        elif max_size.endswith('KB'):
            max_bytes = int(max_size[:-2]) * 1024
        elif max_size.endswith('GB'):
            max_bytes = int(max_size[:-2]) * 1024 * 1024 * 1024
        else:
            max_bytes = int(max_size)
    else:
        max_bytes = max_size
    
    # Setup root logger
    root_logger = logging.getLogger()
    root_logger.setLevel(level)
    
    # Clear existing handlers
    root_logger.handlers.clear()
    
    # File handler with rotation
    try:
        file_handler = logging.handlers.RotatingFileHandler(
            log_file,
            maxBytes=max_bytes,
            backupCount=config.get('backup_count', 7),
            encoding='utf-8'
        )
        file_formatter = logging.Formatter(
            config.get('format', '%(asctime)s - %(name)s - %(levelname)s - %(message)s')
        )
        file_handler.setFormatter(file_formatter)
        file_handler.setLevel(level)
        root_logger.addHandler(file_handler)
    except Exception as e:
        raise ConfigError(f"Failed to setup file logging: {e}")
    
    # Console handler with colors
    console_handler = logging.StreamHandler(sys.stdout)
    console_formatter = ColoredFormatter(
        '%(asctime)s - %(name)s - %(levelname)s - %(message)s'
    )
    console_handler.setFormatter(console_formatter)
    console_handler.setLevel(level)
    root_logger.addHandler(console_handler)
    
    # Setup specific loggers
    setup_specific_loggers(log_dir, level, max_bytes, config.get('backup_count', 7))
    
    logging.info("Logging system initialized")


def setup_specific_loggers(log_dir: Path, level: int, max_bytes: int, backup_count: int):
    """Setup specific loggers for different components"""
    
    loggers_config = [
        ('mtproxy.server', 'mtproxy-server.log'),
        ('mtproxy.handler', 'mtproxy-handler.log'),
        ('mtproxy.crypto', 'mtproxy-crypto.log'),
        ('mtproxy.protocol', 'mtproxy-protocol.log'),
        ('mtproxy.access', 'mtproxy-access.log'),
        ('mtproxy.error', 'mtproxy-error.log'),
    ]
    
    for logger_name, filename in loggers_config:
        logger = logging.getLogger(logger_name)
        
        # File handler for this specific logger
        log_file = log_dir / filename
        handler = logging.handlers.RotatingFileHandler(
            log_file,
            maxBytes=max_bytes,
            backupCount=backup_count,
            encoding='utf-8'
        )
        
        formatter = logging.Formatter(
            '%(asctime)s - %(name)s - %(levelname)s - %(message)s'
        )
        handler.setFormatter(formatter)
        handler.setLevel(level)
        
        logger.addHandler(handler)
        logger.setLevel(level)
    
    # Error logger - only ERROR and CRITICAL
    error_logger = logging.getLogger('mtproxy.error')
    error_logger.setLevel(logging.ERROR)


def get_logger(name: str) -> logging.Logger:
    """Get logger instance"""
    return logging.getLogger(name)


def setup_access_logging(log_dir: Path, max_bytes: int, backup_count: int):
    """Setup access logging"""
    access_logger = logging.getLogger('mtproxy.access')
    access_logger.setLevel(logging.INFO)
    
    # Remove console handler for access log
    access_logger.propagate = False
    
    log_file = log_dir / 'mtproxy-access.log'
    handler = logging.handlers.RotatingFileHandler(
        log_file,
        maxBytes=max_bytes,
        backupCount=backup_count,
        encoding='utf-8'
    )
    
    # Access log format: timestamp, client_ip, action, status
    formatter = logging.Formatter(
        '%(asctime)s - %(message)s'
    )
    handler.setFormatter(formatter)
    access_logger.addHandler(handler)
    
    return access_logger


def log_access(client_ip: str, action: str, status: str = "OK", details: str = ""):
    """Log access information"""
    access_logger = logging.getLogger('mtproxy.access')
    message = f"{client_ip} - {action} - {status}"
    if details:
        message += f" - {details}"
    access_logger.info(message)


def log_error(error: Exception, context: str = ""):
    """Log error with context"""
    error_logger = logging.getLogger('mtproxy.error')
    message = f"{context}: {type(error).__name__}: {error}"
    error_logger.error(message, exc_info=True)
