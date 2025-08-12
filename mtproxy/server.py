"""
MTProxy server implementation
"""

import asyncio
import signal
import sys
import os
import time
from typing import Optional, Dict, Any
from pathlib import Path

from .config import Config
from .handler import ConnectionHandler
from .logger import setup_logging, get_logger
from .exceptions import ServerError, ConfigError
from .utils import get_local_ip, check_port_available, create_directory

logger = get_logger(__name__)


class MTProxyServer:
    """MTProxy server class"""
    
    def __init__(self, config_file: Optional[str] = None):
        """Initialize server with configuration"""
        try:
            self.config = Config(config_file)
            
            # Setup logging
            setup_logging(self.config.get_logging_config())
            
            # Initialize components
            self.handler = ConnectionHandler(self.config.get_server_config())
            self.server = None
            self.running = False
            self.start_time = None
            
            # Setup signal handlers
            self._setup_signal_handlers()
            
            logger.info("MTProxy server initialized")
            
        except Exception as e:
            print(f"Failed to initialize server: {e}")
            raise ServerError(f"Server initialization failed: {e}")
    
    def _setup_signal_handlers(self):
        """Setup signal handlers for graceful shutdown"""
        def signal_handler(signum, frame):
            logger.info(f"Received signal {signum}, shutting down...")
            asyncio.create_task(self.stop())
        
        signal.signal(signal.SIGINT, signal_handler)
        signal.signal(signal.SIGTERM, signal_handler)
        
        if hasattr(signal, 'SIGHUP'):
            def reload_handler(signum, frame):
                logger.info("Received SIGHUP, reloading configuration...")
                asyncio.create_task(self.reload_config())
            signal.signal(signal.SIGHUP, reload_handler)
    
    async def start(self):
        """Start the MTProxy server"""
        if self.running:
            logger.warning("Server is already running")
            return
        
        try:
            # Get server configuration
            server_config = self.config.get_server_config()
            host = server_config['host']
            port = server_config['port']
            
            # Validate configuration
            if not check_port_available(host, port):
                raise ServerError(f"Port {port} is already in use")
            
            # Create necessary directories
            self._create_directories()
            
            # Start server
            logger.info(f"Starting MTProxy server on {host}:{port}")
            
            self.server = await asyncio.start_server(
                self.handler.handle_client,
                host=host,
                port=port,
                reuse_address=True,
                reuse_port=True,
            )
            
            self.running = True
            self.start_time = time.time()
            
            # Log server information
            local_ip = get_local_ip()
            secret = self.config.get('server.secret')
            tls_secret = self.config.get('server.tls_secret')
            fake_domain = self.config.get('server.fake_domain')
            
            logger.info("=" * 60)
            logger.info("MTProxy Server Started Successfully!")
            logger.info("=" * 60)
            logger.info(f"Listening on: {host}:{port}")
            logger.info(f"Local IP: {local_ip}")
            logger.info(f"Secret: {secret}")
            if tls_secret:
                logger.info(f"TLS Secret: {tls_secret}")
                logger.info(f"Fake Domain: {fake_domain}")
            logger.info(f"Max connections: {server_config['max_connections']}")
            logger.info(f"Workers: {server_config['workers']}")
            logger.info(f"Timeout: {server_config['timeout']}s")
            logger.info("=" * 60)
            
            # 下载官方配置文件
            self._download_official_configs()
            
            # 生成连接链接
            try:
                import requests
                try:
                    external_ip = requests.get('https://api.ip.sb/ip', timeout=5).text.strip()
                except:
                    external_ip = requests.get('https://ipinfo.io/ip', timeout=5).text.strip()
                
                logger.info("📱 Telegram连接链接:")
                logger.info(f"普通模式: https://t.me/proxy?server={external_ip}&port={port}&secret={secret}")
                if tls_secret:
                    logger.info(f"TLS模式: https://t.me/proxy?server={external_ip}&port={port}&secret={tls_secret}")
                logger.info("=" * 60)
            except:
                logger.warning("无法获取外网IP，请手动生成连接链接")
            
            # Start background tasks
            await self._start_background_tasks()
            
            # Serve forever
            async with self.server:
                await self.server.serve_forever()
                
        except Exception as e:
            logger.error(f"Failed to start server: {e}")
            self.running = False

    def _download_official_configs(self):
        """下载官方配置文件"""
        import os
        import requests
        
        config_dir = "config"
        os.makedirs(config_dir, exist_ok=True)
        
        files = [
            ("https://core.telegram.org/getProxySecret", "proxy-secret"),
            ("https://core.telegram.org/getProxyConfig", "proxy-multi.conf")
        ]
        
        for url, filename in files:
            filepath = os.path.join(config_dir, filename)
            try:
                response = requests.get(url, timeout=10)
                response.raise_for_status()
                with open(filepath, 'wb') as f:
                    f.write(response.content)
                logger.info(f"已下载 {filename}")
            except Exception as e:
                logger.warning(f"下载 {filename} 失败: {e}")
    
    async def stop(self):
        """Stop the MTProxy server"""
        if not self.running:
            logger.warning("Server is not running")
            return
        
        logger.info("Stopping MTProxy server...")
        
        try:
            self.running = False
            
            # Stop accepting new connections
            if self.server:
                self.server.close()
                await self.server.wait_closed()
                self.server = None
            
            # Close existing connections
            await self._close_connections()
            
            # Stop background tasks
            await self._stop_background_tasks()
            
            uptime = time.time() - self.start_time if self.start_time else 0
            stats = self.handler.get_stats()
            
            logger.info("=" * 60)
            logger.info("MTProxy Server Stopped")
            logger.info("=" * 60)
            logger.info(f"Uptime: {uptime:.1f} seconds")
            logger.info(f"Total connections: {stats['total_connections']}")
            logger.info(f"Bytes sent: {stats['total_bytes_formatted']['sent']}")
            logger.info(f"Bytes received: {stats['total_bytes_formatted']['received']}")
            logger.info("=" * 60)
            
        except Exception as e:
            logger.error(f"Error during shutdown: {e}")
    
    async def restart(self):
        """Restart the server"""
        logger.info("Restarting MTProxy server...")
        await self.stop()
        await asyncio.sleep(1)  # Brief pause
        await self.start()
    
    async def reload_config(self):
        """Reload configuration"""
        try:
            logger.info("Reloading configuration...")
            self.config.reload()
            
            # Update handler configuration
            server_config = self.config.get_server_config()
            self.handler.config.update(server_config)
            
            # Update logging if needed
            setup_logging(self.config.get_logging_config())
            
            logger.info("Configuration reloaded successfully")
            
        except Exception as e:
            logger.error(f"Failed to reload configuration: {e}")
    
    def _create_directories(self):
        """Create necessary directories"""
        directories = [
            '/opt/python-mtproxy/logs',
            '/opt/python-mtproxy/data',
            'logs',
            'data',
        ]
        
        for directory in directories:
            try:
                create_directory(directory)
            except Exception:
                pass  # Ignore errors for optional directories
    
    async def _start_background_tasks(self):
        """Start background maintenance tasks"""
        
        async def cleanup_task():
            """Periodic cleanup task"""
            while self.running:
                try:
                    # Cleanup old client records
                    await self.handler.cleanup_old_clients()
                    
                    # Log statistics
                    stats = self.handler.get_stats()
                    logger.info(f"Stats: {stats['active_connections']} active, "
                              f"{stats['total_connections']} total connections")
                    
                except Exception as e:
                    logger.error(f"Background task error: {e}")
                
                # Wait 5 minutes
                await asyncio.sleep(300)
        
        # Start cleanup task
        asyncio.create_task(cleanup_task())
        logger.debug("Background tasks started")
    
    async def _stop_background_tasks(self):
        """Stop background tasks"""
        # Cancel all running tasks
        tasks = [task for task in asyncio.all_tasks() if not task.done()]
        for task in tasks:
            task.cancel()
        
        # Wait for tasks to complete
        if tasks:
            await asyncio.gather(*tasks, return_exceptions=True)
        
        logger.debug("Background tasks stopped")
    
    async def _close_connections(self):
        """Close all active connections"""
        try:
            # Force close all connections
            for conn_id in list(self.handler.active_connections.keys()):
                # Connections will be cleaned up automatically
                pass
            
            # Wait a moment for cleanup
            await asyncio.sleep(1)
            
            logger.info("All connections closed")
            
        except Exception as e:
            logger.error(f"Error closing connections: {e}")
    
    def get_status(self) -> Dict[str, Any]:
        """Get server status"""
        uptime = time.time() - self.start_time if self.start_time else 0
        
        return {
            'running': self.running,
            'start_time': self.start_time,
            'uptime': uptime,
            'config': {
                'host': self.config.get('server.host'),
                'port': self.config.get('server.port'),
                'secret': self.config.get('server.secret')[:8] + "..." if self.config.get('server.secret') else None,
                'max_connections': self.config.get('server.max_connections'),
                'timeout': self.config.get('server.timeout'),
            },
            'stats': self.handler.get_stats(),
            'clients': len(self.handler.clients),
            'blocked_ips': len(self.handler.blocked_ips),
        }
    
    def get_detailed_stats(self) -> Dict[str, Any]:
        """Get detailed statistics"""
        return {
            'server': self.get_status(),
            'handler': self.handler.get_stats(),
            'clients': self.handler.get_client_stats(),
            'connections': self.handler.get_active_connections(),
            'config': self.config.to_dict(),
        }


async def main():
    """Main entry point"""
    import argparse
    
    parser = argparse.ArgumentParser(description='Python MTProxy Server')
    parser.add_argument('--config', '-c', type=str, help='Configuration file path')
    parser.add_argument('--host', type=str, help='Host to bind to')
    parser.add_argument('--port', '-p', type=int, help='Port to bind to')
    parser.add_argument('--secret', '-s', type=str, help='Proxy secret')
    parser.add_argument('--daemon', '-d', action='store_true', help='Run as daemon')
    parser.add_argument('--pidfile', type=str, help='PID file path')
    parser.add_argument('--version', '-v', action='version', version='MTProxy 1.0.0')
    
    args = parser.parse_args()
    
    try:
        # Create server
        server = MTProxyServer(args.config)
        
        # Override config with command line arguments
        if args.host:
            server.config.set('server.host', args.host)
        if args.port:
            server.config.set('server.port', args.port)
        if args.secret:
            server.config.set('server.secret', args.secret)
        
        # Write PID file if specified
        if args.pidfile:
            with open(args.pidfile, 'w') as f:
                f.write(str(os.getpid()))
        
        # Run as daemon if specified
        if args.daemon:
            # Basic daemonization
            if os.fork() > 0:
                sys.exit(0)
            
            os.setsid()
            
            if os.fork() > 0:
                sys.exit(0)
            
            # Redirect standard file descriptors
            sys.stdout.flush()
            sys.stderr.flush()
            
            with open('/dev/null', 'r') as f:
                os.dup2(f.fileno(), sys.stdin.fileno())
            
            with open('/dev/null', 'w') as f:
                os.dup2(f.fileno(), sys.stdout.fileno())
                os.dup2(f.fileno(), sys.stderr.fileno())
        
        # Start server
        await server.start()
        
    except KeyboardInterrupt:
        logger.info("Interrupted by user")
    except Exception as e:
        logger.error(f"Server error: {e}")
        sys.exit(1)
    finally:
        # Cleanup PID file
        if args.pidfile and os.path.exists(args.pidfile):
            os.unlink(args.pidfile)


if __name__ == '__main__':
    asyncio.run(main())
