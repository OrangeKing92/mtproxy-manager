"""
MTProto protocol implementation for MTProxy
"""

import asyncio
import struct
import time
import socket
from typing import Optional, Tuple, Dict, Any
from dataclasses import dataclass

from .crypto import MTProtoCrypto, TelegramCrypto, ProxyAuth
from .exceptions import ProtocolError, CryptoError
from .logger import get_logger, log_access
from .utils import format_bytes, calculate_crc32

logger = get_logger(__name__)


@dataclass
class ConnectionInfo:
    """Connection information"""
    client_ip: str
    client_port: int
    server_ip: str
    server_port: int
    start_time: float
    bytes_sent: int = 0
    bytes_received: int = 0
    last_activity: float = 0
    auth_key: Optional[bytes] = None
    session_id: Optional[bytes] = None


class MTProtoHandler:
    """MTProto protocol handler"""
    
    def __init__(self, secret: str):
        self.secret = secret
        self.crypto = MTProtoCrypto(secret)
        self.auth = ProxyAuth(secret)
        self.connections: Dict[str, ConnectionInfo] = {}
        
        # Telegram DCs (data centers) - 使用官方最新地址
        self.telegram_dcs = {
            1: ("149.154.175.53", 443),
            2: ("149.154.167.51", 443),
            3: ("149.154.175.100", 443),
            4: ("149.154.167.91", 443),
            5: ("91.108.56.130", 443),
        }
        
        # 尝试加载官方配置文件更新DC地址
        self._load_official_config()
        
        logger.info("MTProto handler initialized")
    
    async def handle_connection(self, reader: asyncio.StreamReader, writer: asyncio.StreamWriter):
        """Handle incoming client connection"""
        client_addr = writer.get_extra_info('peername')
        client_ip, client_port = client_addr
        connection_id = f"{client_ip}:{client_port}"
        
        logger.info(f"New connection from {client_ip}:{client_port}")
        log_access(client_ip, "CONNECT", "ACCEPTED")
        
        # Create connection info
        conn_info = ConnectionInfo(
            client_ip=client_ip,
            client_port=client_port,
            server_ip="",
            server_port=0,
            start_time=time.time(),
            last_activity=time.time()
        )
        self.connections[connection_id] = conn_info
        
        try:
            await self._process_connection(reader, writer, conn_info)
        except Exception as e:
            logger.error(f"Connection error for {client_ip}: {e}")
            log_access(client_ip, "ERROR", "FAILED", str(e))
        finally:
            # Cleanup
            if connection_id in self.connections:
                del self.connections[connection_id]
            
            try:
                writer.close()
                await writer.wait_closed()
            except Exception:
                pass
            
            duration = time.time() - conn_info.start_time
            logger.info(f"Connection closed: {client_ip}, duration: {duration:.1f}s, "
                       f"sent: {format_bytes(conn_info.bytes_sent)}, "
                       f"received: {format_bytes(conn_info.bytes_received)}")
            log_access(client_ip, "DISCONNECT", "OK", 
                      f"duration={duration:.1f}s,sent={format_bytes(conn_info.bytes_sent)}")
    
    async def _process_connection(self, client_reader: asyncio.StreamReader, 
                                client_writer: asyncio.StreamWriter, 
                                conn_info: ConnectionInfo):
        """Process the connection after handshake"""
        
        # Perform handshake
        handshake_data = await self._perform_handshake(client_reader, client_writer, conn_info)
        if not handshake_data:
            raise ProtocolError("Handshake failed")
        
        auth_key, dc_id = handshake_data
        conn_info.auth_key = auth_key
        
        # Connect to Telegram DC
        telegram_reader, telegram_writer = await self._connect_to_telegram(dc_id, conn_info)
        
        try:
            # Start proxying data
            await self._proxy_data(client_reader, client_writer, 
                                 telegram_reader, telegram_writer, conn_info)
        finally:
            try:
                telegram_writer.close()
                await telegram_writer.wait_closed()
            except Exception:
                pass
    
    async def _perform_handshake(self, reader: asyncio.StreamReader, 
                               writer: asyncio.StreamWriter, 
                               conn_info: ConnectionInfo) -> Optional[Tuple[bytes, int]]:
        """Perform MTProxy handshake with client"""
        
        try:
            # Read initial handshake data (64 bytes)
            handshake_data = await asyncio.wait_for(reader.read(64), timeout=10.0)
            
            if len(handshake_data) != 64:
                logger.warning(f"Invalid handshake length: {len(handshake_data)}")
                return None
            
            conn_info.bytes_received += len(handshake_data)
            conn_info.last_activity = time.time()
            
            # Validate handshake
            if not self.auth.validate_client_handshake(handshake_data):
                logger.warning("Invalid client handshake")
                return None
            
            # Extract connection info from handshake
            dc_id = self._extract_dc_from_handshake(handshake_data)
            
            # Create handshake response
            response, auth_key, comm_iv = self.auth.create_handshake_response(handshake_data)
            
            # Send response
            writer.write(response)
            await writer.drain()
            
            conn_info.bytes_sent += len(response)
            conn_info.last_activity = time.time()
            
            logger.debug(f"Handshake completed for {conn_info.client_ip}, DC: {dc_id}")
            log_access(conn_info.client_ip, "HANDSHAKE", "OK", f"dc={dc_id}")
            
            return auth_key, dc_id
            
        except asyncio.TimeoutError:
            logger.warning(f"Handshake timeout for {conn_info.client_ip}")
            log_access(conn_info.client_ip, "HANDSHAKE", "TIMEOUT")
            return None
        except Exception as e:
            logger.error(f"Handshake error for {conn_info.client_ip}: {e}")
            log_access(conn_info.client_ip, "HANDSHAKE", "ERROR", str(e))
            return None
    
    def _extract_dc_from_handshake(self, handshake: bytes) -> int:
        """Extract DC ID from handshake data"""
        # This is a simplified implementation
        # In practice, you might need more sophisticated DC detection
        
        # For now, randomly select DC based on client IP
        import hashlib
        hash_val = hashlib.md5(handshake[:16]).digest()[0]
        dc_id = (hash_val % 5) + 1
        
        logger.debug(f"Selected DC {dc_id} for client")
        return dc_id
    
    async def _connect_to_telegram(self, dc_id: int, conn_info: ConnectionInfo) -> Tuple[asyncio.StreamReader, asyncio.StreamWriter]:
        """Connect to Telegram data center"""
        
        if dc_id not in self.telegram_dcs:
            dc_id = 1  # Default to DC1
        
        telegram_host, telegram_port = self.telegram_dcs[dc_id]
        conn_info.server_ip = telegram_host
        conn_info.server_port = telegram_port
        
        try:
            logger.debug(f"Connecting to Telegram DC{dc_id}: {telegram_host}:{telegram_port}")
            
            telegram_reader, telegram_writer = await asyncio.wait_for(
                asyncio.open_connection(telegram_host, telegram_port),
                timeout=10.0
            )
            
            logger.info(f"Connected to Telegram DC{dc_id} for {conn_info.client_ip}")
            log_access(conn_info.client_ip, "TELEGRAM_CONNECT", "OK", f"dc{dc_id}={telegram_host}:{telegram_port}")
            
            return telegram_reader, telegram_writer
            
        except Exception as e:
            logger.error(f"Failed to connect to Telegram DC{dc_id}: {e}")
            log_access(conn_info.client_ip, "TELEGRAM_CONNECT", "FAILED", str(e))
            raise ProtocolError(f"Cannot connect to Telegram: {e}")
    
    async def _proxy_data(self, client_reader: asyncio.StreamReader, client_writer: asyncio.StreamWriter,
                         telegram_reader: asyncio.StreamReader, telegram_writer: asyncio.StreamWriter,
                         conn_info: ConnectionInfo):
        """Proxy data between client and Telegram"""
        
        async def forward_data(reader: asyncio.StreamReader, writer: asyncio.StreamWriter, 
                             direction: str, is_client_to_telegram: bool):
            """Forward data in one direction"""
            try:
                while True:
                    data = await reader.read(8192)
                    if not data:
                        break
                    
                    # Update connection statistics
                    if is_client_to_telegram:
                        conn_info.bytes_received += len(data)
                    else:
                        conn_info.bytes_sent += len(data)
                    
                    conn_info.last_activity = time.time()
                    
                    # Process data if needed (encryption/decryption)
                    processed_data = await self._process_data(data, conn_info, is_client_to_telegram)
                    
                    # Forward data
                    writer.write(processed_data)
                    await writer.drain()
                    
                    logger.debug(f"{direction}: forwarded {len(data)} bytes")
                    
            except Exception as e:
                logger.debug(f"{direction} forwarding stopped: {e}")
            finally:
                try:
                    writer.close()
                except Exception:
                    pass
        
        # Start bidirectional forwarding
        try:
            await asyncio.gather(
                forward_data(client_reader, telegram_writer, "Client->Telegram", True),
                forward_data(telegram_reader, client_writer, "Telegram->Client", False),
                return_exceptions=True
            )
        except Exception as e:
            logger.error(f"Data forwarding error: {e}")
    
    async def _process_data(self, data: bytes, conn_info: ConnectionInfo, is_client_to_telegram: bool) -> bytes:
        """Process data (decrypt/encrypt if needed)"""
        # In a full implementation, you might need to decrypt/encrypt data here
        # For now, we just pass through the data
        return data
    
    def get_connection_stats(self) -> Dict[str, Any]:
        """Get connection statistics"""
        current_time = time.time()
        active_connections = len(self.connections)
        
        total_bytes_sent = sum(conn.bytes_sent for conn in self.connections.values())
        total_bytes_received = sum(conn.bytes_received for conn in self.connections.values())
        
        # Calculate average connection duration
        durations = [current_time - conn.start_time for conn in self.connections.values()]
        avg_duration = sum(durations) / len(durations) if durations else 0
        
        return {
            'active_connections': active_connections,
            'total_bytes_sent': total_bytes_sent,
            'total_bytes_received': total_bytes_received,
            'average_duration': avg_duration,
            'connections': [
                {
                    'client': f"{conn.client_ip}:{conn.client_port}",
                    'server': f"{conn.server_ip}:{conn.server_port}",
                    'duration': current_time - conn.start_time,
                    'bytes_sent': conn.bytes_sent,
                    'bytes_received': conn.bytes_received,
                    'last_activity': current_time - conn.last_activity,
                }
                for conn in self.connections.values()
            ]
        }
    
    def close_connection(self, client_ip: str, client_port: int):
        """Close specific connection"""
        connection_id = f"{client_ip}:{client_port}"
        if connection_id in self.connections:
            del self.connections[connection_id]
            logger.info(f"Forced closure of connection: {connection_id}")
    
    def _load_official_config(self):
        """加载官方配置文件"""
        try:
            # 尝试读取proxy-multi.conf
            import os
            config_file = "config/proxy-multi.conf"
            if os.path.exists(config_file):
                with open(config_file, 'r') as f:
                    content = f.read()
                # 简化解析，提取DC配置
                for line in content.split('\n'):
                    if line.startswith('proxy_for '):
                        parts = line.split()
                        if len(parts) >= 3:
                            try:
                                dc_id = int(parts[1])
                                ip_port = parts[2].split(':')
                                if len(ip_port) == 2:
                                    ip, port = ip_port[0], int(ip_port[1])
                                    self.telegram_dcs[dc_id] = (ip, port)
                            except:
                                continue
                logger.info("已加载官方DC配置")
        except Exception as e:
            logger.debug(f"未找到官方配置文件: {e}")

    def close_all_connections(self):
        """Close all connections"""
        count = len(self.connections)
        self.connections.clear()
        logger.info(f"Closed {count} connections")


class MTProtoPacket:
    """MTProto packet structure"""
    
    def __init__(self, data: bytes):
        self.data = data
        self.length = len(data)
        self.auth_key_id = None
        self.msg_key = None
        self.encrypted_data = None
        
        if len(data) >= 24:
            self.auth_key_id = struct.unpack('<Q', data[:8])[0]
            self.msg_key = data[8:24]
            self.encrypted_data = data[24:]
    
    def is_valid(self) -> bool:
        """Check if packet is valid"""
        return (self.length >= 24 and 
                self.auth_key_id is not None and 
                self.msg_key is not None and 
                self.encrypted_data is not None)
    
    def decrypt(self, auth_key: bytes) -> Optional[bytes]:
        """Decrypt packet data"""
        if not self.is_valid():
            return None
        
        try:
            crypto = MTProtoCrypto("")
            
            # Create AES key and IV from auth_key and msg_key
            aes_key, aes_iv = TelegramCrypto.create_aes_key_iv(auth_key, self.msg_key)
            
            # Decrypt data
            decrypted = crypto.decrypt_aes_ige(self.encrypted_data, aes_key, aes_iv)
            
            return decrypted
            
        except Exception as e:
            logger.error(f"Packet decryption failed: {e}")
            return None
    
    def encrypt(self, auth_key: bytes, plaintext: bytes) -> bytes:
        """Encrypt packet data"""
        try:
            crypto = MTProtoCrypto("")
            
            # Pad plaintext
            padded_data = TelegramCrypto.pad_data(plaintext)
            
            # Create msg_key
            msg_key = TelegramCrypto.create_msg_key(auth_key, padded_data)
            
            # Create AES key and IV
            aes_key, aes_iv = TelegramCrypto.create_aes_key_iv(auth_key, msg_key)
            
            # Encrypt data
            encrypted = crypto.encrypt_aes_ige(padded_data, aes_key, aes_iv)
            
            # Build packet
            packet = struct.pack('<Q', self.auth_key_id) + msg_key + encrypted
            
            return packet
            
        except Exception as e:
            logger.error(f"Packet encryption failed: {e}")
            raise CryptoError(f"Encryption failed: {e}")


def validate_mtproto_packet(data: bytes) -> bool:
    """Validate MTProto packet structure"""
    if len(data) < 24:
        return False
    
    # Check for basic MTProto structure
    auth_key_id = struct.unpack('<Q', data[:8])[0]
    
    # Auth key ID should not be zero for encrypted messages
    return auth_key_id != 0


def extract_telegram_domain(data: bytes) -> Optional[str]:
    """Extract Telegram domain from TLS SNI"""
    try:
        # Look for SNI extension in TLS handshake
        if b'telegram' in data.lower():
            # Extract domain from SNI
            # This is a simplified implementation
            return "web.telegram.org"
    except Exception:
        pass
    
    return None
