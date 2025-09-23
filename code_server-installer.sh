#!/bin/bash
set -e

# ======================================================
#   code-server installer (Ubuntu/Debian & AlmaLinux/Rocky)
#   Metode: Nginx+Certbot atau Cloudflare Tunnel
# ======================================================

# --- Fungsi uninstaller
uninstall_code_server() {
    echo "=== Uninstalling code-server ==="
    
    # Deteksi OS
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
    else
        echo "❌ Cannot detect OS"
        exit 1
    fi
    
    # Stop dan disable service
    if systemctl is-active --quiet code-server; then
        echo "🔄 Stopping code-server service..."
        sudo systemctl stop code-server
    fi
    
    if systemctl is-enabled --quiet code-server 2>/dev/null; then
        echo "🔄 Disabling code-server service..."
        sudo systemctl disable code-server
    fi
    
    # Remove systemd service file
    if [ -f "/lib/systemd/system/code-server.service" ] || [ -f "/etc/systemd/system/code-server.service" ]; then
        echo "🗑️  Removing systemd service..."
        sudo rm -f /lib/systemd/system/code-server.service
        sudo rm -f /etc/systemd/system/code-server.service
        sudo systemctl daemon-reload
    fi
    
    # Remove code-server binary dan folder
    if [ -d "/usr/lib/code-server" ]; then
        echo "🗑️  Removing code-server installation..."
        sudo rm -rf /usr/lib/code-server
    fi
    
    if [ -L "/usr/bin/code-server" ]; then
        sudo rm -f /usr/bin/code-server
    fi
    
    # Remove data directory
    if [ -d "/var/lib/code-server" ]; then
        echo "🗑️  Removing code-server data..."
        sudo rm -rf /var/lib/code-server
    fi
    
    # Remove nginx config
    if [[ "$OS" =~ ^(ubuntu|debian)$ ]]; then
        if [ -f "/etc/nginx/sites-available/code-server.conf" ]; then
            echo "🗑️  Removing nginx configuration..."
            sudo rm -f /etc/nginx/sites-available/code-server.conf
            sudo rm -f /etc/nginx/sites-enabled/code-server.conf
            if systemctl is-active --quiet nginx; then
                sudo systemctl reload nginx
            fi
        fi
    else
        if [ -f "/etc/nginx/conf.d/code-server.conf" ]; then
            echo "🗑️  Removing nginx configuration..."
            sudo rm -f /etc/nginx/conf.d/code-server.conf
            if systemctl is-active --quiet nginx; then
                sudo systemctl reload nginx
            fi
        fi
    fi
    
    # Remove cloudflared config
    if [ -f "/etc/cloudflared/config.yml" ]; then
        echo "🗑️  Removing cloudflared configuration..."
        if systemctl is-active --quiet cloudflared; then
            sudo systemctl stop cloudflared
        fi
        if systemctl is-enabled --quiet cloudflared 2>/dev/null; then
            sudo systemctl disable cloudflared
        fi
        sudo rm -f /etc/cloudflared/config.yml
    fi
    
    # Clean temporary files
    rm -rf ~/code-server 2>/dev/null
    
    echo "✅ code-server berhasil di-uninstall!"
    echo "📝 Catatan: Nginx, Certbot, dan Cloudflared tidak dihapus (mungkin digunakan aplikasi lain)"
}

# --- Fungsi pengecekan instalasi existing
check_existing_installation() {
    if systemctl list-unit-files | grep -q "code-server.service" || 
       [ -f "/lib/systemd/system/code-server.service" ] || 
       [ -f "/etc/systemd/system/code-server.service" ] ||
       [ -d "/usr/lib/code-server" ] || 
       [ -L "/usr/bin/code-server" ]; then
        echo "⚠️  Ditemukan instalasi code-server yang sudah ada!"
        echo ""
        read -p "Apakah Anda ingin menghapus instalasi lama? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            uninstall_code_server
            echo ""
        else
            echo "❌ Instalasi dibatalkan. Gunakan --uninstall untuk menghapus instalasi lama."
            exit 1
        fi
    fi
}

# --- Default config
CODE_VERSION="4.104.0"
DOMAIN=""
CODE_PASS=""
METHOD=""
PORT="8080"

# --- Parse arguments
while [[ "$#" -gt 0 ]]; do
  case $1 in
    --domain) DOMAIN="$2"; shift ;;
    --password) CODE_PASS="$2"; shift ;;
    --method) METHOD="$2"; shift ;;
    --port) PORT="$2"; shift ;;
    --uninstall) 
      uninstall_code_server
      exit 0 ;;
    --help) 
      echo "code-server installer (Ubuntu/Debian & AlmaLinux/Rocky)"
      echo ""
      echo "Panduan instalasi code-server dengan reverse proxy."
      echo ""
      echo "Opsi:"
      echo "  --domain <domain>       Domain untuk akses code-server (wajib untuk nginx/cloudflared)"
      echo "  --password <pass>       Password untuk login (wajib)"
      echo "  --method <nginx|cloudflared|direct>  Metode reverse proxy (wajib)"
      echo "  --port <port>           Port untuk code-server (default: 8080)"
      echo "  --uninstall             Uninstall code-server dan semua konfigurasi"
      echo "  --help                  Tampilkan panduan ini"
      echo ""
      echo "Metode:"
      echo "  nginx      : Menggunakan Nginx + Certbot untuk HTTPS"
      echo "  cloudflared: Menggunakan Cloudflare Tunnel"
      echo "  direct     : Jalankan code-server langsung tanpa reverse proxy (tidak aman)"
      echo ""
      echo "Contoh:"
      echo "  bash code_server-installer.sh --domain example.com --password mypass --method nginx"
      echo "  bash code_server-installer.sh --domain example.com --password mypass --method nginx --port 9090"
      echo ""
      echo "  curl -fsSL https://domain.tld/install-code-server.sh | bash -s -- \\"
      echo "    --domain ide.domainmu.com \\"
      echo "    --password rahasiaBanget \\"
      echo "    --method cloudflared"
      echo ""
      echo "  bash code_server-installer.sh --password mypass --method direct --port 3000"
      echo ""
      echo "Uninstall:"
      echo "  bash code_server-installer.sh --uninstall"
      echo ""
      exit 0 ;;
    *) echo "Argumen tidak dikenali: $1" && exit 1 ;;
  esac
  shift
done

if [[ -z "$CODE_PASS" || -z "$METHOD" ]]; then
  echo "❌ Usage:"
  echo "  Install: bash code_server-installer.sh --password <pass> --method <nginx|cloudflared|direct> [--domain <domain>] [--port <port>]"
  echo "  Uninstall: bash code_server-installer.sh --uninstall"
  echo "  Gunakan --help untuk panduan lengkap"
  exit 1
fi

if [[ "$METHOD" != "direct" && -z "$DOMAIN" ]]; then
  echo "❌ Domain wajib untuk method nginx atau cloudflared"
  exit 1
fi

# --- Validasi port
if ! [[ "$PORT" =~ ^[0-9]+$ ]] || [ "$PORT" -lt 1 ] || [ "$PORT" -gt 65535 ]; then
  echo "❌ Port harus berupa angka antara 1-65535"
  exit 1
fi

# --- Cek instalasi existing
check_existing_installation

echo "=== Install code-server v$CODE_VERSION ==="

# --- Deteksi OS
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
    VER=$VERSION_ID
else
    echo "❌ Cannot detect OS"
    exit 1
fi

# --- Install dependencies
case $OS in
    ubuntu|debian)
        sudo apt update
        sudo apt install -y wget tar
        ;;
    almalinux|rocky|rhel|centos)
        sudo dnf update -y
        sudo dnf install -y wget tar
        ;;
    *)
        echo "❌ OS tidak didukung: $OS"
        echo "   Supported: Ubuntu, Debian, AlmaLinux, Rocky Linux, RHEL"
        exit 1
        ;;
esac

# --- Download & setup code-server
mkdir -p ~/code-server
cd ~/code-server

wget -q https://github.com/coder/code-server/releases/download/v${CODE_VERSION}/code-server-${CODE_VERSION}-linux-amd64.tar.gz
tar -xzf code-server-${CODE_VERSION}-linux-amd64.tar.gz

sudo mv code-server-${CODE_VERSION}-linux-amd64 /usr/lib/code-server
sudo ln -sf /usr/lib/code-server/bin/code-server /usr/bin/code-server

sudo mkdir -p /var/lib/code-server
sudo chown -R $(whoami):$(whoami) /var/lib/code-server

# --- Tentukan bind address berdasarkan method
if [[ "$METHOD" == "direct" ]]; then
  BIND_ADDR="0.0.0.0:${PORT}"
  echo "⚠️  PERINGATAN: Method 'direct' mengekspos code-server langsung tanpa reverse proxy."
  echo "   Ini tidak aman dan hanya untuk testing lokal. Pastikan firewall dikonfigurasi dengan benar."
  echo "   Port yang digunakan: ${PORT}"
else
  BIND_ADDR="127.0.0.1:${PORT}"
fi

# --- Buat systemd service
cat <<EOF | sudo tee /lib/systemd/system/code-server.service >/dev/null
[Unit]
Description=code-server
After=network.target

[Service]
Type=simple
Environment=PASSWORD=${CODE_PASS}
Environment=TZ=Asia/Jakarta
Environment=LC_ALL=en_US.UTF-8
Environment=HOME=/home/$(whoami)
ExecStart=/usr/bin/code-server --bind-addr ${BIND_ADDR} --user-data-dir /var/lib/code-server --auth password
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable --now code-server

# --- Setup reverse proxy
if [[ "$METHOD" == "nginx" ]]; then
  echo "=== Setup Nginx + Certbot ==="

  case $OS in
      ubuntu|debian)
          sudo apt install -y nginx certbot python3-certbot-nginx
          NGINX_CONF_DIR="/etc/nginx/sites-available"
          NGINX_ENABLE_DIR="/etc/nginx/sites-enabled"
          ;;
      almalinux|rocky|rhel|centos)
          sudo dnf install -y nginx certbot python3-certbot-nginx
          NGINX_CONF_DIR="/etc/nginx/conf.d"
          NGINX_ENABLE_DIR=""
          ;;
  esac

  if [[ "$OS" =~ ^(ubuntu|debian)$ ]]; then
      sudo tee /etc/nginx/sites-available/code-server.conf >/dev/null <<EOF
server {
    listen 80;
    server_name ${DOMAIN};

    location / {
        proxy_pass http://127.0.0.1:${PORT}/;
        proxy_set_header Host \$host;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection upgrade;
        proxy_set_header Accept-Encoding gzip;
        proxy_set_header Accept-Language en;
        proxy_set_header X-Forwarded-For \$remote_addr;
    }
}
EOF
  else
      sudo tee /etc/nginx/conf.d/code-server.conf >/dev/null <<EOF
server {
    listen 80;
    server_name ${DOMAIN};

    location / {
        proxy_pass http://127.0.0.1:${PORT}/;
        proxy_set_header Host \$host;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection upgrade;
        proxy_set_header Accept-Encoding gzip;
        proxy_set_header Accept-Language en;
        proxy_set_header X-Forwarded-For \$remote_addr;
    }
}
EOF
  fi

  if [[ "$OS" =~ ^(ubuntu|debian)$ ]]; then
      sudo ln -sf /etc/nginx/sites-available/code-server.conf /etc/nginx/sites-enabled/
  fi

  # Enable and start nginx
  sudo systemctl enable nginx
  sudo nginx -t && sudo systemctl restart nginx

  # Configure firewall
  if [[ "$OS" =~ ^(almalinux|rocky|rhel|centos)$ ]]; then
      if systemctl is-active --quiet firewalld; then
          sudo firewall-cmd --permanent --add-service=http
          sudo firewall-cmd --permanent --add-service=https
          sudo firewall-cmd --reload
          echo "✅ Firewall configured to allow HTTP/HTTPS"
      else
          echo "⚠️  FirewallD tidak aktif. Pastikan port 80/443 dapat diakses dari luar."
      fi
  elif [[ "$OS" =~ ^(ubuntu|debian)$ ]]; then
      if command -v ufw >/dev/null 2>&1 && ufw status | grep -q "Status: active"; then
          sudo ufw allow 'Nginx Full'
          echo "✅ UFW configured to allow Nginx"
      else
          echo "⚠️  UFW tidak aktif atau tidak terinstall. Pastikan port 80/443 dapat diakses dari luar."
      fi
  fi

  sudo certbot --nginx -d $DOMAIN --non-interactive --agree-tos -m admin@$DOMAIN

elif [[ "$METHOD" == "cloudflared" ]]; then
  echo "=== Setup Cloudflare Tunnel ==="

  curl -fsSL https://developers.cloudflare.com/cloudflared/install.sh | sudo bash

  cloudflared tunnel login
  cloudflared tunnel create code-server
  cloudflared tunnel route dns code-server $DOMAIN

  sudo mkdir -p /etc/cloudflared
  cat <<EOF | sudo tee /etc/cloudflared/config.yml >/dev/null
tunnel: code-server
credentials-file: /root/.cloudflared/*.json

ingress:
  - hostname: ${DOMAIN}
    service: http://localhost:${PORT}
  - service: http_status:404
EOF

  sudo cloudflared service install
  sudo systemctl enable --now cloudflared

elif [[ "$METHOD" == "direct" ]]; then
  echo "=== Setup Direct Access ==="
  
  # Configure firewall
  if [[ "$OS" =~ ^(almalinux|rocky|rhel|centos)$ ]]; then
      if systemctl is-active --quiet firewalld; then
          sudo firewall-cmd --permanent --add-port=${PORT}/tcp
          sudo firewall-cmd --reload
          echo "✅ Firewall configured to allow port ${PORT}"
      else
          echo "⚠️  FirewallD tidak aktif. Pastikan port ${PORT} dapat diakses dari luar jika diperlukan."
      fi
  elif [[ "$OS" =~ ^(ubuntu|debian)$ ]]; then
      if command -v ufw >/dev/null 2>&1 && ufw status | grep -q "Status: active"; then
          sudo ufw allow ${PORT}/tcp
          echo "✅ UFW configured to allow port ${PORT}"
      else
          echo "⚠️  UFW tidak aktif atau tidak terinstall. Pastikan port ${PORT} dapat diakses dari luar jika diperlukan."
      fi
  fi
  
  echo "✅ code-server berjalan di http://$(hostname -I | awk '{print $1}'):${PORT}"
  echo "🔐 Password: ${CODE_PASS}"

else
  echo "❌ METHOD harus 'nginx', 'cloudflared', atau 'direct'"
  exit 1
fi

echo "✅ Instalasi selesai"
if [[ "$METHOD" == "direct" ]]; then
  echo "🌐 Akses: http://$(hostname -I | awk '{print $1}'):${PORT}"
else
  echo "🌐 Akses: https://${DOMAIN}"
fi
echo "🔐 Password login: ${CODE_PASS}"
