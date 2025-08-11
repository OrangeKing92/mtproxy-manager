"""
Configuration management for MTProxy
"""

import os
import yaml
import secrets
from typing import Dict, Any, Optional
from pathlib import Path

from .exceptions import ConfigError
from .logger import get_logger

logger = get_logger(__name__)


class Config:
    """MTProxy configuration manager"""
    
    DEFAULT_CONFIG = {
        'server': {
            'host': '0.0.0.0',
            'port': 8443,
            'secret': None,
            'max_connections': 1000,
            'timeout': 300,
            'workers': 4,
            'buffer_size': 8192,
            'keepalive_timeout': 60,
        },
        'logging': {
            'level': 'INFO',
            'file': '/opt/python-mtproxy/logs/mtproxy.log',
            'max_size': '100MB',
            'backup_count': 7,
            'format': '%(asctime)s - %(name)s - %(levelname)s - %(message)s',
        },
        'security': {
            'allowed_ips': [],
            'banned_ips': [],
            'rate_limit': 100,
        },
        'monitoring': {
            'stats_enabled': True,
            'stats_port': 8080,
            'health_check_interval': 30,
        },
        'telegram': {
            'api_id': None,
            'api_hash': None,
            'datacenter': 'auto',
        }
    }
    
    def __init__(self, config_file: Optional[str] = None):
        self.config_file = config_file or self._find_config_file()
        self.config = self.DEFAULT_CONFIG.copy()
        self._load_config()
        self._load_environment()
        self._validate_config()
    
    def _find_config_file(self) -> str:
        """Find configuration file in standard locations"""
        possible_paths = [
            '/opt/python-mtproxy/config/mtproxy.conf',
            'config/mtproxy.conf',
            'mtproxy.conf',
            os.path.expanduser('~/.mtproxy.conf'),
        ]
        
        for path in possible_paths:
            if os.path.exists(path):
                return path
        
        # Create default config if none found
        config_dir = Path('/opt/python-mtproxy/config')
        if not config_dir.exists():
            config_dir = Path('config')
        
        config_dir.mkdir(parents=True, exist_ok=True)
        config_file = config_dir / 'mtproxy.conf'
        
        self._create_default_config(str(config_file))
        return str(config_file)
    
    def _create_default_config(self, config_file: str):
        """Create default configuration file"""
        config = self.DEFAULT_CONFIG.copy()
        
        # Generate random secret
        config['server']['secret'] = secrets.token_hex(16)
        
        try:
            with open(config_file, 'w') as f:
                yaml.dump(config, f, default_flow_style=False, indent=2)
            logger.info(f"Created default configuration: {config_file}")
        except Exception as e:
            raise ConfigError(f"Failed to create config file: {e}")
    
    def _load_config(self):
        """Load configuration from file"""
        if not os.path.exists(self.config_file):
            logger.warning(f"Config file not found: {self.config_file}")
            return
        
        try:
            with open(self.config_file, 'r') as f:
                file_config = yaml.safe_load(f) or {}
            
            self._deep_update(self.config, file_config)
            logger.info(f"Loaded configuration from: {self.config_file}")
            
        except Exception as e:
            raise ConfigError(f"Failed to load config file: {e}")
    
    def _load_environment(self):
        """Load configuration from environment variables"""
        env_mappings = {
            'MTPROXY_HOST': ('server', 'host'),
            'MTPROXY_PORT': ('server', 'port'),
            'MTPROXY_SECRET': ('server', 'secret'),
            'MTPROXY_MAX_CONNECTIONS': ('server', 'max_connections'),
            'MTPROXY_TIMEOUT': ('server', 'timeout'),
            'MTPROXY_WORKERS': ('server', 'workers'),
            'LOG_LEVEL': ('logging', 'level'),
            'LOG_FILE': ('logging', 'file'),
            'LOG_MAX_SIZE': ('logging', 'max_size'),
            'LOG_BACKUP_COUNT': ('logging', 'backup_count'),
            'STATS_ENABLED': ('monitoring', 'stats_enabled'),
            'STATS_PORT': ('monitoring', 'stats_port'),
            'HEALTH_CHECK_INTERVAL': ('monitoring', 'health_check_interval'),
        }
        
        for env_var, (section, key) in env_mappings.items():
            value = os.getenv(env_var)
            if value is not None:
                # Type conversion
                if key in ['port', 'max_connections', 'timeout', 'workers', 'backup_count', 'stats_port', 'health_check_interval']:
                    value = int(value)
                elif key in ['stats_enabled']:
                    value = value.lower() in ('true', '1', 'yes', 'on')
                
                self.config[section][key] = value
                logger.debug(f"Loaded from environment: {env_var}={value}")
    
    def _deep_update(self, target: Dict[str, Any], source: Dict[str, Any]):
        """Deep update dictionary"""
        for key, value in source.items():
            if key in target and isinstance(target[key], dict) and isinstance(value, dict):
                self._deep_update(target[key], value)
            else:
                target[key] = value
    
    def _validate_config(self):
        """Validate configuration values"""
        # Validate port
        port = self.get('server.port')
        if not (1 <= port <= 65535):
            raise ConfigError(f"Invalid port: {port}")
        
        # Validate secret
        secret = self.get('server.secret')
        if not secret:
            # Generate new secret
            secret = secrets.token_hex(16)
            self.set('server.secret', secret)
            self.save()
            logger.info("Generated new secret")
        
        # Validate workers
        workers = self.get('server.workers')
        if workers < 1:
            raise ConfigError(f"Invalid workers count: {workers}")
        
        # Validate max connections
        max_conn = self.get('server.max_connections')
        if max_conn < 1:
            raise ConfigError(f"Invalid max_connections: {max_conn}")
        
        logger.info("Configuration validated successfully")
    
    def get(self, key: str, default=None):
        """Get configuration value using dot notation"""
        keys = key.split('.')
        value = self.config
        
        for k in keys:
            if isinstance(value, dict) and k in value:
                value = value[k]
            else:
                return default
        
        return value
    
    def set(self, key: str, value: Any):
        """Set configuration value using dot notation"""
        keys = key.split('.')
        target = self.config
        
        for k in keys[:-1]:
            if k not in target:
                target[k] = {}
            target = target[k]
        
        target[keys[-1]] = value
    
    def save(self):
        """Save configuration to file"""
        try:
            # Create backup
            if os.path.exists(self.config_file):
                backup_file = f"{self.config_file}.backup"
                os.rename(self.config_file, backup_file)
            
            # Save new config
            with open(self.config_file, 'w') as f:
                yaml.dump(self.config, f, default_flow_style=False, indent=2)
            
            logger.info(f"Configuration saved to: {self.config_file}")
            
        except Exception as e:
            raise ConfigError(f"Failed to save config: {e}")
    
    def reload(self):
        """Reload configuration from file"""
        self.config = self.DEFAULT_CONFIG.copy()
        self._load_config()
        self._load_environment()
        self._validate_config()
        logger.info("Configuration reloaded")
    
    def get_telegram_config(self) -> Dict[str, str]:
        """Get Telegram API configuration"""
        return {
            'api_id': self.get('telegram.api_id'),
            'api_hash': self.get('telegram.api_hash'),
            'datacenter': self.get('telegram.datacenter', 'auto'),
        }
    
    def get_server_config(self) -> Dict[str, Any]:
        """Get server configuration"""
        return self.config['server'].copy()
    
    def get_logging_config(self) -> Dict[str, Any]:
        """Get logging configuration"""
        return self.config['logging'].copy()
    
    def to_dict(self) -> Dict[str, Any]:
        """Get full configuration as dictionary"""
        return self.config.copy()
    
    def __str__(self) -> str:
        """String representation of config"""
        # Hide sensitive information
        safe_config = self.config.copy()
        if 'secret' in safe_config.get('server', {}):
            safe_config['server']['secret'] = '***HIDDEN***'
        
        return yaml.dump(safe_config, default_flow_style=False, indent=2)
