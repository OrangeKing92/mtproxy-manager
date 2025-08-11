"""
Custom exceptions for MTProxy
"""


class MTProxyError(Exception):
    """Base exception for MTProxy errors"""
    pass


class ConfigError(MTProxyError):
    """Configuration related errors"""
    pass


class CryptoError(MTProxyError):
    """Cryptography related errors"""
    pass


class ProtocolError(MTProxyError):
    """Protocol handling errors"""
    pass


class ConnectionError(MTProxyError):
    """Connection related errors"""
    pass


class AuthenticationError(MTProxyError):
    """Authentication errors"""
    pass


class ServerError(MTProxyError):
    """Server operation errors"""
    pass


class ValidationError(MTProxyError):
    """Input validation errors"""
    pass
