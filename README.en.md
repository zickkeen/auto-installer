# Auto Installer

[![GitHub]### Code Server
```bash
# Install with Nginx + Certbot (local)
bash code_server-installer.sh --domain example.com --password mypass --method nginx

# Install with Cloudflare Tunnel (local)
bash code_server-installer.sh --domain example.com --password mypass --method cloudflared

# Install direct without reverse proxy (not secure, for testing only)
bash code_server-installer.sh --password mypass --method direct

# Install with custom port
bash code_server-installer.sh --domain example.com --password mypass --method nginx --port 9090
bash code_server-installer.sh --password mypass --method direct --port 3000

# Or download and run directly from GitHub
curl -fsSL https://raw.githubusercontent.com/zickkeen/auto-installer/main/code_server-installer.sh | bash -s -- --domain example.com --password mypass --method nginx
```/img.shields.io/badge/GitHub-zickkeen/auto--installer-blue)](https://github.com/zickkeen/auto-installer)

A collection of automated installer scripts for various open-source applications and services. This project aims to simplify the installation and initial configuration of popular applications on Linux (Debian/Ubuntu and RedHat-based).

**Repository**: [https://github.com/zickkeen/auto-installer](https://github.com/zickkeen/auto-installer)

## 📋 Changelog

See [CHANGELOG.md](CHANGELOG.md) for detailed changes [(view changes)](https://github.com/zickkeen/auto-installer/blob/main/CHANGELOG.md)

## 🚀 Features

- **Code Server Installer**: Installs VS Code Server with a reverse proxy (Nginx + Certbot or Cloudflare Tunnel) or direct access
- **PostgreSQL Installer**: Installs and configures PostgreSQL with an option for initial database setup

## 📦 Available Scripts

| Script | Description | OS Support |
|--------|-----------|------------|
| `code_server-installer.sh` | Installs Code Server with a reverse proxy | Ubuntu/Debian, AlmaLinux/Rocky |
| `postgresql-installer.sh` | Installs PostgreSQL with initial configuration | Debian/Ubuntu, RedHat-based |

## 🛠️ Usage

### Code Server
```bash
# Install with Nginx + Certbot (local)
bash code_server-installer.sh --domain example.com --password mypass --method nginx

# Install with Cloudflare Tunnel (local)
bash code_server-installer.sh --domain example.com --password mypass --method cloudflared

# Or download and run directly from GitHub
curl -fsSL [https://raw.githubusercontent.com/zickkeen/auto-installer/main/code_server-installer.sh](https://raw.githubusercontent.com/zickkeen/auto-installer/main/code_server-installer.sh) | bash -s -- --domain example.com --password mypass --method nginx
````

### PostgreSQL

```bash
# Basic installation (local)
bash postgresql-installer.sh --pg-version 15

# Installation with initial setup (local)
bash postgresql-installer.sh --pg-version 14 --setup-db --db-name mydb --db-user myuser --db-pass mypass

# Or download and run directly from GitHub
curl -fsSL [https://raw.githubusercontent.com/zickkeen/auto-installer/main/postgresql-installer.sh](https://raw.githubusercontent.com/zickkeen/auto-installer/main/postgresql-installer.sh) | bash -s -- --pg-version 15 --setup-db --db-name mydb --db-user myuser --db-pass mypass
```

Use the `--help` flag on any script for complete guidance.

## 🤝 Contributing

This project is open-source and contributions are welcome\! We appreciate contributions in the form of:

  - Adding new installers for other applications
  - Fixing bugs or improving existing features
  - Improving documentation
  - Adding support for new OS versions

### How to Contribute

1.  **Fork** this repository: [https://github.com/zickkeen/auto-installer](https://github.com/zickkeen/auto-installer)
2.  **Clone** your fork: `git clone https://github.com/your-username/auto-installer.git`
3.  **Create a new branch**: `git checkout -b feature/feature-name`
4.  **Make your changes** and commit: `git commit -m "Add feature X"`
5.  **Push** to your branch: `git push origin feature/feature-name`
6.  **Create a Pull Request** on GitHub

### Contribution Guidelines

  - Ensure scripts use `set -e` for robust error handling
  - Include a `--help` flag and argument validation
  - Test scripts on supported environments
  - Follow the file naming convention: `{application}-installer.sh`
  - Update README.md if you add a new script

## 👥 Contributors

Thank you to everyone who has contributed:

  - **Zick Keen** - Creator and main maintainer
    If you'd like to be added to this list, please make a contribution and let us know\!

## 💰 Support

This project is developed on a voluntary basis. If you find it helpful and wish to provide support:

  - ⭐ **Star** this repository on GitHub
  - 🍴 **Fork** and share it with your friends
  - 💬 **Provide feedback** or report issues
  - 💝 **Donate**:
      - 🐙 [GitHub Sponsors](https://github.com/sponsors/zickkeen)
      - ☕ [Ko-fi](https://ko-fi.com/zickkeen)
      - 💰 [PayPal](https://paypal.me/donateZickkeen)
      - ☕ [Buy Me a Coffee](https://buymeacoffee.com/zickkeen)
      - 💝 [Sociabuzz](https://sociabuzz.com/zickkeen)
      - **Cryptocurrency**:
          - ₿ **Bitcoin**: `bc1q0rxk0v0d7xgr2s3fg346tljkcqys00vnqc397n`
          - Ξ **Ethereum**: `bc1q0rxk0v0d7xgr2s3fg346tljkcqys00vnqc397n`
          - 💲 **USDT (Polygon)**: `0x39a7cb7abbd45e242e7fbe3adc4acd946e54f7f3`
          - 💲 **USDT (ERC20/BEP20)**: `0xa679bfed3bcb01c0eabfc44ed196df0ca9ad9d8d`

Any support is greatly appreciated and helps the development of this project\!

## 📄 License

This project is licensed under the MIT License. See the `LICENSE` file for more details.

## ⚠️ Disclaimer

These scripts are provided "as is" without any warranty. Always back up important data before running any installer. Use at your own risk.