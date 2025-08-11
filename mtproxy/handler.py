"""
Connection handler for MTProxy server
"""

import asyncio
import time
import socket
from typing import Optional, Dict, Any, List
from dataclasses import dataclass, field

from .protocol import MTProtoHandler, ConnectionInfo
from .exceptions import ConnectionError, ProtocolError
from .logger import get_logger, log_access, log_error
from .utils import format_bytes, format_duration, validate_ip_address

logger = get_logger(__name__)


@dataclass
class ClientInfo:
    """Client connection information"""
    ip: str
    port: int
    connect_time: float
    last_seen: float
    bytes_sent: int = 0
    bytes_received: int = 0
    connection_count: int = 1
    blocked: bool = False
    block_reason: str = ""


class ConnectionHandler:
    """Handles client connections and security policies"""
    
    def __init__(self, config: Dict[str, Any]):
        self.config = config
        self.mtproto_handler = MTProtoHandler(config['secret'])
        
        # Connection management
        self.clients: Dict[str, ClientInfo] = {}
        self.active_connections: Dict[str, ConnectionInfo] = {}
        self.blocked_ips: set = set(config.get('banned_ips', []))
        self.allowed_ips: set = set(config.get('allowed_ips', []))
        
        # Rate limiting
        self.rate_limit = config.get('rate_limit', 100)  # connections per minute
        self.connection_timeout = config.get('timeout', 300)
        self.max_connections_per_ip = config.get('max_connections_per_ip', 10)
        
        # Statistics
        self.stats = {
            'total_connections': 0,
            'active_connections': 0,
            'blocked_connections': 0,
            'total_bytes_sent': 0,
            'total_bytes_received': 0,
            'start_time': time.time(),
        }
        
        logger.info("Connection handler initialized")
    
    async def handle_client(self, reader: asyncio.StreamReader, writer: asyncio.StreamWriter):
        """Handle incoming client connection"""
        client_addr = writer.get_extra_info('peername')
        if not client_addr:
            logger.warning("Could not get client address")
            await self._close_connection(writer)
            return
        
        client_ip, client_port = client_addr
        connection_id = f"{client_ip}:{client_port}:{time.time()}"
        
        # Update statistics
        self.stats['total_connections'] += 1
        self.stats['active_connections'] += 1
        
        logger.info(f"New connection: {client_ip}:{client_port}")
        
        try:
            # Security checks
            if not await self._security_check(client_ip):
                self.stats['blocked_connections'] += 1
                await self._close_connection(writer)
                return
            
            # Rate limiting
            if not await self._rate_limit_check(client_ip):
                self.stats['blocked_connections'] += 1
                await self._close_connection(writer)
                return
            
            # Update client info
            await self._update_client_info(client_ip, client_port)
            
            # Handle the connection
            await self._handle_connection(reader, writer, client_ip, client_port, connection_id)
            
        except Exception as e:
            logger.error(f"Error handling client {client_ip}: {e}")
            log_error(e, f"Client handler for {client_ip}")
        finally:
            # Cleanup
            self.stats['active_connections'] -= 1
            if connection_id in self.active_connections:
                del self.active_connections[connection_id]
            
            await self._close_connection(writer)
            
            logger.info(f"Connection closed: {client_ip}:{client_port}")
    
    async def _security_check(self, client_ip: str) -> bool:
        """Perform security checks on client IP"""
        
        # Check blocked IPs
        if client_ip in self.blocked_ips:
            logger.warning(f"Blocked IP attempted connection: {client_ip}")
            log_access(client_ip, "CONNECT", "BLOCKED", "IP in blocklist")
            return False
        
        # Check allowed IPs (if whitelist is configured)
        if self.allowed_ips and client_ip not in self.allowed_ips:
            logger.warning(f"Non-whitelisted IP attempted connection: {client_ip}")
            log_access(client_ip, "CONNECT", "BLOCKED", "IP not in whitelist")
            return False
        
        # Check if client is already marked as blocked
        if client_ip in self.clients and self.clients[client_ip].blocked:
            logger.warning(f"Previously blocked client attempted connection: {client_ip}")
            log_access(client_ip, "CONNECT", "BLOCKED", self.clients[client_ip].block_reason)
            return False
        
        return True
    
    async def _rate_limit_check(self, client_ip: str) -> bool:
        """Check rate limiting for client IP"""
        current_time = time.time()
        
        # Check connection count per IP
        client_connections = sum(1 for conn in self.active_connections.values() 
                               if conn.client_ip == client_ip)
        
        if client_connections >= self.max_connections_per_ip:
            logger.warning(f"Too many connections from {client_ip}: {client_connections}")
            log_access(client_ip, "CONNECT", "RATE_LIMITED", f"connections={client_connections}")
            return False
        
        # Check rate limiting (connections per minute)
        if client_ip in self.clients:
            client = self.clients[client_ip]
            time_diff = current_time - client.connect_time
            
            if time_diff < 60:  # Within last minute
                if client.connection_count >= self.rate_limit:
                    logger.warning(f"Rate limit exceeded for {client_ip}: {client.connection_count}/min")
                    log_access(client_ip, "CONNECT", "RATE_LIMITED", f"rate={client.connection_count}/min")
                    
                    # Block client temporarily
                    await self._block_client(client_ip, "Rate limit exceeded")
                    return False
        
        return True
    
    async def _update_client_info(self, client_ip: str, client_port: int):
        """Update client information"""
        current_time = time.time()
        
        if client_ip not in self.clients:
            self.clients[client_ip] = ClientInfo(
                ip=client_ip,
                port=client_port,
                connect_time=current_time,
                last_seen=current_time
            )
        else:
            client = self.clients[client_ip]
            client.last_seen = current_time
            client.connection_count += 1
            
            # Reset connection count if it's been more than a minute
            if current_time - client.connect_time > 60:
                client.connect_time = current_time
                client.connection_count = 1
    
    async def _handle_connection(self, reader: asyncio.StreamReader, writer: asyncio.StreamWriter,
                               client_ip: str, client_port: int, connection_id: str):
        """Handle the actual connection"""
        
        # Create connection info
        conn_info = ConnectionInfo(
            client_ip=client_ip,
            client_port=client_port,
            server_ip="",
            server_port=0,
            start_time=time.time(),
            last_activity=time.time()
        )
        
        self.active_connections[connection_id] = conn_info
        
        try:
            # Set connection timeout
            reader._transport.set_write_buffer_limits(high=1024*1024)  # 1MB buffer
            
            # Handle with MTProto handler
            await asyncio.wait_for(
                self.mtproto_handler.handle_connection(reader, writer),
                timeout=self.connection_timeout
            )
            
        except asyncio.TimeoutError:
            logger.warning(f"Connection timeout for {client_ip}")
            log_access(client_ip, "TIMEOUT", "CLOSED", f"timeout={self.connection_timeout}s")
        
        except Exception as e:
            logger.error(f"Connection error for {client_ip}: {e}")
            log_access(client_ip, "ERROR", "FAILED", str(e))
        
        finally:
            # Update statistics
            if client_ip in self.clients:
                client = self.clients[client_ip]
                client.bytes_sent += conn_info.bytes_sent
                client.bytes_received += conn_info.bytes_received
                
                self.stats['total_bytes_sent'] += conn_info.bytes_sent
                self.stats['total_bytes_received'] += conn_info.bytes_received
    
    async def _close_connection(self, writer: asyncio.StreamWriter):
        """Safely close connection"""
        try:
            if not writer.is_closing():
                writer.close()
                await writer.wait_closed()
        except Exception as e:
            logger.debug(f"Error closing connection: {e}")
    
    async def _block_client(self, client_ip: str, reason: str):
        """Block a client IP"""
        if client_ip in self.clients:
            self.clients[client_ip].blocked = True
            self.clients[client_ip].block_reason = reason
        
        self.blocked_ips.add(client_ip)
        logger.warning(f"Blocked client {client_ip}: {reason}")
        log_access(client_ip, "BLOCK", "APPLIED", reason)
    
    async def unblock_client(self, client_ip: str) -> bool:
        """Unblock a client IP"""
        if client_ip in self.blocked_ips:
            self.blocked_ips.remove(client_ip)
            
            if client_ip in self.clients:
                self.clients[client_ip].blocked = False
                self.clients[client_ip].block_reason = ""
            
            logger.info(f"Unblocked client {client_ip}")
            log_access(client_ip, "UNBLOCK", "APPLIED")
            return True
        
        return False
    
    def get_stats(self) -> Dict[str, Any]:
        """Get handler statistics"""
        current_time = time.time()
        uptime = current_time - self.stats['start_time']
        
        return {
            **self.stats,
            'uptime': uptime,
            'uptime_formatted': format_duration(uptime),
            'total_bytes_formatted': {
                'sent': format_bytes(self.stats['total_bytes_sent']),
                'received': format_bytes(self.stats['total_bytes_received']),
            },
            'rates': {
                'connections_per_hour': self.stats['total_connections'] / (uptime / 3600) if uptime > 0 else 0,
                'bytes_per_second': (self.stats['total_bytes_sent'] + self.stats['total_bytes_received']) / uptime if uptime > 0 else 0,
            }
        }
    
    def get_client_stats(self) -> List[Dict[str, Any]]:
        """Get client statistics"""
        current_time = time.time()
        
        client_stats = []
        for client in self.clients.values():
            # Count active connections for this client
            active_conns = sum(1 for conn in self.active_connections.values() 
                             if conn.client_ip == client.ip)
            
            client_stats.append({
                'ip': client.ip,
                'port': client.port,
                'connect_time': client.connect_time,
                'last_seen': client.last_seen,
                'duration': current_time - client.connect_time,
                'duration_formatted': format_duration(current_time - client.connect_time),
                'bytes_sent': client.bytes_sent,
                'bytes_received': client.bytes_received,
                'bytes_sent_formatted': format_bytes(client.bytes_sent),
                'bytes_received_formatted': format_bytes(client.bytes_received),
                'connection_count': client.connection_count,
                'active_connections': active_conns,
                'blocked': client.blocked,
                'block_reason': client.block_reason,
            })
        
        # Sort by last seen (most recent first)
        client_stats.sort(key=lambda x: x['last_seen'], reverse=True)
        
        return client_stats
    
    def get_active_connections(self) -> List[Dict[str, Any]]:
        """Get active connection information"""
        current_time = time.time()
        
        connections = []
        for conn_id, conn in self.active_connections.items():
            connections.append({
                'id': conn_id,
                'client_ip': conn.client_ip,
                'client_port': conn.client_port,
                'server_ip': conn.server_ip,
                'server_port': conn.server_port,
                'start_time': conn.start_time,
                'duration': current_time - conn.start_time,
                'duration_formatted': format_duration(current_time - conn.start_time),
                'last_activity': conn.last_activity,
                'idle_time': current_time - conn.last_activity,
                'idle_time_formatted': format_duration(current_time - conn.last_activity),
                'bytes_sent': conn.bytes_sent,
                'bytes_received': conn.bytes_received,
                'bytes_sent_formatted': format_bytes(conn.bytes_sent),
                'bytes_received_formatted': format_bytes(conn.bytes_received),
            })
        
        # Sort by start time (newest first)
        connections.sort(key=lambda x: x['start_time'], reverse=True)
        
        return connections
    
    async def cleanup_old_clients(self, max_age_hours: int = 24):
        """Cleanup old client information"""
        current_time = time.time()
        max_age_seconds = max_age_hours * 3600
        
        old_clients = [ip for ip, client in self.clients.items()
                      if current_time - client.last_seen > max_age_seconds]
        
        for client_ip in old_clients:
            del self.clients[client_ip]
        
        if old_clients:
            logger.info(f"Cleaned up {len(old_clients)} old client records")
        
        return len(old_clients)
