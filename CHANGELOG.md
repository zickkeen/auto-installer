# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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