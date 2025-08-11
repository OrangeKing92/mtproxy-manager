"""
Cryptographic functions for MTProxy
"""

import os
import struct
import hashlib
import secrets
from typing import Tuple, Optional
from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes
from cryptography.hazmat.backends import default_backend
from Crypto.Cipher import AES

from .exceptions import CryptoError
from .logger import get_logger

logger = get_logger(__name__)


class MTProtoCrypto:
    """MTProto cryptographic operations"""
    
    def __init__(self, secret: str):
        """Initialize with secret"""
        self.secret = bytes.fromhex(secret)
        if len(self.secret) != 16:
            raise CryptoError(f"Invalid secret length: {len(self.secret)}, expected 16")
        
        logger.debug("MTProtoCrypto initialized")
    
    def create_auth_key(self, client_nonce: bytes, server_nonce: bytes) -> Tuple[bytes, bytes]:
        """Create authentication key and IV"""
        if len(client_nonce) != 16 or len(server_nonce) != 16:
            raise CryptoError("Invalid nonce length")
        
        # Combine nonces and secret
        data = client_nonce + server_nonce + self.secret
        
        # Generate auth key using SHA256
        auth_key = hashlib.sha256(data).digest()
        
        # Generate IV
        iv_data = server_nonce + client_nonce + self.secret[:8]
        iv = hashlib.md5(iv_data).digest()
        
        logger.debug("Authentication key and IV created")
        return auth_key, iv
    
    def encrypt_aes_ctr(self, data: bytes, key: bytes, iv: bytes) -> bytes:
        """Encrypt data using AES-CTR mode"""
        try:
            cipher = Cipher(
                algorithms.AES(key[:32]),
                modes.CTR(iv[:16]),
                backend=default_backend()
            )
            encryptor = cipher.encryptor()
            return encryptor.update(data) + encryptor.finalize()
        except Exception as e:
            raise CryptoError(f"AES-CTR encryption failed: {e}")
    
    def decrypt_aes_ctr(self, data: bytes, key: bytes, iv: bytes) -> bytes:
        """Decrypt data using AES-CTR mode"""
        try:
            cipher = Cipher(
                algorithms.AES(key[:32]),
                modes.CTR(iv[:16]),
                backend=default_backend()
            )
            decryptor = cipher.decryptor()
            return decryptor.update(data) + decryptor.finalize()
        except Exception as e:
            raise CryptoError(f"AES-CTR decryption failed: {e}")
    
    def encrypt_aes_ige(self, data: bytes, key: bytes, iv: bytes) -> bytes:
        """Encrypt data using AES-IGE mode (MTProto specific)"""
        # IGE mode implementation for MTProto
        if len(data) % 16 != 0:
            raise CryptoError("Data length must be multiple of 16 for IGE")
        
        if len(key) < 32:
            raise CryptoError("Key length must be at least 32 bytes for IGE")
        
        if len(iv) < 32:
            raise CryptoError("IV length must be at least 32 bytes for IGE")
        
        try:
            aes_key = key[:32]
            iv1 = iv[:16]
            iv2 = iv[16:32]
            
            encrypted = bytearray()
            
            for i in range(0, len(data), 16):
                block = data[i:i+16]
                
                # XOR with previous ciphertext (or IV)
                xor_block = bytes(a ^ b for a, b in zip(block, iv1))
                
                # AES encrypt
                cipher = AES.new(aes_key, AES.MODE_ECB)
                enc_block = cipher.encrypt(xor_block)
                
                # XOR with previous plaintext (or IV)
                result_block = bytes(a ^ b for a, b in zip(enc_block, iv2))
                
                encrypted.extend(result_block)
                
                # Update IVs
                iv1 = result_block
                iv2 = block
            
            return bytes(encrypted)
            
        except Exception as e:
            raise CryptoError(f"AES-IGE encryption failed: {e}")
    
    def decrypt_aes_ige(self, data: bytes, key: bytes, iv: bytes) -> bytes:
        """Decrypt data using AES-IGE mode (MTProto specific)"""
        if len(data) % 16 != 0:
            raise CryptoError("Data length must be multiple of 16 for IGE")
        
        if len(key) < 32:
            raise CryptoError("Key length must be at least 32 bytes for IGE")
        
        if len(iv) < 32:
            raise CryptoError("IV length must be at least 32 bytes for IGE")
        
        try:
            aes_key = key[:32]
            iv1 = iv[:16]
            iv2 = iv[16:32]
            
            decrypted = bytearray()
            
            for i in range(0, len(data), 16):
                block = data[i:i+16]
                
                # XOR with previous plaintext (or IV)
                xor_block = bytes(a ^ b for a, b in zip(block, iv2))
                
                # AES decrypt
                cipher = AES.new(aes_key, AES.MODE_ECB)
                dec_block = cipher.decrypt(xor_block)
                
                # XOR with previous ciphertext (or IV)
                result_block = bytes(a ^ b for a, b in zip(dec_block, iv1))
                
                decrypted.extend(result_block)
                
                # Update IVs
                iv2 = result_block
                iv1 = block
            
            return bytes(decrypted)
            
        except Exception as e:
            raise CryptoError(f"AES-IGE decryption failed: {e}")
    
    def generate_random_bytes(self, length: int) -> bytes:
        """Generate cryptographically secure random bytes"""
        return secrets.token_bytes(length)
    
    def calculate_sha1(self, data: bytes) -> bytes:
        """Calculate SHA1 hash"""
        return hashlib.sha1(data).digest()
    
    def calculate_sha256(self, data: bytes) -> bytes:
        """Calculate SHA256 hash"""
        return hashlib.sha256(data).digest()
    
    def calculate_md5(self, data: bytes) -> bytes:
        """Calculate MD5 hash"""
        return hashlib.md5(data).digest()


class TelegramCrypto:
    """Telegram-specific cryptographic operations"""
    
    @staticmethod
    def generate_nonce() -> bytes:
        """Generate 16-byte nonce"""
        return secrets.token_bytes(16)
    
    @staticmethod
    def generate_server_nonce() -> bytes:
        """Generate 16-byte server nonce"""
        return secrets.token_bytes(16)
    
    @staticmethod
    def create_msg_key(auth_key: bytes, data: bytes, incoming: bool = True) -> bytes:
        """Create message key for MTProto 2.0"""
        # MTProto 2.0 msg_key calculation
        x = 0 if incoming else 8
        
        # Take slice of auth_key
        auth_key_slice = auth_key[88+x:88+x+32]
        
        # Create hash input
        hash_input = auth_key_slice + data
        
        # Calculate SHA256
        sha256_hash = hashlib.sha256(hash_input).digest()
        
        # Take first 16 bytes as msg_key
        return sha256_hash[:16]
    
    @staticmethod
    def create_aes_key_iv(auth_key: bytes, msg_key: bytes, incoming: bool = True) -> Tuple[bytes, bytes]:
        """Create AES key and IV from auth_key and msg_key for MTProto 2.0"""
        x = 0 if incoming else 8
        
        # Create hash inputs
        sha256_a_input = msg_key + auth_key[x:x+36]
        sha256_b_input = auth_key[x+40:x+76] + msg_key
        
        # Calculate hashes
        sha256_a = hashlib.sha256(sha256_a_input).digest()
        sha256_b = hashlib.sha256(sha256_b_input).digest()
        
        # Create key and IV
        aes_key = sha256_a[:8] + sha256_b[8:24] + sha256_a[24:32]
        aes_iv = sha256_b[:8] + sha256_a[8:24] + sha256_b[24:32]
        
        return aes_key, aes_iv
    
    @staticmethod
    def pad_data(data: bytes, block_size: int = 16) -> bytes:
        """Pad data to block size using random padding"""
        padding_length = block_size - (len(data) % block_size)
        if padding_length == 0:
            padding_length = block_size
        
        # Random padding
        padding = secrets.token_bytes(padding_length)
        return data + padding
    
    @staticmethod
    def unpad_data(data: bytes, original_length: int) -> bytes:
        """Remove padding from data"""
        return data[:original_length]


class ProxyAuth:
    """Proxy authentication and handshake"""
    
    def __init__(self, secret: str):
        self.crypto = MTProtoCrypto(secret)
        self.secret_bytes = bytes.fromhex(secret)
    
    def create_handshake_response(self, client_handshake: bytes) -> Tuple[bytes, bytes, bytes]:
        """Create handshake response"""
        if len(client_handshake) < 64:
            raise CryptoError("Invalid client handshake length")
        
        # Extract client data
        # First 56 bytes contain encrypted data, last 8 bytes are ignored
        encrypted_data = client_handshake[:56]
        
        # Generate server nonce
        server_nonce = TelegramCrypto.generate_server_nonce()
        
        # Create decryption key from first 48 bytes
        dec_key = encrypted_data[:32]
        dec_iv = encrypted_data[32:48]
        
        # Generate response
        response_data = server_nonce + self.secret_bytes
        
        # Encrypt response
        response_key = self.crypto.calculate_sha256(response_data)[:32]
        response_iv = self.crypto.calculate_sha256(response_data[16:])[:16]
        
        # Create encrypted response
        encrypted_response = self.crypto.encrypt_aes_ctr(response_data, response_key, response_iv)
        
        # Create auth key and IV for future communication
        client_nonce = encrypted_data[8:24]  # Extract from handshake
        auth_key, comm_iv = self.crypto.create_auth_key(client_nonce, server_nonce)
        
        logger.debug("Handshake response created")
        return encrypted_response, auth_key, comm_iv
    
    def validate_client_handshake(self, handshake: bytes) -> bool:
        """Validate client handshake format"""
        if len(handshake) != 64:
            return False
        
        # Basic validation - check if it looks like encrypted data
        # In a real implementation, you'd do more thorough validation
        return True


def generate_proxy_secret() -> str:
    """Generate a new proxy secret"""
    return secrets.token_hex(16)


def validate_proxy_secret(secret: str) -> bool:
    """Validate proxy secret format"""
    try:
        if not secret or len(secret) != 32:
            return False
        
        # Try to decode as hex
        bytes.fromhex(secret)
        return True
    except ValueError:
        return False


def create_fake_tls_handshake(domain: str = "www.google.com") -> bytes:
    """Create fake TLS handshake for obfuscation"""
    # This is a simplified version - in production, you'd want a more sophisticated implementation
    tls_version = b'\x03\x03'  # TLS 1.2
    random_data = secrets.token_bytes(32)
    session_id = secrets.token_bytes(32)
    
    # Build basic TLS Client Hello structure
    handshake = b'\x16'  # Handshake
    handshake += tls_version
    handshake += struct.pack('>H', 0)  # Length placeholder
    handshake += b'\x01'  # Client Hello
    handshake += struct.pack('>I', 0)[1:]  # Length placeholder
    handshake += tls_version
    handshake += random_data
    handshake += struct.pack('B', len(session_id)) + session_id
    
    # Add domain as SNI
    domain_bytes = domain.encode('utf-8')
    sni_extension = struct.pack('>H', 0) + struct.pack('>H', len(domain_bytes) + 5)
    sni_extension += struct.pack('>H', len(domain_bytes) + 3)
    sni_extension += b'\x00' + struct.pack('>H', len(domain_bytes)) + domain_bytes
    
    handshake += sni_extension
    
    return handshake


def obfuscate_data(data: bytes, key: bytes) -> bytes:
    """Simple data obfuscation"""
    key_cycle = (key * ((len(data) // len(key)) + 1))[:len(data)]
    return bytes(a ^ b for a, b in zip(data, key_cycle))
