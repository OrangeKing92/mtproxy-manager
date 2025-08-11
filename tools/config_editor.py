#!/usr/bin/env python3
"""
MTProxy Configuration Editor - Interactive configuration management tool
"""

import os
import sys
import time
import argparse
import json
from pathlib import Path
from typing import Dict, Any, Optional

# Add project root to Python path
project_root = Path(__file__).parent.parent
sys.path.insert(0, str(project_root))

try:
    from mtproxy.config import Config
    from mtproxy.utils import validate_ip_address, validate_port, generate_secret
    from mtproxy.exceptions import ConfigError
except ImportError as e:
    print(f"Error importing modules: {e}")
    sys.exit(1)


class ConfigEditor:
    """Interactive configuration editor"""
    
    def __init__(self, config_file: Optional[str] = None):
        try:
            self.config = Config(config_file)
        except Exception as e:
            print(f"Error loading configuration: {e}")
            sys.exit(1)
    
    def interactive_edit(self):
        """Interactive configuration editing"""
        print("MTProxy Configuration Editor")
        print("=" * 40)
        print("Current configuration values:")
        print()
        
        # Display current values
        sections = [
            ("Server Settings", [
                ('server.host', 'Host'),
                ('server.port', 'Port'),
                ('server.secret', 'Secret'),
                ('server.max_connections', 'Max Connections'),
                ('server.timeout', 'Timeout (seconds)'),
                ('server.workers', 'Workers'),
            ]),
            ("Logging Settings", [
                ('logging.level', 'Log Level'),
                ('logging.file', 'Log File'),
                ('logging.max_size', 'Max Log Size'),
                ('logging.backup_count', 'Backup Count'),
            ]),
            ("Security Settings", [
                ('security.rate_limit', 'Rate Limit'),
                ('security.max_connections_per_ip', 'Max Connections per IP'),
            ]),
        ]
        
        for section_name, settings in sections:
            print(f"\n{section_name}:")
            print("-" * len(section_name))
            
            for key, label in settings:
                value = self.config.get(key)
                if key == 'server.secret' and value:
                    display_value = value[:8] + "..." if len(value) > 8 else value
                else:
                    display_value = value
                print(f"  {label}: {display_value}")
        
        print("\n" + "=" * 40)
        print("\nEnter new values (press Enter to keep current value)")
        print("Type 'help' for help, 'save' to save, 'quit' to exit without saving")
        print()
        
        modified = False
        
        while True:
            try:
                command = input("config> ").strip()
                
                if command.lower() in ['quit', 'exit', 'q']:
                    if modified:
                        save = input("Save changes before exiting? (y/N): ").strip().lower()
                        if save in ['y', 'yes']:
                            self._save_config()
                    break
                
                elif command.lower() in ['save', 's']:
                    self._save_config()
                    modified = False
                    print("Configuration saved!")
                
                elif command.lower() in ['help', 'h']:
                    self._show_help()
                
                elif command.lower() in ['show', 'display']:
                    self._show_current_config()
                
                elif command.lower() == 'generate-secret':
                    new_secret = generate_secret()
                    self.config.set('server.secret', new_secret)
                    print(f"Generated new secret: {new_secret}")
                    modified = True
                
                elif '=' in command:
                    # Direct assignment: key=value
                    key, value = command.split('=', 1)
                    key = key.strip()
                    value = value.strip()
                    
                    if self._set_config_value(key, value):
                        modified = True
                
                elif command:
                    # Interactive setting
                    if self._interactive_set(command):
                        modified = True
                
            except KeyboardInterrupt:
                print("\nUse 'quit' to exit")
            except EOFError:
                break
            except Exception as e:
                print(f"Error: {e}")
    
    def _interactive_set(self, key: str) -> bool:
        """Interactively set a configuration value"""
        current_value = self.config.get(key)
        
        if current_value is None:
            print(f"Unknown configuration key: {key}")
            return False
        
        print(f"\nSetting: {key}")
        print(f"Current value: {current_value}")
        
        if key == 'server.secret':
            print("Secret should be 32 hexadecimal characters")
            print("Type 'generate' to auto-generate a new secret")
        elif key == 'server.host':
            print("Host to bind to (0.0.0.0 for all interfaces)")
        elif key == 'server.port':
            print("Port number (1-65535)")
        elif key == 'logging.level':
            print("Available levels: DEBUG, INFO, WARNING, ERROR, CRITICAL")
        
        new_value = input(f"New value [{current_value}]: ").strip()
        
        if not new_value:
            print("Value unchanged")
            return False
        
        return self._set_config_value(key, new_value)
    
    def _set_config_value(self, key: str, value: str) -> bool:
        """Set a configuration value with validation"""
        try:
            # Type conversion and validation
            if key in ['server.port', 'server.max_connections', 'server.timeout', 
                      'server.workers', 'logging.backup_count', 'security.rate_limit',
                      'security.max_connections_per_ip']:
                try:
                    value = int(value)
                except ValueError:
                    print(f"Error: {key} must be an integer")
                    return False
            
            elif key == 'server.host':
                if value not in ['0.0.0.0', 'localhost', '127.0.0.1'] and not validate_ip_address(value):
                    print(f"Error: Invalid IP address: {value}")
                    return False
            
            elif key == 'server.port':
                if not validate_port(value):
                    print(f"Error: Port must be between 1 and 65535")
                    return False
            
            elif key == 'server.secret':
                if value.lower() == 'generate':
                    value = generate_secret()
                    print(f"Generated new secret: {value}")
                elif len(value) != 32:
                    print(f"Error: Secret must be 32 hexadecimal characters")
                    return False
                else:
                    try:
                        bytes.fromhex(value)
                    except ValueError:
                        print(f"Error: Secret must be valid hexadecimal")
                        return False
            
            elif key == 'logging.level':
                if value.upper() not in ['DEBUG', 'INFO', 'WARNING', 'ERROR', 'CRITICAL']:
                    print(f"Error: Invalid log level: {value}")
                    return False
                value = value.upper()
            
            # Set the value
            self.config.set(key, value)
            print(f"Set {key} = {value}")
            return True
            
        except Exception as e:
            print(f"Error setting {key}: {e}")
            return False
    
    def _save_config(self):
        """Save configuration to file"""
        try:
            self.config.save()
            print(f"Configuration saved to: {self.config.config_file}")
        except Exception as e:
            print(f"Error saving configuration: {e}")
    
    def _show_help(self):
        """Show help information"""
        print("""
Configuration Editor Help:
========================

Commands:
  help, h          - Show this help
  show, display    - Show current configuration
  save, s          - Save changes to file
  quit, q          - Exit (prompts to save if modified)
  generate-secret  - Generate a new random secret

Setting values:
  key=value        - Direct assignment (e.g., server.port=8080)
  key              - Interactive setting with current value

Available configuration keys:
  server.host                    - Host to bind to
  server.port                    - Port to listen on
  server.secret                  - Proxy secret (32 hex chars)
  server.max_connections         - Maximum connections
  server.timeout                 - Connection timeout
  server.workers                 - Number of workers
  logging.level                  - Log level
  logging.file                   - Log file path
  logging.max_size              - Maximum log file size
  logging.backup_count          - Number of backup files
  security.rate_limit           - Rate limit per IP
  security.max_connections_per_ip - Max connections per IP

Examples:
  server.port=8080              - Set port to 8080
  server.secret                 - Interactively set secret
  generate-secret               - Generate new secret
  logging.level=DEBUG           - Set log level to DEBUG
""")
    
    def _show_current_config(self):
        """Show current configuration"""
        print("\nCurrent Configuration:")
        print("=" * 30)
        config_dict = self.config.to_dict()
        
        def print_dict(d, indent=0):
            for key, value in d.items():
                if isinstance(value, dict):
                    print("  " * indent + f"{key}:")
                    print_dict(value, indent + 1)
                else:
                    if key == 'secret' and isinstance(value, str) and len(value) > 8:
                        value = value[:8] + "..."
                    print("  " * indent + f"{key}: {value}")
        
        print_dict(config_dict)
        print()
    
    def backup_config(self, backup_path: Optional[str] = None) -> str:
        """Create configuration backup"""
        if backup_path is None:
            config_dir = Path(self.config.config_file).parent
            backup_path = config_dir / f"mtproxy.conf.backup.{int(time.time())}"
        
        try:
            import shutil
            shutil.copy2(self.config.config_file, backup_path)
            return str(backup_path)
        except Exception as e:
            raise ConfigError(f"Failed to create backup: {e}")
    
    def restore_config(self, backup_path: str):
        """Restore configuration from backup"""
        try:
            import shutil
            shutil.copy2(backup_path, self.config.config_file)
            self.config.reload()
        except Exception as e:
            raise ConfigError(f"Failed to restore backup: {e}")
    
    def validate_config(self) -> bool:
        """Validate current configuration"""
        try:
            self.config._validate_config()
            print("Configuration is valid")
            return True
        except ConfigError as e:
            print(f"Configuration validation failed: {e}")
            return False
    
    def get_setting(self, key: str) -> Any:
        """Get a specific setting"""
        value = self.config.get(key)
        if value is None:
            print(f"Setting '{key}' not found")
        else:
            if key == 'server.secret' and isinstance(value, str) and len(value) > 8:
                print(f"{key}: {value[:8]}...")
            else:
                print(f"{key}: {value}")
        return value
    
    def set_setting(self, key: str, value: str) -> bool:
        """Set a specific setting"""
        return self._set_config_value(key, value)


def main():
    """Main entry point"""
    parser = argparse.ArgumentParser(description='MTProxy Configuration Editor')
    parser.add_argument('--config', '-c', type=str, help='Configuration file path')
    parser.add_argument('--set', type=str, help='Set value (format: key=value)')
    parser.add_argument('--get', type=str, help='Get value for key')
    parser.add_argument('--validate', action='store_true', help='Validate configuration')
    parser.add_argument('--backup', type=str, help='Create backup at specified path')
    parser.add_argument('--restore', type=str, help='Restore from backup')
    parser.add_argument('--generate-secret', action='store_true', help='Generate new secret')
    
    args = parser.parse_args()
    
    try:
        editor = ConfigEditor(args.config)
        
        if args.validate:
            editor.validate_config()
        
        elif args.get:
            editor.get_setting(args.get)
        
        elif args.set:
            if '=' not in args.set:
                print("Error: Set format should be key=value")
                sys.exit(1)
            
            key, value = args.set.split('=', 1)
            if editor.set_setting(key.strip(), value.strip()):
                editor._save_config()
        
        elif args.backup:
            backup_path = editor.backup_config(args.backup)
            print(f"Configuration backed up to: {backup_path}")
        
        elif args.restore:
            editor.restore_config(args.restore)
            print(f"Configuration restored from: {args.restore}")
        
        elif args.generate_secret:
            new_secret = generate_secret()
            editor.config.set('server.secret', new_secret)
            editor._save_config()
            print(f"Generated and saved new secret: {new_secret}")
        
        else:
            # Interactive mode
            editor.interactive_edit()
    
    except KeyboardInterrupt:
        print("\nEditor interrupted")
    except Exception as e:
        print(f"Error: {e}")
        sys.exit(1)


if __name__ == '__main__':
    main()
