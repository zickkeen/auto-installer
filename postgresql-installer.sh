#!/bin/bash
set -e

# ======================================================
#   PostgreSQL Auto Installer
#   Mendukung Debian/Ubuntu dan RedHat-based (AlmaLinux, Rocky, CloudLinux, dll)
# ======================================================

# --- Default config
PG_VERSION="15"
SHOW_HELP=false
SHOW_VERSION=false
SETUP_DB=false
DB_NAME=""
DB_USER=""
DB_PASS=""

# --- Fungsi deteksi OS
detect_os() {
    if [[ -f /etc/debian_version ]]; then
        echo "debian"
    elif [[ -f /etc/redhat-release ]]; then
        echo "redhat"
    else
        echo "unknown"
    fi
}

# --- Fungsi instalasi Debian/Ubuntu
install_debian() {
    echo "=== Instalasi PostgreSQL $PG_VERSION untuk Debian/Ubuntu ==="
    sudo apt update
    sudo apt install -y postgresql-$PG_VERSION postgresql-contrib-$PG_VERSION

    # Enable dan start service
    sudo systemctl enable postgresql
    sudo systemctl start postgresql

    # Setup password untuk postgres user (opsional)
    echo "PostgreSQL berhasil diinstal. User 'postgres' dapat digunakan."
}

# --- Fungsi instalasi RedHat-based
install_redhat() {
    echo "=== Instalasi PostgreSQL $PG_VERSION untuk RedHat-based ==="
    # Enable PostgreSQL repository
    sudo dnf install -y https://download.postgresql.org/pub/repos/yum/reporpms/EL-8-x86_64/pgdg-redhat-repo-latest.noarch.rpm || \
    sudo yum install -y https://download.postgresql.org/pub/repos/yum/reporpms/EL-7-x86_64/pgdg-redhat-repo-latest.noarch.rpm

    # Install PostgreSQL
    sudo dnf install -y postgresql$PG_VERSION-server postgresql$PG_VERSION-contrib || \
    sudo yum install -y postgresql$PG_VERSION-server postgresql$PG_VERSION-contrib

    # Initialize database
    sudo /usr/pgsql-$PG_VERSION/bin/postgresql-$PG_VERSION-setup initdb || \
    sudo service postgresql-$PG_VERSION initdb

    # Enable dan start service
    sudo systemctl enable postgresql-$PG_VERSION
    sudo systemctl start postgresql-$PG_VERSION

    echo "PostgreSQL berhasil diinstal."
}

# --- Fungsi konfigurasi awal
configure_postgresql() {
    echo "=== Konfigurasi Awal PostgreSQL ==="

    if [[ "$OS" == "debian" ]]; then
        PG_CONF="/etc/postgresql/$PG_VERSION/main/postgresql.conf"
        PG_HBA="/etc/postgresql/$PG_VERSION/main/pg_hba.conf"
        SERVICE_NAME="postgresql"
    elif [[ "$OS" == "redhat" ]]; then
        PG_CONF="/var/lib/pgsql/$PG_VERSION/data/postgresql.conf"
        PG_HBA="/var/lib/pgsql/$PG_VERSION/data/pg_hba.conf"
        SERVICE_NAME="postgresql-$PG_VERSION"
    fi

    # Backup config files
    sudo cp $PG_CONF $PG_CONF.backup
    sudo cp $PG_HBA $PG_HBA.backup

    # Update postgresql.conf untuk listen_addresses
    sudo sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/" $PG_CONF

    # Update pg_hba.conf untuk mengizinkan koneksi dari semua
    echo "host    all             all             0.0.0.0/0               md5" | sudo tee -a $PG_HBA >/dev/null
    echo "host    all             all             ::/0                    md5" | sudo tee -a $PG_HBA >/dev/null

    # Set password untuk postgres user
    if [[ -n "$DB_PASS" ]]; then
        sudo -u postgres psql -c "ALTER USER postgres PASSWORD '$DB_PASS';"
        echo "Password untuk user 'postgres' telah diubah."
    fi

    # Buat database baru jika ditentukan
    if [[ -n "$DB_NAME" ]]; then
        sudo -u postgres createdb $DB_NAME
        echo "Database '$DB_NAME' telah dibuat."
    fi

    # Buat user baru jika ditentukan
    if [[ -n "$DB_USER" && -n "$DB_PASS" ]]; then
        sudo -u postgres psql -c "CREATE USER $DB_USER WITH PASSWORD '$DB_PASS';"
        if [[ -n "$DB_NAME" ]]; then
            sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER;"
        fi
        echo "User '$DB_USER' telah dibuat dan diberi akses ke database '$DB_NAME'."
    fi

    # Restart service
    sudo systemctl restart $SERVICE_NAME

    echo "Konfigurasi awal selesai."
}

# --- Parse arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --pg-version) PG_VERSION="$2"; shift ;;
        --setup-db) SETUP_DB=true ;;
        --db-name) DB_NAME="$2"; shift ;;
        --db-user) DB_USER="$2"; shift ;;
        --db-pass) DB_PASS="$2"; shift ;;
        --help) SHOW_HELP=true ;;
        --version) SHOW_VERSION=true ;;
        *) echo "Argumen tidak dikenali: $1" && exit 1 ;;
    esac
    shift
done

# --- Tampilkan help
if [[ "$SHOW_HELP" == true ]]; then
    echo "PostgreSQL Auto Installer"
    echo ""
    echo "Script untuk instalasi dan konfigurasi PostgreSQL secara otomatis pada Debian/Ubuntu dan RedHat-based."
    echo ""
    echo "Opsi:"
    echo "  --pg-version <versi>    Versi PostgreSQL (default: 15)"
    echo "  --setup-db              Lakukan konfigurasi awal (listen_addresses, pg_hba.conf)"
    echo "  --db-name <nama>        Nama database baru (opsional, memerlukan --setup-db)"
    echo "  --db-user <user>        Username baru (opsional, memerlukan --setup-db)"
    echo "  --db-pass <pass>        Password untuk user (opsional, memerlukan --setup-db)"
    echo "  --help                  Tampilkan panduan ini"
    echo "  --version               Tampilkan versi script"
    echo ""
    echo "Contoh:"
    echo "  bash postgresql-installer.sh --pg-version 14 --setup-db --db-name mydb --db-user myuser --db-pass mypass"
    echo ""
    exit 0
fi

# --- Tampilkan versi
if [[ "$SHOW_VERSION" == true ]]; then
    echo "PostgreSQL Auto Installer v1.0"
    exit 0
fi

# --- Deteksi OS
OS=$(detect_os)
if [[ "$OS" == "unknown" ]]; then
    echo "❌ OS tidak didukung. Script ini mendukung Debian/Ubuntu dan RedHat-based."
    exit 1
fi

echo "OS terdeteksi: $OS"

# --- Instalasi berdasarkan OS
if [[ "$OS" == "debian" ]]; then
    install_debian
elif [[ "$OS" == "redhat" ]]; then
    install_redhat
fi

# --- Konfigurasi awal jika diminta
if [[ "$SETUP_DB" == true ]]; then
    configure_postgresql
fi

echo "✅ Instalasi PostgreSQL selesai!"
