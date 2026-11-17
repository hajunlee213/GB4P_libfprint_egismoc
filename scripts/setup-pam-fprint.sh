#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo "=== PAM fingerprint (fprintd) retry count and timeout tuning ==="

# Check for root
if [ "$EUID" -ne 0 ]; then
    echo "[ERROR] This script must be run as root (sudo)." >&2
    exit 1
fi

PAM_SRC="${PROJECT_ROOT}/configs/pam/fprintd"
PAM_DEST="/usr/share/pam-configs/fprintd"

if [ ! -f "${PAM_SRC}" ]; then
    echo "[ERROR] PAM config template not found: ${PAM_SRC}" >&2
    exit 1
fi

echo "-> /usr/share/pam-configs/fprintd updated (max-tries=3, timeout=30)..."
cp "${PAM_SRC}" "${PAM_DEST}"
chmod 644 "${PAM_DEST}"

echo "-> Running pam-auth-update to refresh /etc/pam.d/common-auth..."
pam-auth-update --package

echo "[SUCCESS] PAM fprintd configured (max 3 tries, 30 s timeout)!"
