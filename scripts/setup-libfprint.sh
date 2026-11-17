#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo "=== [1/2] Restoring the Egis SDCP fingerprint patched driver (v2) ==="

if [ "$EUID" -ne 0 ]; then
    echo "[ERROR] This script must be run as root (sudo)." >&2
    exit 1
fi

LIB_SRC="${PROJECT_ROOT}/configs/libfprint/libfprint-2.so.2.0.0"
LIB_DIR="/usr/local/lib/x86_64-linux-gnu"
LIB_DEST="${LIB_DIR}/libfprint-2.so.2.0.0"

# 1. Check for and install required packages
if ! dpkg -s libpam-fprintd fprintd &>/dev/null; then
    echo "-> Installing required packages (fprintd, libpam-fprintd)..."
    apt-get update -qq
    apt-get install -y -qq fprintd libpam-fprintd
fi

# 2. Deploy the prebuilt Version 2 patched binary
if [ ! -f "${LIB_SRC}" ]; then
    echo "[ERROR] Patched library binary not found: ${LIB_SRC}" >&2
    exit 1
fi

echo "-> Installing the patched libfprint library (${LIB_DEST})..."
mkdir -p "${LIB_DIR}"
cp "${LIB_SRC}" "${LIB_DEST}"
chmod 755 "${LIB_DEST}"

# Create symlinks
ln -sf libfprint-2.so.2.0.0 "${LIB_DIR}/libfprint-2.so.2"
ln -sf libfprint-2.so.2 "${LIB_DIR}/libfprint-2.so"

echo "-> Refreshing ldconfig..."
ldconfig

# 3. Pin the stock libfprint package (keeps apt from pulling in a newer ABI that no longer matches the patched build)
echo "-> Holding the libfprint-2-2 package..."
apt-mark hold libfprint-2-2 >/dev/null

# 4. Clear the old SDCP session cache
echo "-> Clearing the previous SDCP session claim cache..."
rm -f /var/lib/fprint/sdcp-claim-*

# 5. Restart the fprintd service
echo "-> Restarting the fprintd service..."
systemctl restart fprintd.service || true

echo "[SUCCESS] Egis SDCP patched driver (v2) installed and applied!"
