#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "========================================================="
echo " Galaxy Book 4 Pro (GB4P) fingerprint driver & PAM one-click restore"
echo " (Egis 1c7a:05a1 SDCP v2 + PAM 3 tries / 30 s tuning)"
echo "========================================================="

# Check for root and escalate automatically
if [ "$EUID" -ne 0 ]; then
    echo "[!] Root privileges required. Re-running with sudo..."
    exec sudo bash "$0" "$@"
fi

# Handle the rollback option
if [ "${1:-}" = "--restore" ] || [ "${1:-}" = "--uninstall" ]; then
    bash "${SCRIPT_DIR}/scripts/restore-libfprint.sh"
    # Restore stock PAM (1 try / 10 s)
    sed -i 's/pam_fprintd\.so.*/pam_fprintd.so max-tries=1 timeout=10 # debug/' /usr/share/pam-configs/fprintd || true
    pam-auth-update --package || true
    echo "[SUCCESS] Fingerprint driver and PAM settings rolled back to stock."
    exit 0
fi

# 1. Restore the libfprint SDCP Version 2 patched driver
bash "${SCRIPT_DIR}/scripts/setup-libfprint.sh"
echo ""

# 2. Restore the PAM fingerprint options (3 tries, 30 s wait)
bash "${SCRIPT_DIR}/scripts/setup-pam-fprint.sh"
echo ""

echo "========================================================="
echo " [SUCCESS] Fingerprint sensor and PAM settings restored!"
echo "========================================================="
echo " 1. Egis SDCP patched driver (v2):"
echo "    - Host key kept permanently: enrolled fingerprints survive reboots"
echo "    - fprintd crash fix: task_ssm leak resolved, no more abnormal daemon exits"
echo "    - Forced SDCP reconnect: fixes sensor amnesia (65 E0) after suspend/screen lock"
echo "    - No session expiry: session no longer discarded after 24 hours"
echo " 2. PAM tuning:"
echo "    - Max tries: 3 (Ubuntu default 1 -> 3)"
echo "    - Timeout: 30 s (Ubuntu default 10 s -> 30 s)"
echo "========================================================="
echo " 🚀 Usage:"
echo " - Enroll a new fingerprint: fprintd-enroll"
echo " - List enrolled fingerprints: fprintd-list \$USER"
echo " - Test fingerprint authentication: fprintd-verify"
echo " - Roll back to stock: sudo ./fingerprint_setup.sh --restore"
echo "========================================================="
