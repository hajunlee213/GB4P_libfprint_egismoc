#!/usr/bin/env bash
set -euo pipefail

echo "=== Rolling back the Egis SDCP patched driver to stock ==="

if [ "$EUID" -ne 0 ]; then
    echo "[ERROR] This script must be run as root (sudo)." >&2
    exit 1
fi

LIB_DIR="/usr/local/lib/x86_64-linux-gnu"

echo "-> Removing custom libfprint files from /usr/local/lib..."
rm -f "${LIB_DIR}/libfprint-2.so"*

echo "-> Releasing the hold on the libfprint-2-2 package..."
apt-mark unhold libfprint-2-2 >/dev/null || true

echo "-> Refreshing ldconfig..."
ldconfig

echo "-> Clearing the SDCP cache and restarting fprintd..."
rm -f /var/lib/fprint/sdcp-claim-*
systemctl restart fprintd.service || true

echo "[SUCCESS] Restored to the stock libfprint driver!"
