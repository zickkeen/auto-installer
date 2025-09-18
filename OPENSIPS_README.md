# OpenSIPS Installer Documentation

## Overview

OpenSIPS is a mature Open Source implementation of a SIP Server. OpenSIPS is more than a SIP proxy/router as it includes application-level functionalities. OpenSIPS, as a SIP server, is the core component of any SIP-based VoIP solution.

This installer provides automated installation of OpenSIPS stable version with best practice configuration for production use.

## Features

## Features

- **Latest Stable Version**: Installs OpenSIPS 3.5.x (current stable release)
- **Best Practice Config**: Pre-configured with industry standard settings
- **Database Integration**: MySQL/MariaDB support with automatic schema setup
- **Security**: Proper authentication, permissions, and firewall rules
- **Load Balancing**: Built-in dispatcher and load balancer modules
- **NAT Traversal**: RTP proxy and NAT helper support
- **Monitoring**: HTTP MI interface for management and monitoring
- **Web Interface**: Optional OpenSIPS Control Panel installation

## Supported Versions

This installer supports the latest OpenSIPS stable releases:

- **3.6.1** - Latest stable release (recommended)
- **3.5.7** - Previous stable release
- **3.4.14** - LTS release (long-term support)

The installer automatically installs the latest available version from the 3.6.x series.

### Supported Operating Systems
- **Debian/Ubuntu**: 20.04, 22.04, 24.04
- **RedHat/CentOS/RHEL**: 7, 8, 9
- **AlmaLinux/Rocky Linux**: 8, 9

### Hardware Requirements
- **RAM**: Minimum 512MB, Recommended 1GB+
- **CPU**: 1 core minimum, 2+ cores recommended
- **Storage**: 2GB free space
- **Network**: Stable internet connection for package downloads

### Software Dependencies
- MySQL/MariaDB 5.7+ or PostgreSQL 12+
- PHP 7.4+ (for web interface)
- Apache/Nginx (for web interface)

## Installation

### Basic Installation

```bash
# Download and run installer
curl -fsSL https://raw.githubusercontent.com/zickkeen/auto-installer/main/opensips-installer.sh | bash -s -- --db-pass your_password

# Or run locally
bash opensips-installer.sh --db-pass your_password
```

### Advanced Installation

```bash
# Full installation with web interface
bash opensips-installer.sh \
  --db-pass your_password \
  --sip-domain yourdomain.com \
  --with-web

# Custom database settings
bash opensips-installer.sh \
  --db-pass your_password \
  --db-engine mysql \
  --sip-domain sip.yourdomain.com
```

## Configuration Options

| Option | Description | Default | Required |
|--------|-------------|---------|----------|
| `--db-pass` | Database password for OpenSIPS user | - | Yes |
| `--sip-domain` | SIP domain for the server | - | No |
| `--db-engine` | Database engine (mysql/postgres) | mysql | No |
| `--no-db` | Skip database setup | false | No |
| `--with-web` | Install web control panel | false | No |
| `--help` | Show help message | - | No |

## Post-Installation Configuration

### 1. Verify Installation

```bash
# Check service status
sudo systemctl status opensips

# Check SIP port
netstat -tlnp | grep :5060

# Check MI interface
curl http://localhost:8888/mi
```

### 2. Add SIP Users

#### Via MI Interface
```bash
# Connect to MI interface
opensips-cli -x mi

# Add subscriber
mi subscriber_add username password@example.com

# List subscribers
mi subscriber_list
```

#### Via Database
```bash
mysql -u opensips -p opensips

INSERT INTO subscriber (username, domain, password, ha1, ha1b)
VALUES ('user1', 'example.com', 'password123', MD5('user1:example.com:password123'), MD5('user1@example.com:example.com:password123'));
```

### 3. Configure SIP Clients

Configure your SIP clients/softphones with:
- **Server**: Your server IP or domain
- **Port**: 5060 (UDP/TCP)
- **Username**: Created user
- **Password**: User password
- **Domain**: Your SIP domain

### 4. Load Balancing (Optional)

Add destination servers to dispatcher:

```bash
# Via MI interface
opensips-cli -x mi dispatcher_add 1 sip:192.168.1.100:5060 0 1 '' 'weight=50'
opensips-cli -x mi dispatcher_add 1 sip:192.168.1.101:5060 0 1 '' 'weight=50'
```

## Best Practice Configuration

The installer includes the following best practices:

### Security
- Authentication enabled for all requests
- Permissions module for access control
- PIKE module for DoS protection
- Proper firewall configuration

### Performance
- Optimized database connections
- Connection pooling
- Memory-efficient configuration
- Multi-core support

### Reliability
- Database-backed user location
- Transaction management
- Proper error handling
- Logging configuration

### Scalability
- Dispatcher module for load balancing
- Load balancer module for advanced routing
- RTP proxy for media handling
- NAT traversal support

## Monitoring and Management

### MI (Management Interface)

Access via HTTP on port 8888:
```bash
# Get server info
curl "http://localhost:8888/mi/get_statistics"

# Reload configuration
curl "http://localhost:8888/mi/reload_config"
```

### Command Line Tools

```bash
# OpenSIPS CLI
opensips-cli

# Check configuration
opensips -c /etc/opensips/opensips.cfg

# View logs
tail -f /var/log/opensips/opensips.log
```

### Web Interface (if installed)

Access at: `http://your-server/opensips-cp`

Features:
- User management
- Route management
- Statistics monitoring
- Configuration editing

## Troubleshooting

### Common Issues

#### 1. Service won't start
```bash
# Check configuration
opensips -c /etc/opensips/opensips.cfg

# Check logs
journalctl -u opensips -f

# Check database connection
mysql -u opensips -p -e "SELECT 1"
```

#### 2. SIP registration fails
- Verify user credentials in database
- Check domain configuration
- Ensure proper network connectivity

#### 3. No audio in calls
- Configure RTP proxy
- Check NAT settings
- Verify firewall rules for RTP ports

### Log Files

- **Main log**: `/var/log/opensips/opensips.log`
- **System log**: `journalctl -u opensips`
- **MI log**: `/var/log/opensips/mi.log`

### Useful Commands

```bash
# Restart service
sudo systemctl restart opensips

# Reload configuration
sudo systemctl reload opensips

# View active calls
opensips-cli -x mi dlg_list

# View registered users
opensips-cli -x mi ul_dump
```

## Backup and Recovery

### Database Backup
```bash
mysqldump -u opensips -p opensips > opensips_backup.sql
```

### Configuration Backup
```bash
cp /etc/opensips/opensips.cfg /etc/opensips/opensips.cfg.backup
```

### Full Backup
```bash
# Stop service
sudo systemctl stop opensips

# Backup database and config
tar -czf opensips_backup.tar.gz /etc/opensips /var/lib/mysql/opensips

# Start service
sudo systemctl start opensips
```

## Security Considerations

### Network Security
- Use firewall to restrict access to SIP ports
- Implement VPN for remote management
- Use TLS for encrypted SIP signaling

### Access Control
- Implement proper user authentication
- Use permissions module for IP-based access
- Regular password updates

### Monitoring
- Monitor for unusual activity
- Implement rate limiting
- Regular security updates

## Performance Tuning

### Memory Optimization
```bash
# Adjust shared memory (in opensips.cfg)
shared_memory_size = 128  # MB
```

### Database Optimization
```bash
# MySQL tuning
innodb_buffer_pool_size = 256M
max_connections = 200
```

### CPU Optimization
```bash
# Increase worker processes
children = 8  # Adjust based on CPU cores
```

## Support and Resources

### Official Documentation
- [OpenSIPS Documentation](https://opensips.org/Documentation/)
- [OpenSIPS Wiki](https://opensips.org/wiki/)
- [OpenSIPS Forums](https://opensips.org/forums/)

### Community Resources
- [OpenSIPS GitHub](https://github.com/OpenSIPS/opensips)
- [OpenSIPS Mailing Lists](https://opensips.org/Support/MailingLists)

### Commercial Support
- [OpenSIPS Solutions](https://opensips.org/Support/Commercial-Support)

## Changelog

### v1.0.0
- Initial release
- OpenSIPS 3.4 LTS installation
- Best practice configuration
- Database integration
- Web interface support
- Comprehensive documentation