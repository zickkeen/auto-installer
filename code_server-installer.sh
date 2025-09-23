#!/bin/bash
set -e

# ======================================================
#   code-server installer (Ubuntu/Debian & AlmaLinux/Rocky)
#   Metode: Nginx+Certbot atau Cloudflare Tunnel
# ======================================================

# --- Default config
CODE_VERSION="4.104.0"
DOMAIN=""
CODE_PASS=""
METHOD=""

# --- Parse arguments
while [[ "$#" -gt 0 ]]; do
  case $1 in
    --domain) DOMAIN="$2"; shift ;;
    --password) CODE_PASS="$2"; shift ;;
    --method) METHOD="$2"; shift ;;
    --help) 
      echo "code-server installer (Ubuntu/Debian & AlmaLinux/Rocky)"
      echo ""
      echo "Panduan instalasi code-server dengan reverse proxy."
      echo ""
      echo "Opsi:"
      echo "  --domain <domain>       Domain untuk akses code-server (wajib untuk nginx/cloudflared)"
      echo "  --password <pass>       Password untuk login (wajib)"
      echo "  --method <nginx|cloudflared|direct>  Metode reverse proxy (wajib)"
      echo "  --help                  Tampilkan panduan ini"
      echo ""
      echo "Metode:"
      echo "  nginx      : Menggunakan Nginx + Certbot untuk HTTPS"
      echo "  cloudflared: Menggunakan Cloudflare Tunnel"
      echo "  direct     : Jalankan code-server langsung tanpa reverse proxy (tidak aman)"
      echo ""
      echo "Contoh:"
      echo "  bash code_server-installer.sh --domain example.com --password mypass --method nginx"
      echo ""
      echo "  curl -fsSL https://domain.tld/install-code-server.sh | bash -s -- \\"
      echo "    --domain ide.domainmu.com \\"
      echo "    --password rahasiaBanget \\"
      echo "    --method cloudflared"
      echo ""
      echo "  bash code_server-installer.sh --password mypass --method direct"
      echo ""
      exit 0 ;;
    *) echo "Argumen tidak dikenali: $1" && exit 1 ;;
  esac
  shift
done

if [[ -z "$CODE_PASS" || -z "$METHOD" ]]; then
  echo "❌ Usage:"
  echo "  bash code_server-installer.sh --password <pass> --method <nginx|cloudflared|direct> [--domain <domain>]"
  echo "  Gunakan --help untuk panduan lengkap"
  exit 1
fi

if [[ "$METHOD" != "direct" && -z "$DOMAIN" ]]; then
  echo "❌ Domain wajib untuk method nginx atau cloudflared"
  exit 1
fi

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
  BIND_ADDR="0.0.0.0:8080"
  echo "⚠️  PERINGATAN: Method 'direct' mengekspos code-server langsung tanpa reverse proxy."
  echo "   Ini tidak aman dan hanya untuk testing lokal. Pastikan firewall dikonfigurasi dengan benar."
else
  BIND_ADDR="127.0.0.1:8080"
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
  else
      sudo tee /etc/nginx/conf.d/code-server.conf >/dev/null <<EOF
  fi
server {
    listen 80;
    server_name ${DOMAIN};

    location / {
        proxy_pass http://127.0.0.1:8080/;
        proxy_set_header Host \$host;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection upgrade;
        proxy_set_header Accept-Encoding gzip;
        proxy_set_header Accept-Language en;
        proxy_set_header X-Forwarded-For \$remote_addr;
    }
}
EOF

  if [[ "$OS" =~ ^(ubuntu|debian)$ ]]; then
      sudo ln -sf /etc/nginx/sites-available/code-server.conf /etc/nginx/sites-enabled/
  fi

  # Enable and start nginx
  sudo systemctl enable nginx
  sudo nginx -t && sudo systemctl restart nginx

  # Open firewall for RedHat family
  if [[ "$OS" =~ ^(almalinux|rocky|rhel|centos)$ ]]; then
      sudo firewall-cmd --permanent --add-service=http
      sudo firewall-cmd --permanent --add-service=https
      sudo firewall-cmd --reload
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
    service: http://localhost:8080
  - service: http_status:404
EOF

  sudo cloudflared service install
  sudo systemctl enable --now cloudflared

elif [[ "$METHOD" == "direct" ]]; then
  echo "=== Setup Direct Access ==="
  
  # Open firewall for RedHat family
  if [[ "$OS" =~ ^(almalinux|rocky|rhel|centos)$ ]]; then
      sudo firewall-cmd --permanent --add-port=8080/tcp
      sudo firewall-cmd --reload
      echo "✅ Firewall configured to allow port 8080"
  fi
  
  echo "✅ code-server berjalan di http://$(hostname -I | awk '{print $1}'):8080"
  echo "🔐 Password: ${CODE_PASS}"

else
  echo "❌ METHOD harus 'nginx', 'cloudflared', atau 'direct'"
  exit 1
fi

echo "✅ Instalasi selesai"
if [[ "$METHOD" == "direct" ]]; then
  echo "🌐 Akses: http://$(hostname -I | awk '{print $1}'):8080"
else
  echo "🌐 Akses: https://${DOMAIN}"
fi
echo "🔐 Password login: ${CODE_PASS}"
