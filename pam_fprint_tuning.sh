#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "========================================================="
echo " Galaxy Book 4 Pro (GB4P) PAM fingerprint (fprintd) option tuning"
echo " (max-tries=3, timeout=30)"
echo "========================================================="

# Check for root
if [ "$EUID" -ne 0 ]; then
    echo "[!] Root privileges required. Re-running with sudo..."
    exec sudo bash "$0" "$@"
fi

# 1. Update the PAM fprintd profile and common-auth
bash "${SCRIPT_DIR}/scripts/setup-pam-fprint.sh"

echo ""
echo "========================================================="
echo " [SUCCESS] PAM fingerprint option tuning complete!"
echo "========================================================="
echo " 1. /usr/share/pam-configs/fprintd: max-tries=3 timeout=30"
echo " 2. /etc/pam.d/common-auth: pam-auth-update refreshed"
echo "========================================================="
