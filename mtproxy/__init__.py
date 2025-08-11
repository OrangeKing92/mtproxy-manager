"""
Python MTProxy - Telegram MTProto Proxy Implementation

A modern, feature-rich Python implementation of MTProxy with SSH remote management capabilities.
"""

__version__ = "1.0.0"
__author__ = "MTProxy Team"
__email__ = "admin@example.com"

from .server import MTProxyServer
from .config import Config
from .logger import setup_logging

__all__ = ['MTProxyServer', 'Config', 'setup_logging']
