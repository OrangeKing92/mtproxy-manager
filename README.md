# Python MTProxy

A modern, feature-rich Python implementation of MTProxy for Telegram with comprehensive SSH remote management capabilities.

## Features

🚀 **Easy Deployment**
- One-click deployment script for Debian/Ubuntu
- Automatic systemd service configuration
- Comprehensive health monitoring

🛠️ **SSH Remote Management**
- Complete command-line interface
- Real-time log viewing and analysis
- Remote configuration editing
- Health checking and diagnostics

🔧 **Production Ready**
- Systemd integration with auto-restart
- Log rotation and cleanup
- Security hardening
- Performance monitoring

🔐 **Security Features**
- IP-based access control
- Rate limiting
- Connection monitoring
- Secure configuration management

## Quick Start

### 1. Clone and Deploy

```bash
# Clone the repository
git clone https://github.com/your-repo/python-mtproxy.git
cd python-mtproxy

# One-click deployment (requires sudo)
sudo ./scripts/deploy.sh
```

### 2. SSH Remote Management

After deployment, you can manage the service remotely via SSH:

```bash
# Check status
ssh user@server "mtproxy-cli status"

# View logs in real-time
ssh user@server "mtproxy-logs --follow"

# Restart service
ssh user@server "mtproxy-cli restart"

# Health check
ssh user@server "mtproxy-health"
```

### 3. Local Management

On the server, you can use these commands:

```bash
# Service control
mtproxy-cli start|stop|restart|status

# Configuration
mtproxy-cli config show
mtproxy-cli config edit

# Monitoring
mtproxy-cli health
mtproxy-cli stats

# Logs
mtproxy-logs --follow
mtproxy-logs --level ERROR
mtproxy-logs --search "connection"
```

## Installation Options

### Production Deployment
```bash
sudo ./scripts/deploy.sh --production
```

### Development Deployment
```bash
sudo ./scripts/deploy.sh --development
```

### Update Existing Installation
```bash
sudo ./scripts/deploy.sh --update
```

### Uninstall
```bash
sudo ./scripts/uninstall.sh
```

## Configuration

The main configuration file is located at `/opt/python-mtproxy/config/mtproxy.conf`:

```yaml
server:
  host: 0.0.0.0
  port: 8443
  secret: your_32_char_secret
  max_connections: 1000
  timeout: 300

logging:
  level: INFO
  file: /opt/python-mtproxy/logs/mtproxy.log
  max_size: 100MB
  backup_count: 7

security:
  allowed_ips: []
  banned_ips: []
  rate_limit: 100
```

### Environment Variables

You can override configuration using environment variables:

```bash
export MTPROXY_PORT=8443
export MTPROXY_SECRET=your_secret
export LOG_LEVEL=DEBUG
```

## SSH Management Tools

### Main CLI Tool (`mtproxy-cli`)

```bash
# Service management
mtproxy-cli start
mtproxy-cli stop
mtproxy-cli restart
mtproxy-cli status

# Configuration
mtproxy-cli config show
mtproxy-cli config edit

# Monitoring
mtproxy-cli health
mtproxy-cli stats
```

### Log Viewer (`mtproxy-logs`)

```bash
# Follow logs in real-time
mtproxy-logs --follow

# View last 100 lines
mtproxy-logs --lines 100

# Filter by log level
mtproxy-logs --level ERROR

# Search for patterns
mtproxy-logs --search "connection error"

# View logs from specific date
mtproxy-logs --date today
mtproxy-logs --date 2024-01-15
```

### Health Checker (`mtproxy-health`)

```bash
# Full health check
mtproxy-health

# Network connectivity only
mtproxy-health --network

# Performance check only
mtproxy-health --performance

# JSON output
mtproxy-health --json
```

## Directory Structure

```
/opt/python-mtproxy/
├── mtproxy/              # Core application code
├── tools/                # Management tools
├── config/               # Configuration files
├── logs/                 # Log files
├── scripts/              # Deployment scripts
└── venv/                 # Python virtual environment
```

## Service Management

### Systemd Service

The service is installed as `python-mtproxy.service`:

```bash
# Standard systemd commands
sudo systemctl start python-mtproxy
sudo systemctl stop python-mtproxy
sudo systemctl restart python-mtproxy
sudo systemctl status python-mtproxy

# Auto-start on boot
sudo systemctl enable python-mtproxy
sudo systemctl disable python-mtproxy
```

### Log Files

- **Main log**: `/opt/python-mtproxy/logs/mtproxy.log`
- **Error log**: `/opt/python-mtproxy/logs/mtproxy-error.log`
- **Access log**: `/opt/python-mtproxy/logs/mtproxy-access.log`

Logs are automatically rotated daily and compressed.

## Monitoring and Diagnostics

### Health Monitoring

The built-in health checker monitors:
- Service status
- Process health
- Port availability
- Configuration validity
- System resources
- Network connectivity
- Log file activity

### Statistics

Get detailed statistics:

```bash
mtproxy-cli stats
```

This shows:
- Active connections
- Bandwidth usage
- Uptime
- Error rates
- Client information

### Performance Monitoring

Monitor system performance:

```bash
# Resource usage
mtproxy-health --performance

# Process information
ps aux | grep mtproxy

# Network connections
netstat -tlnp | grep 8443
```

## Security

### Access Control

Configure IP-based access control in `mtproxy.conf`:

```yaml
security:
  # Allow only specific IPs
  allowed_ips:
    - "192.168.1.0/24"
    - "10.0.0.1"
  
  # Block specific IPs
  banned_ips:
    - "1.2.3.4"
    - "5.6.7.8"
  
  # Rate limiting
  rate_limit: 100
  max_connections_per_ip: 10
```

### Firewall Configuration

The deployment script automatically configures UFW:

```bash
# Check firewall status
sudo ufw status

# Manually configure if needed
sudo ufw allow 8443/tcp
sudo ufw allow ssh
```

### SSL/TLS

For additional security, consider running behind a reverse proxy with SSL:

```nginx
server {
    listen 443 ssl;
    server_name your-domain.com;
    
    ssl_certificate /path/to/cert.pem;
    ssl_certificate_key /path/to/key.pem;
    
    location / {
        proxy_pass http://127.0.0.1:8443;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

## Troubleshooting

### Common Issues

1. **Service won't start**
   ```bash
   # Check logs
   mtproxy-logs --level ERROR
   journalctl -u python-mtproxy -f
   
   # Check configuration
   mtproxy-cli config show
   
   # Validate config
   python3 -m mtproxy.config --validate
   ```

2. **Port binding issues**
   ```bash
   # Check if port is in use
   netstat -tlnp | grep 8443
   
   # Check firewall
   sudo ufw status
   
   # Test port connectivity
   nc -zv localhost 8443
   ```

3. **Permission issues**
   ```bash
   # Check file permissions
   ls -la /opt/python-mtproxy/
   
   # Fix permissions
   sudo chown -R mtproxy:mtproxy /opt/python-mtproxy/
   ```

4. **High resource usage**
   ```bash
   # Check system resources
   mtproxy-health --performance
   
   # Monitor process
   top -p $(pgrep -f mtproxy)
   
   # Check connections
   mtproxy-cli stats
   ```

### Getting Help

1. **Check logs first**:
   ```bash
   mtproxy-logs --follow
   mtproxy-logs --level ERROR
   ```

2. **Run health check**:
   ```bash
   mtproxy-health
   ```

3. **Verify configuration**:
   ```bash
   mtproxy-cli config show
   ```

4. **Check system status**:
   ```bash
   mtproxy-cli status
   systemctl status python-mtproxy
   ```

## Development

### Local Development

```bash
# Clone repository
git clone https://github.com/your-repo/python-mtproxy.git
cd python-mtproxy

# Create virtual environment
python3 -m venv venv
source venv/bin/activate

# Install dependencies
pip install -r requirements.txt
pip install -r requirements-dev.txt

# Install in development mode
pip install -e .

# Run tests
pytest tests/

# Run linting
flake8 mtproxy/ tools/ tests/
black mtproxy/ tools/ tests/
```

### Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Run the test suite
6. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Telegram Connection

After successful deployment, you'll get connection information:

```
Server: YOUR_SERVER_IP
Port: 8443
Secret: your_generated_secret

Telegram Link:
tg://proxy?server=YOUR_SERVER_IP&port=8443&secret=your_generated_secret
```

Use this link in Telegram to connect through your proxy.

## Support

- **Documentation**: Check this README and inline code documentation
- **Issues**: Report bugs and request features on GitHub
- **Logs**: Always check logs first for troubleshooting
- **Health Check**: Use `mtproxy-health` for system diagnostics
