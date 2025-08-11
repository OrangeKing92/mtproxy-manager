"""
Tests for MTProxy cryptographic functions
"""

import pytest
import secrets

from mtproxy.crypto import (
    MTProtoCrypto, TelegramCrypto, ProxyAuth,
    generate_proxy_secret, validate_proxy_secret
)
from mtproxy.exceptions import CryptoError


class TestMTProtoCrypto:
    """Test MTProto cryptographic operations"""
    
    def test_initialization(self):
        """Test crypto initialization"""
        secret = generate_proxy_secret()
        crypto = MTProtoCrypto(secret)
        
        assert crypto.secret == bytes.fromhex(secret)
        assert len(crypto.secret) == 16
    
    def test_invalid_secret(self):
        """Test invalid secret handling"""
        with pytest.raises(CryptoError):
            MTProtoCrypto("invalid_secret")
        
        with pytest.raises(CryptoError):
            MTProtoCrypto("a" * 30)  # Wrong length
    
    def test_auth_key_creation(self):
        """Test authentication key creation"""
        secret = generate_proxy_secret()
        crypto = MTProtoCrypto(secret)
        
        client_nonce = secrets.token_bytes(16)
        server_nonce = secrets.token_bytes(16)
        
        auth_key, iv = crypto.create_auth_key(client_nonce, server_nonce)
        
        assert len(auth_key) == 32  # SHA256 output
        assert len(iv) == 16        # MD5 output
        assert auth_key != iv
    
    def test_invalid_nonce_length(self):
        """Test invalid nonce length handling"""
        secret = generate_proxy_secret()
        crypto = MTProtoCrypto(secret)
        
        with pytest.raises(CryptoError):
            crypto.create_auth_key(b"short", secrets.token_bytes(16))
        
        with pytest.raises(CryptoError):
            crypto.create_auth_key(secrets.token_bytes(16), b"short")
    
    def test_aes_ctr_encryption(self):
        """Test AES-CTR encryption/decryption"""
        secret = generate_proxy_secret()
        crypto = MTProtoCrypto(secret)
        
        key = secrets.token_bytes(32)
        iv = secrets.token_bytes(16)
        plaintext = b"Hello, World! This is a test message for AES-CTR."
        
        # Encrypt
        ciphertext = crypto.encrypt_aes_ctr(plaintext, key, iv)
        assert ciphertext != plaintext
        assert len(ciphertext) == len(plaintext)
        
        # Decrypt
        decrypted = crypto.decrypt_aes_ctr(ciphertext, key, iv)
        assert decrypted == plaintext
    
    def test_aes_ige_encryption(self):
        """Test AES-IGE encryption/decryption"""
        secret = generate_proxy_secret()
        crypto = MTProtoCrypto(secret)
        
        key = secrets.token_bytes(32)
        iv = secrets.token_bytes(32)  # IGE needs 32-byte IV
        plaintext = b"A" * 32  # Must be multiple of 16
        
        # Encrypt
        ciphertext = crypto.encrypt_aes_ige(plaintext, key, iv)
        assert ciphertext != plaintext
        assert len(ciphertext) == len(plaintext)
        
        # Decrypt
        decrypted = crypto.decrypt_aes_ige(ciphertext, key, iv)
        assert decrypted == plaintext
    
    def test_ige_invalid_input(self):
        """Test AES-IGE with invalid input"""
        secret = generate_proxy_secret()
        crypto = MTProtoCrypto(secret)
        
        key = secrets.token_bytes(32)
        iv = secrets.token_bytes(32)
        
        # Invalid data length (not multiple of 16)
        with pytest.raises(CryptoError):
            crypto.encrypt_aes_ige(b"invalid_length", key, iv)
        
        # Invalid key length
        with pytest.raises(CryptoError):
            crypto.encrypt_aes_ige(b"A" * 16, b"short_key", iv)
        
        # Invalid IV length
        with pytest.raises(CryptoError):
            crypto.encrypt_aes_ige(b"A" * 16, key, b"short_iv")


class TestTelegramCrypto:
    """Test Telegram-specific cryptographic functions"""
    
    def test_nonce_generation(self):
        """Test nonce generation"""
        nonce1 = TelegramCrypto.generate_nonce()
        nonce2 = TelegramCrypto.generate_nonce()
        
        assert len(nonce1) == 16
        assert len(nonce2) == 16
        assert nonce1 != nonce2  # Should be random
    
    def test_msg_key_creation(self):
        """Test message key creation"""
        auth_key = secrets.token_bytes(256)  # Typical auth_key size
        data = b"Test message data for msg_key calculation"
        
        msg_key_in = TelegramCrypto.create_msg_key(auth_key, data, incoming=True)
        msg_key_out = TelegramCrypto.create_msg_key(auth_key, data, incoming=False)
        
        assert len(msg_key_in) == 16
        assert len(msg_key_out) == 16
        assert msg_key_in != msg_key_out  # Should be different for incoming/outgoing
    
    def test_aes_key_iv_creation(self):
        """Test AES key and IV creation"""
        auth_key = secrets.token_bytes(256)
        msg_key = secrets.token_bytes(16)
        
        key_in, iv_in = TelegramCrypto.create_aes_key_iv(auth_key, msg_key, incoming=True)
        key_out, iv_out = TelegramCrypto.create_aes_key_iv(auth_key, msg_key, incoming=False)
        
        assert len(key_in) == 32
        assert len(iv_in) == 32
        assert len(key_out) == 32
        assert len(iv_out) == 32
        
        # Keys should be different for incoming/outgoing
        assert key_in != key_out
        assert iv_in != iv_out
    
    def test_data_padding(self):
        """Test data padding"""
        data = b"Test data"
        
        padded = TelegramCrypto.pad_data(data, block_size=16)
        
        assert len(padded) % 16 == 0
        assert len(padded) >= len(data)
        assert padded.startswith(data)
        
        # Test unpadding
        unpadded = TelegramCrypto.unpad_data(padded, len(data))
        assert unpadded == data


class TestProxyAuth:
    """Test proxy authentication"""
    
    def test_initialization(self):
        """Test proxy auth initialization"""
        secret = generate_proxy_secret()
        auth = ProxyAuth(secret)
        
        assert auth.secret_bytes == bytes.fromhex(secret)
    
    def test_handshake_validation(self):
        """Test handshake validation"""
        secret = generate_proxy_secret()
        auth = ProxyAuth(secret)
        
        # Valid handshake (64 bytes)
        valid_handshake = secrets.token_bytes(64)
        assert auth.validate_client_handshake(valid_handshake) == True
        
        # Invalid handshake (wrong length)
        invalid_handshake = secrets.token_bytes(32)
        assert auth.validate_client_handshake(invalid_handshake) == False


class TestUtilityFunctions:
    """Test utility cryptographic functions"""
    
    def test_secret_generation(self):
        """Test proxy secret generation"""
        secret1 = generate_proxy_secret()
        secret2 = generate_proxy_secret()
        
        assert len(secret1) == 32  # 16 bytes = 32 hex chars
        assert len(secret2) == 32
        assert secret1 != secret2  # Should be random
        
        # Should be valid hex
        bytes.fromhex(secret1)  # Should not raise
        bytes.fromhex(secret2)  # Should not raise
    
    def test_secret_validation(self):
        """Test proxy secret validation"""
        # Valid secrets
        valid_secret = generate_proxy_secret()
        assert validate_proxy_secret(valid_secret) == True
        
        # Invalid secrets
        assert validate_proxy_secret("") == False
        assert validate_proxy_secret("too_short") == False
        assert validate_proxy_secret("a" * 31) == False  # Too short
        assert validate_proxy_secret("a" * 33) == False  # Too long
        assert validate_proxy_secret("x" * 32) == False  # Invalid hex
        assert validate_proxy_secret(None) == False
