# Auto Installer

[![GitHub](https://img.shields.io/badge/GitHub-zickkeen/auto--installer-blue)](https://github.com/zickkeen/auto-installer)

Kumpulan script installer otomatis untuk berbagai aplikasi dan layanan open-source. Project ini bertujuan untuk memudahkan instalasi dan konfigurasi awal aplikasi populer di Linux (Debian/Ubuntu dan RedHat-based).

**Repository**: [https://github.com/zickkeen/auto-installer](https://github.com/zickkeen/auto-installer)

## 📋 Changelog

lihat [CHANGELOG.md](CHANGELOG.md) untuk mengetahui detail perubahannya [(changes.ue)](https://github.com/zickkeen/auto-installer/blob/main/CHANGELOG.md)

## 🚀 Fitur

- **Code Server Installer**: Instalasi VS Code Server dengan reverse proxy (Nginx + Certbot atau Cloudflare Tunnel)
- **PostgreSQL Installer**: Instalasi dan konfigurasi PostgreSQL dengan opsi setup database awal

## 📦 Script yang Tersedia

| Script | Deskripsi | OS Support |
|--------|-----------|------------|
| `code_server-installer.sh` | Instalasi Code Server dengan reverse proxy | Ubuntu 22.04 |
| `postgresql-installer.sh` | Instalasi PostgreSQL dengan konfigurasi awal | Debian/Ubuntu, RedHat-based |

## 🛠️ Cara Penggunaan

### Code Server
```bash
# Instalasi dengan Nginx + Certbot (lokal)
bash code_server-installer.sh --domain example.com --password mypass --method nginx

# Instalasi dengan Cloudflare Tunnel (lokal)
bash code_server-installer.sh --domain example.com --password mypass --method cloudflared

# Atau download dan jalankan langsung dari GitHub
curl -fsSL https://raw.githubusercontent.com/zickkeen/auto-installer/main/code_server-installer.sh | bash -s -- --domain example.com --password mypass --method nginx
```

### PostgreSQL
```bash
# Instalasi dasar (lokal)
bash postgresql-installer.sh --pg-version 15

# Instalasi dengan konfigurasi awal (lokal)
bash postgresql-installer.sh --pg-version 14 --setup-db --db-name mydb --db-user myuser --db-pass mypass

# Atau download dan jalankan langsung dari GitHub
curl -fsSL https://raw.githubusercontent.com/zickkeen/auto-installer/main/postgresql-installer.sh | bash -s -- --pg-version 15 --setup-db --db-name mydb --db-user myuser --db-pass mypass
```

Gunakan `--help` pada setiap script untuk panduan lengkap.

## 🤝 Kontribusi

Project ini adalah open-source dan siapa saja dapat berkontribusi! Kami menyambut kontribusi dalam bentuk:

- Menambahkan installer baru untuk aplikasi lain
- Memperbaiki bug atau meningkatkan fitur existing
- Meningkatkan dokumentasi
- Menambahkan dukungan OS baru

### Cara Berkontribusi

1. **Fork** repository ini: [https://github.com/zickkeen/auto-installer](https://github.com/zickkeen/auto-installer)
2. **Clone** fork Anda: `git clone https://github.com/your-username/auto-installer.git`
3. **Buat branch** baru: `git checkout -b feature/nama-fitur`
4. **Lakukan perubahan** dan commit: `git commit -m "Tambah fitur X"`
5. **Push** ke branch Anda: `git push origin feature/nama-fitur`
6. **Buat Pull Request** di GitHub

### Panduan Kontribusi

- Pastikan script menggunakan `set -e` untuk error handling
- Sertakan `--help` dan validasi argumen
- Test script pada environment yang didukung
- Ikuti konvensi penamaan file: `{aplikasi}-installer.sh`
- Update README.md jika menambah script baru

## 👥 Kontributor

Terima kasih kepada semua yang telah berkontribusi:

<!-- CONTRIBUTORS:START -->
- **Zick Keen** - Creator dan maintainer utama
<!-- CONTRIBUTORS:END -->

Jika Anda ingin ditambahkan ke daftar ini, silakan buat kontribusi dan beri tahu kami!

## 💰 Dukungan

Project ini dikembangkan secara sukarela. Jika Anda merasa terbantu dan ingin memberikan dukungan:

- ⭐ **Star** repository ini di GitHub
- 🍴 **Fork** dan bagikan ke teman-teman
- 💬 **Berikan feedback** atau laporkan issue
- 💝 **Donasi**:
  - 🐙 [GitHub Sponsors](https://github.com/sponsors/zickkeen)
  - ☕ [Ko-fi](https://ko-fi.com/zickkeen)
  - 💰 [PayPal](https://paypal.me/donateZickkeen)
  - ☕ [Buy Me a Coffee](https://buymeacoffee.com/zickkeen)
  - 💝 [Sociabuzz](https://sociabuzz.com/zickkeen)
  - **Cryptocurrency**:
    - ₿ **Bitcoin**: `bc1q0rxk0v0d7xgr2s3fg346tljkcqys00vnqc397n`
    - Ξ **Ethereum**: `bc1q0rxk0v0d7xgr2s3fg346tljkcqys00vnqc397n`
    - 💲 **USDT (Polygon)**: `0x39a7cb7abbd45e242e7fbe3adc4acd946e54f7f3`
    - 💲 **USDT Blockchain**: `0xa679bfed3bcb01c0eabfc44ed196df0ca9ad9d8d`

Setiap dukungan sangat berarti untuk pengembangan project ini!

## 📄 Lisensi

Project ini menggunakan lisensi MIT. Lihat file `LICENSE` untuk detail lebih lanjut.

## ⚠️ Disclaimer

Script ini disediakan "as is" tanpa jaminan. Pastikan untuk backup data penting sebelum menjalankan installer. Gunakan dengan risiko sendiri.
