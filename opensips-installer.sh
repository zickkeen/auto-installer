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
    curl -s https://apt.opensips.org/opensips-org.gpg -o /usr/share/keyrings/opensips-org.gpg
    echo "deb [signed-by=/usr/share/keyrings/opensips-org.gpg] https://apt.opensips.org $DISTRO_CODENAME $OPENSIPS_VERSION-releases" | sudo tee /etc/apt/sources.list.d/opensips.list

    sudo apt update
    sudo apt install -y opensips opensips-mysql-module opensips-postgres-module opensips-unixodbc-module

    # Install additional modules
    sudo apt install -y opensips-http-modules opensips-json-modules opensips-xml-modules opensips-tls-modules
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
    sudo -u opensips opensipsdbctl create $DB_NAME
}

# --- Fungsi create best practice configuration
create_config() {
    echo "=== Creating best practice configuration ==="

    OPENSIPS_CONFIG="/etc/opensips/opensips.cfg"

    # Backup existing config
    if [[ -f "$OPENSIPS_CONFIG" ]]; then
        sudo cp $OPENSIPS_CONFIG $OPENSIPS_CONFIG.backup
    fi

    # Create new configuration with best practices
    cat << EOF | sudo tee $OPENSIPS_CONFIG > /dev/null
####### Global Parameters #########

log_level=3
log_stderror=no
log_facility=LOG_LOCAL0

children=4
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
loadmodule "rtpproxy.so"
loadmodule "dispatcher.so"
loadmodule "load_balancer.so"
loadmodule "permissions.so"
loadmodule "pike.so"
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

# Dispatcher
modparam("dispatcher", "db_url", "mysql://$DB_USER:$DB_PASS@$DB_HOST:$DB_PORT/$DB_NAME")
modparam("dispatcher", "table_name", "dispatcher")
modparam("dispatcher", "setid_col", "setid")
modparam("dispatcher", "destination_col", "destination")
modparam("dispatcher", "flags_col", "flags")
modparam("dispatcher", "priority_col", "priority")
modparam("dispatcher", "attrs_col", "attrs")

# Load balancer
modparam("load_balancer", "db_url", "mysql://$DB_USER:$DB_PASS@$DB_HOST:$DB_PORT/$DB_NAME")

# Permissions
modparam("permissions", "db_url", "mysql://$DB_USER:$DB_PASS@$DB_HOST:$DB_PORT/$DB_NAME")

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

    if (msg:len >= 2048) {
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
    if (!www_authorize("$td", "subscriber")) {
        www_challenge("$td", "0");
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

        # Apply load balancing if configured
        if (!load_balance("1", "pstn")) {
            sl_send_reply(503, "Service Unavailable");
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

    echo "Best practice configuration created at $OPENSIPS_CONFIG"
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