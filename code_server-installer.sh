#!/bin/bash
set -e

# ======================================================
#   code-server installer (Ubuntu 22.04)
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
      echo "code-server installer (Ubuntu 22.04)"
      echo ""
      echo "Panduan instalasi code-server dengan reverse proxy."
      echo ""
      echo "Opsi:"
      echo "  --domain <domain>       Domain untuk akses code-server (wajib)"
      echo "  --password <pass>       Password untuk login (wajib)"
      echo "  --method <nginx|cloudflared>  Metode reverse proxy (wajib)"
      echo "  --help                  Tampilkan panduan ini"
      echo ""
      echo "Metode:"
      echo "  nginx      : Menggunakan Nginx + Certbot untuk HTTPS"
      echo "  cloudflared: Menggunakan Cloudflare Tunnel"
      echo ""
      echo "Contoh:"
      echo "  bash code_server-installer.sh --domain example.com --password mypass --method nginx"
      echo ""
      echo "  curl -fsSL https://domain.tld/install-code-server.sh | bash -s -- \\"
      echo "    --domain ide.domainmu.com \\"
      echo "    --password rahasiaBanget \\"
      echo "    --method cloudflared"
      echo ""
      exit 0 ;;
    *) echo "Argumen tidak dikenali: $1" && exit 1 ;;
  esac
  shift
done

if [[ -z "$DOMAIN" || -z "$CODE_PASS" || -z "$METHOD" ]]; then
  echo "❌ Usage:"
  echo "  bash code_server-installer.sh --domain <domain> --password <pass> --method <nginx|cloudflared>"
  echo "  Gunakan --help untuk panduan lengkap"
  exit 1
fi

echo "=== Install code-server v$CODE_VERSION ==="

# --- Install dependencies
sudo apt update
sudo apt install -y wget tar

# --- Download & setup code-server
mkdir -p ~/code-server
cd ~/code-server

wget -q https://github.com/coder/code-server/releases/download/v${CODE_VERSION}/code-server-${CODE_VERSION}-linux-amd64.tar.gz
tar -xzf code-server-${CODE_VERSION}-linux-amd64.tar.gz

sudo mv code-server-${CODE_VERSION}-linux-amd64 /usr/lib/code-server
sudo ln -sf /usr/lib/code-server/bin/code-server /usr/bin/code-server

sudo mkdir -p /var/lib/code-server
sudo chown -R $(whoami):$(whoami) /var/lib/code-server

# --- Buat systemd service
cat <<EOF | sudo tee /lib/systemd/system/code-server.service >/dev/null
[Unit]
Description=code-server
After=network.target

[Service]
Type=simple
Environment=PASSWORD=${CODE_PASS}
Environment=TZ=Asia/Jakarta
Environtment=LC_ALL=en_US.UTF-8
Environtment=HOME=/home/$(whoami)
ExecStart=/usr/bin/code-server --bind-addr 127.0.0.1:8080 --user-data-dir /var/lib/code-server --auth password
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable --now code-server

# --- Setup reverse proxy
if [[ "$METHOD" == "nginx" ]]; then
  echo "=== Setup Nginx + Certbot ==="

  sudo apt install -y nginx certbot python3-certbot-nginx

  sudo tee /etc/nginx/sites-available/code-server.conf >/dev/null <<EOF
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

  sudo ln -sf /etc/nginx/sites-available/code-server.conf /etc/nginx/sites-enabled/
  sudo nginx -t && sudo systemctl restart nginx

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

else
  echo "❌ METHOD harus 'nginx' atau 'cloudflared'"
  exit 1
fi

echo "✅ Instalasi selesai"
echo "🌐 Akses: https://${DOMAIN}"
echo "🔐 Password login: ${CODE_PASS}"
