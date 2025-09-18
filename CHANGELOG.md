# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [v1.1.0] - 2025-01-10

### Added
- **OpenSIPS Installer**: Comprehensive SIP proxy server installation script
  - OpenSIPS 3.6.x LTS (latest stable) installation from official repositories
  - Official OpenSIPS APT/YUM repositories (apt.opensips.org / yum.opensips.org)
  - Best practice configuration with security, performance, and reliability optimizations
  - Database integration (MySQL/MariaDB and PostgreSQL support)
  - Load balancing and dispatcher modules
  - NAT traversal and RTP proxy support
  - HTTP MI interface for management and monitoring
  - Optional OpenSIPS Control Panel web interface
  - Support for Debian/Ubuntu and RedHat-based distributions
  - Comprehensive documentation (OPENSIPS_README.md)
- **Documentation Enhancement**: Added detailed OpenSIPS documentation
  - Installation guides and configuration options
  - Best practices and security considerations
  - Troubleshooting and performance tuning
  - Monitoring and management instructions

### Technical Details
- OpenSIPS configuration includes authentication, permissions, and DoS protection
- Database schema initialization with opensipsdbctl
- Firewall configuration for SIP and RTP ports
- Service management with systemd integration
- Official OpenSIPS repositories for Debian/Ubuntu (apt.opensips.org) and RedHat (yum.opensips.org)
- Comprehensive error handling and validation

## [v1.0.0] - 2025-09-18

### Added
- Initial release of Auto Installer project
- **Code Server Installer**: Automated installation script for VS Code Server with reverse proxy support
  - Support for Nginx + Certbot method
  - Support for Cloudflare Tunnel method
  - Ubuntu 22.04 compatibility
- **PostgreSQL Installer**: Comprehensive PostgreSQL installation and configuration script
  - Support for Debian/Ubuntu and RedHat-based distributions
  - Initial database setup options (--setup-db)
  - User and database creation capabilities
- **GitHub Actions Workflow**: Automated contributor list updates
  - Daily scheduled updates
  - Push-triggered updates
  - Proper authentication using GITHUB_TOKEN
- **Documentation**: Complete README with usage examples and contribution guidelines
  - English and Indonesian versions
  - Direct download instructions using curl
  - Comprehensive help and examples

### Technical Details
- Scripts follow consistent naming convention: `{application}-installer.sh`
- Error handling with `set -e` in all scripts
- Argument validation and `--help` support
- YAML-compliant GitHub Actions workflow
- Automated testing and validation

### Infrastructure
- GitHub repository setup with proper structure
- Workflow automation for contributor management
- Badge integration and repository links
- Open-source licensing (MIT)