#!/bin/bash
set -e

# ======================================================
#   OpenSIPS Auto Installer
#   Stable version with best practice configuration
# ======================================================

# --- Default config
OPENSIPS_VERSION="3.5"
DB_ENGINE="mysql"
DB_HOST="localhost"
DB_PORT="3306"
DB_NAME="opensips"
DB_USER="opensips"
DB_PASS=""
SIP_DOMAIN=""
INSTALL_DB=true
INSTALL_WEB=false

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

# --- Fungsi install dependencies
install_dependencies() {
    echo "=== Installing dependencies ==="

    if [[ "$OS" == "debian" ]]; then
        sudo apt update
        sudo apt install -y wget gnupg2 software-properties-common

        # Install MySQL/MariaDB
        sudo apt install -y mariadb-server mariadb-client

        # Install PHP untuk web interface (opsional)
        if [[ "$INSTALL_WEB" == true ]]; then
            sudo apt install -y php php-mysql php-gd php-curl apache2
        fi

    elif [[ "$OS" == "redhat" ]]; then
        sudo yum update -y
        sudo yum install -y wget

        # Install MySQL/MariaDB
        sudo yum install -y mariadb-server mariadb

        # Install PHP untuk web interface (opsional)
        if [[ "$INSTALL_WEB" == true ]]; then
            sudo yum install -y php php-mysql php-gd php-curl httpd
        fi
    fi
}

# --- Fungsi install OpenSIPS Debian/Ubuntu
install_opensips_debian() {
    echo "=== Installing OpenSIPS $OPENSIPS_VERSION for Debian/Ubuntu ==="

    # Detect Ubuntu/Debian version for repository
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        DISTRO_CODENAME=${VERSION_CODENAME:-$(lsb_release -cs 2>/dev/null || echo "noble")}
    else
        DISTRO_CODENAME="noble"  # fallback
    fi

    # Add official OpenSIPS repository with modern APT signing
    sudo curl -s https://apt.opensips.org/opensips-org.gpg -o /usr/share/keyrings/opensips-org.gpg
    echo "deb [signed-by=/usr/share/keyrings/opensips-org.gpg] https://apt.opensips.org $DISTRO_CODENAME $OPENSIPS_VERSION-releases" | sudo tee /etc/apt/sources.list.d/opensips.list

    sudo apt update
    sudo apt install -y opensips opensips-mysql-module opensips-postgres-module opensips-unixodbc-module

    # Install additional modules (only those available for 3.5)
    sudo apt install -y opensips-http-modules
}

# --- Fungsi install OpenSIPS RedHat
install_opensips_redhat() {
    echo "=== Installing OpenSIPS $OPENSIPS_VERSION for RedHat ==="

    # Add official OpenSIPS repository
    sudo yum install -y http://yum.opensips.org/opensips-org.repo

    # Install OpenSIPS packages
    sudo yum install -y opensips opensips-mysql opensips-postgres opensips-unixodbc opensips-http opensips-json opensips-xml opensips-tls
}

# --- Fungsi setup database
setup_database() {
    echo "=== Setting up database ==="

    # Start MySQL/MariaDB
    sudo systemctl enable mariadb
    sudo systemctl start mariadb

    # Secure MySQL installation
    sudo mysql_secure_installation << EOF

y
$DB_PASS
$DB_PASS
y
y
y
y
EOF

    # Create OpenSIPS database and user
    sudo mysql -u root -p"$DB_PASS" << EOF
CREATE DATABASE IF NOT EXISTS $DB_NAME;
CREATE USER IF NOT EXISTS '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';
GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost';
FLUSH PRIVILEGES;
EOF

    # Create OpenSIPS tables
    # Prefer opensipsdbctl if available, otherwise try to import SQL schema manually
    if command -v opensipsdbctl >/dev/null 2>&1; then
        sudo -u opensips opensipsdbctl create $DB_NAME
    else
        echo "opensipsdbctl: not found, attempting manual DB schema import"
        # Try to locate an OpenSIPS SQL schema file from installed packages
        SQL_PATH=""
        # Check package contents first (dpkg may list files)
        if command -v dpkg >/dev/null 2>&1; then
            SQL_PATH=$(dpkg -L opensips 2>/dev/null | grep -E "\.sql$" | head -n1 || true)
        fi
        # Fallback: search common locations
        if [[ -z "$SQL_PATH" ]]; then
            SQL_PATH=$(find /usr/share -type f -iname "*opensips*schema*.sql" -o -iname "*opensips*create*.sql" 2>/dev/null | head -n1 || true)
        fi

        if [[ -n "$SQL_PATH" ]]; then
            echo "Found SQL schema: $SQL_PATH"
            # Try importing using socket auth (sudo mysql)
            if sudo mysql -e 'SELECT 1' >/dev/null 2>&1; then
                echo "Importing schema using sudo mysql (socket auth)"
                sudo mysql $DB_NAME < "$SQL_PATH"
            elif sudo mysql -u root -p"$DB_PASS" -e 'SELECT 1' >/dev/null 2>&1; then
                echo "Importing schema using root password"
                sudo mysql -u root -p"$DB_PASS" $DB_NAME < "$SQL_PATH"
            else
                echo "❌ Cannot connect to MariaDB as root (socket or password). Please import $SQL_PATH into $DB_NAME manually."
            fi
        else
            echo "No local SQL schema found; downloading from upstream"
            # Download official schema for the installed version
            SCHEMA_URL="https://raw.githubusercontent.com/OpenSIPS/opensips/$OPENSIPS_VERSION/scripts/mysql/standard-create.sql"
            TMP_SCHEMA="/tmp/opensips_schema.sql"
            if wget -q -O "$TMP_SCHEMA" "$SCHEMA_URL"; then
                echo "Downloaded schema from $SCHEMA_URL"
                # Import the downloaded schema
                if sudo mysql -e 'SELECT 1' >/dev/null 2>&1; then
                    echo "Importing downloaded schema using sudo mysql (socket auth)"
                    sudo mysql $DB_NAME < "$TMP_SCHEMA"
                elif sudo mysql -u root -p"$DB_PASS" -e 'SELECT 1' >/dev/null 2>&1; then
                    echo "Importing downloaded schema using root password"
                    sudo mysql -u root -p"$DB_PASS" $DB_NAME < "$TMP_SCHEMA"
                else
                    echo "❌ Cannot connect to MariaDB as root. Downloaded schema saved to $TMP_SCHEMA; import manually into $DB_NAME."
                fi
                # Clean up
                rm -f "$TMP_SCHEMA"
            else
                echo "❌ Failed to download schema from $SCHEMA_URL. Please install opensips tools or provide schema file and import into $DB_NAME."
            fi
        fi
    fi
}

# --- Fungsi create best practice configuration
create_config() {
    echo "=== Creating best practice configuration ==="

    OPENSIPS_CONFIG="/etc/opensips/opensips.cfg"

    # Backup existing config
    if [[ -f "$OPENSIPS_CONFIG" ]]; then
        sudo cp $OPENSIPS_CONFIG $OPENSIPS_CONFIG.backup
    fi

    # Ensure config directory exists
    sudo mkdir -p $(dirname "$OPENSIPS_CONFIG")

    # Use OpenSIPS 3.5 config templating system
    if command -v opensips-cli >/dev/null 2>&1; then
        echo "Generating config using OpenSIPS CLI templating"
        sudo opensips-cli cfg generate --template basic --output "$OPENSIPS_CONFIG" \
            --set db_url="mysql://$DB_USER:$DB_PASS@$DB_HOST:$DB_PORT/$DB_NAME" \
            --set httpd_port=8888 \
            --set socket="tcp:127.0.0.1:5060" \
            --set socket="udp:127.0.0.1:5060"
    else
        echo "Warning: opensips-cli not found; falling back to sample config copy"
        # Find package-provided sample config
        SAMPLE_CONFIG=""
        # Prefer dpkg listing if available
        if command -v dpkg >/dev/null 2>&1; then
            SAMPLE_CONFIG=$(dpkg -L opensips 2>/dev/null | grep -E "\.cfg$" | grep -E "(sample|example|opensips\.cfg)" | head -n1 || true)
        fi
        # Fallback: search common locations
        if [[ -z "$SAMPLE_CONFIG" ]]; then
            for p in "/usr/share/doc/opensips/examples/opensips.cfg" "/usr/share/opensips/opensips.cfg.sample" "/etc/opensips/opensips.cfg.sample" "/usr/share/opensips/opensips.cfg"; do
                if [[ -f "$p" ]]; then
                    SAMPLE_CONFIG="$p"
                    break
                fi
            done
        fi

        if [[ -n "$SAMPLE_CONFIG" && "$SAMPLE_CONFIG" != "$OPENSIPS_CONFIG" ]]; then
            echo "Using package sample config: $SAMPLE_CONFIG"
            sudo cp "$SAMPLE_CONFIG" "$OPENSIPS_CONFIG"
        else
            echo "Using existing config or no sample found; will update in place"
        fi
        # Replace DB URL placeholders with our values
        sudo sed -i "s|mysql://.*@.*:.*\/.*|mysql://$DB_USER:$DB_PASS@$DB_HOST:$DB_PORT/$DB_NAME|g" "$OPENSIPS_CONFIG"
        # Replace MI port if present
        sudo sed -i "s/modparam(\"httpd\", \"port\", [0-9]*)/modparam(\"httpd\", \"port\", 8888)/g" "$OPENSIPS_CONFIG"
        # Ensure socket is set for SIP listening
        if ! grep -q "socket=" "$OPENSIPS_CONFIG"; then
            # Add basic socket if not present
            sudo sed -i '1a socket=tcp:127.0.0.1:5060\nsocket=udp:127.0.0.1:5060' "$OPENSIPS_CONFIG"
        fi
            echo "Warning: could not find package sample config; falling back to minimal config"
            # Minimal fallback config
            cat << EOF | sudo tee $OPENSIPS_CONFIG > /dev/null
####### Global Parameters #########

log_level=3
stderror_enabled=no
syslog_enabled=yes
syslog_facility=LOG_LOCAL0

socket=tcp:127.0.0.1:5060
socket=udp:127.0.0.1:5060

####### Modules Section ########

loadmodule "db_mysql.so"
loadmodule "signaling.so"
loadmodule "sl.so"
loadmodule "tm.so"
loadmodule "rr.so"
loadmodule "maxfwd.so"
loadmodule "sipmsgops.so"
loadmodule "uri.so"
loadmodule "textops.so"
loadmodule "usrloc.so"
loadmodule "registrar.so"
loadmodule "auth.so"
loadmodule "auth_db.so"
loadmodule "nathelper.so"
loadmodule "httpd.so"
loadmodule "mi_fifo.so"

####### Module Parameters ########

# Database connection
modparam("db_mysql", "db_url", "mysql://$DB_USER:$DB_PASS@$DB_HOST:$DB_PORT/$DB_NAME")

# User location
modparam("usrloc", "db_mode", 2)
modparam("usrloc", "db_url", "mysql://$DB_USER:$DB_PASS@$DB_HOST:$DB_PORT/$DB_NAME")

# Authentication
modparam("auth_db", "db_url", "mysql://$DB_USER:$DB_PASS@$DB_HOST:$DB_PORT/$DB_NAME")
modparam("auth_db", "calculate_ha1", 1)
modparam("auth_db", "password_column", "password")

# HTTPD for MI interface
modparam("httpd", "port", 8888)

# MI FIFO
modparam("mi_fifo", "fifo_name", "/tmp/opensips_fifo")

####### Main SIP routing logic ########

route {
    # Initial sanity checks
    if (!mf_process_maxfwd_header(10)) {
        sl_send_reply(483, "Too Many Hops");
        exit;
    }

    if (len(msg) >= 2048) {
        sl_send_reply(513, "Message too big");
        exit;
    }

    # Handle OPTIONS requests
    if (is_method("OPTIONS")) {
        sl_send_reply(200, "OK");
        exit;
    }

    # Handle retransmissions
    if (t_check_trans()) {
        t_relay();
        exit;
    }

    # Handle loose routing
    if (loose_route()) {
        if (is_method("BYE|ACK")) {
            setflag(FLT_ACC);
        }
        route(relay);
        exit;
    }

    # Handle REGISTER requests
    if (is_method("REGISTER")) {
        route(register);
        exit;
    }

    # Handle INVITE requests
    if (is_method("INVITE")) {
        route(invite);
        exit;
    }

    # Default routing
    route(default);
}

route[register] {
    # Authenticate user
    if (!www_authorize("\$td", "subscriber")) {
        www_challenge("\$td", "0");
        exit;
    }

    # Check if user is allowed to register
    if (!check_to()) {
        sl_send_reply(403, "Forbidden");
        exit;
    }

    # Save location
    if (!save("location")) {
        sl_reply_error();
    }

    exit;
}

route[invite] {
    # Record routing
    record_route();

    # Loose route handling
    if (loose_route()) {
        route(relay);
        exit;
    }

    # Preloaded route handling
    if (!has_totag()) {
        # Handle initial INVITE
        if (!lookup("location")) {
            sl_send_reply(404, "Not Found");
            exit;
        }
    }

    route(relay);
}

route[default] {
    # Handle other methods
    if (!lookup("location")) {
        sl_send_reply(404, "Not Found");
        exit;
    }

    route(relay);
}

route[relay] {
    # Handle NAT
    if (nat_uac_test(19)) {
        if (is_method("REGISTER|INVITE|ACK|BYE|CANCEL")) {
            nat_uac_fix();
        }
    }

    # Relay the message
    if (!t_relay()) {
        sl_reply_error();
    }

    exit;
}
EOF
        fi
    fi

    echo "Best practice configuration created at $OPENSIPS_CONFIG"
    # Validate configuration
    if ! sudo opensips -c $OPENSIPS_CONFIG >/dev/null 2>&1; then
        echo "❌ Generated OpenSIPS configuration failed validation. Run 'sudo opensips -c $OPENSIPS_CONFIG' to see errors."
        exit 1
    else
        echo "OpenSIPS configuration validated successfully."
    fi
}

# --- Fungsi setup web interface (opsional)
setup_web_interface() {
    if [[ "$INSTALL_WEB" == true ]]; then
        echo "=== Setting up web interface ==="

        # Download and setup OpenSIPS Control Panel
        cd /tmp
        wget https://github.com/OpenSIPS/opensips-cp/archive/master.zip
        unzip master.zip
        sudo mv opensips-cp-master /var/www/html/opensips-cp

        # Configure web interface
        sudo cp /var/www/html/opensips-cp/config/db.inc.php.example /var/www/html/opensips-cp/config/db.inc.php
        sudo sed -i "s/DBUSER/$DB_USER/g" /var/www/html/opensips-cp/config/db.inc.php
        sudo sed -i "s/DBPASS/$DB_PASS/g" /var/www/html/opensips-cp/config/db.inc.php
        sudo sed -i "s/DBNAME/$DB_NAME/g" /var/www/html/opensips-cp/config/db.inc.php

        # Set permissions
        sudo chown -R www-data:www-data /var/www/html/opensips-cp
        sudo chmod -R 755 /var/www/html/opensips-cp

        echo "Web interface installed at http://your-server/opensips-cp"
    fi
}

# --- Parse arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --sip-domain) SIP_DOMAIN="$2"; shift ;;
        --db-pass) DB_PASS="$2"; shift ;;
        --db-engine) DB_ENGINE="$2"; shift ;;
        --no-db) INSTALL_DB=false ;;
        --with-web) INSTALL_WEB=true ;;
        --help)
            echo "OpenSIPS Auto Installer"
            echo ""
            echo "Install OpenSIPS LTS/stable with best practice configuration."
            echo ""
            echo "Options:"
            echo "  --sip-domain <domain>    SIP domain (optional)"
            echo "  --db-pass <password>     Database password (required)"
            echo "  --db-engine <mysql|postgres> Database engine (default: mysql)"
            echo "  --no-db                  Skip database setup"
            echo "  --with-web               Install web interface"
            echo "  --help                   Show this help"
            echo ""
            echo "Example:"
            echo "  bash opensips-installer.sh --db-pass mypassword --sip-domain example.com"
            echo ""
            exit 0 ;;
        *) echo "Unknown argument: $1" && exit 1 ;;
    esac
    shift
done

# --- Validation
if [[ "$INSTALL_DB" == true && -z "$DB_PASS" ]]; then
    echo "❌ Database password is required. Use --db-pass <password>"
    exit 1
fi

# --- Detect OS
OS=$(detect_os)
if [[ "$OS" == "unknown" ]]; then
    echo "❌ Unsupported OS. This script supports Debian/Ubuntu and RedHat-based systems."
    exit 1
fi

echo "OS detected: $OS"

# --- Install dependencies
install_dependencies

# --- Install OpenSIPS
if [[ "$OS" == "debian" ]]; then
    install_opensips_debian
elif [[ "$OS" == "redhat" ]]; then
    install_opensips_redhat
fi

# --- Setup database
if [[ "$INSTALL_DB" == true ]]; then
    setup_database
fi

# --- Create configuration
create_config

# --- Setup web interface
setup_web_interface

# --- Enable and start service
sudo systemctl enable opensips
sudo systemctl start opensips

echo "✅ OpenSIPS installation completed!"
echo "🌐 SIP Server: $SIP_DOMAIN (if configured)"
echo "🗄️  Database: $DB_NAME"
echo "🔐 MI Interface: http://localhost:8888"
if [[ "$INSTALL_WEB" == true ]]; then
    echo "🌐 Web Interface: http://your-server/opensips-cp"
fi
echo ""
echo "📚 Next steps:"
echo "1. Configure your SIP clients to use this server"
echo "2. Add users via MI interface or database"
echo "3. Configure routing rules as needed"