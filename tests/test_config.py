"""
Tests for MTProxy configuration module
"""

import os
import tempfile
import pytest
from pathlib import Path

from mtproxy.config import Config
from mtproxy.exceptions import ConfigError


class TestConfig:
    """Test configuration management"""
    
    def test_default_config(self):
        """Test default configuration creation"""
        with tempfile.TemporaryDirectory() as temp_dir:
            config_file = Path(temp_dir) / "test_config.conf"
            config = Config(str(config_file))
            
            # Check default values
            assert config.get('server.host') == '0.0.0.0'
            assert config.get('server.port') == 8443
            assert isinstance(config.get('server.max_connections'), int)
            assert config.get('logging.level') == 'INFO'
    
    def test_config_file_creation(self):
        """Test configuration file creation"""
        with tempfile.TemporaryDirectory() as temp_dir:
            config_file = Path(temp_dir) / "test_config.conf"
            config = Config(str(config_file))
            
            # Config file should be created
            assert config_file.exists()
            
            # Should contain secret
            secret = config.get('server.secret')
            assert secret is not None
            assert len(secret) == 32
    
    def test_config_validation(self):
        """Test configuration validation"""
        with tempfile.TemporaryDirectory() as temp_dir:
            config_file = Path(temp_dir) / "test_config.conf"
            config = Config(str(config_file))
            
            # Test valid port
            config.set('server.port', 8080)
            config._validate_config()  # Should not raise
            
            # Test invalid port
            with pytest.raises(ConfigError):
                config.set('server.port', 70000)
                config._validate_config()
            
            with pytest.raises(ConfigError):
                config.set('server.port', 0)
                config._validate_config()
    
    def test_environment_override(self):
        """Test environment variable override"""
        with tempfile.TemporaryDirectory() as temp_dir:
            config_file = Path(temp_dir) / "test_config.conf"
            
            # Set environment variable
            os.environ['MTPROXY_PORT'] = '9999'
            
            try:
                config = Config(str(config_file))
                assert config.get('server.port') == 9999
            finally:
                # Cleanup
                del os.environ['MTPROXY_PORT']
    
    def test_get_set_operations(self):
        """Test get/set operations with dot notation"""
        with tempfile.TemporaryDirectory() as temp_dir:
            config_file = Path(temp_dir) / "test_config.conf"
            config = Config(str(config_file))
            
            # Test set
            config.set('server.timeout', 600)
            assert config.get('server.timeout') == 600
            
            # Test nested set
            config.set('new.nested.value', 'test')
            assert config.get('new.nested.value') == 'test'
            
            # Test default value
            assert config.get('nonexistent.key', 'default') == 'default'
    
    def test_config_reload(self):
        """Test configuration reload"""
        with tempfile.TemporaryDirectory() as temp_dir:
            config_file = Path(temp_dir) / "test_config.conf"
            config = Config(str(config_file))
            
            original_port = config.get('server.port')
            
            # Modify and save
            config.set('server.port', 9090)
            config.save()
            
            # Create new config instance (simulates reload)
            config2 = Config(str(config_file))
            assert config2.get('server.port') == 9090
            
            # Test reload method
            config.set('server.port', original_port)
            config.reload()
            assert config.get('server.port') == 9090  # Should reload from file
