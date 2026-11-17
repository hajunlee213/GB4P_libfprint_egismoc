# Fingerprint Sensor Driver & PAM One-Click Restore (`fingerprint_setup.sh`)

This script restores, in one step, the **SDCP Version 2 driver** and the **PAM tuning (3 tries / 30 s)** that fix the following problems on the fingerprint sensor of the Samsung Galaxy Book 4 Pro (NT960XGK / Egis `1c7a:05a1`): enrolled fingerprints lost on reboot, the sensor dying after screen lock or suspend resume (`65 E0`), and `fprintd` daemon crashes.

---

## 1. Background and purpose

The EgisTec MoC fingerprint sensor (`1c7a:05a1`) in the Galaxy Book 4 Pro talks to the host over an encrypted channel using SDCP (Secure Device Connection Protocol). Stock Ubuntu and the default open-source driver have several serious problems with it:

1. **Enrolled fingerprints lost on reboot (host key discard bug)**:
   - When the driver sees the kernel `boot_id` change, it deletes the cached host key and generates a new one.
   - The sensor cryptographically binds fingerprint templates to the host key, so when the key changes it treats the host as a new owner and refuses access to the existing fingerprints.
2. **Sensor dead after screen lock / suspend resume (`65 E0` error)**:
   - When the screen turns off or USB enters power saving, the sensor hardware loses its own session.
   - The driver assumes the previous session is still alive, tries to talk over it, and hits a mismatch error.
3. **`fprintd` daemon crash after cancellation (resource leak)**:
   - If the screen turns off or the attempt is cancelled mid-authentication, the state machine (`task_ssm`) is not cleaned up, and the daemon exits abnormally on the next fingerprint request.
4. **Harsh default PAM limits on Ubuntu**:
   - The stock Ubuntu package, to cut waiting in terminals, falls back to the password after a single failed attempt and times out after 10 seconds.

---

## 2. System paths modified or created

| Path | Role | Change |
| :--- | :--- | :--- |
| `configs/libfprint/libfprint-2.so.2.0.0` | Version 2 patched binary in this repo | Patched shared library build |
| `/usr/local/lib/x86_64-linux-gnu/libfprint-2.so*` | Install location on the system | Patched library and symlinks are deployed here |
| `libfprint-2-2` (apt package) | Package version pin | `apt-mark hold` blocks upgrades; `--restore` runs `unhold` |
| `configs/pam/fprintd` | PAM profile template in this repo | `pam_fprintd.so max-tries=3 timeout=30` |
| `/usr/share/pam-configs/fprintd` | System PAM profile | Updated to `max-tries=3 timeout=30` |
| `/etc/pam.d/common-auth` | Common PAM stack | 3 tries and 30 s wait applied automatically |
| `/var/lib/fprint/sdcp-claim-*` | Session key cache | Cleared on reboot/reset to drop the old volatile session |

---

## 3. Key parameters and how they work (Version 1 vs Version 2)

### Version 1 (reboot baseline)
* **Keep the host key permanently**: removed the logic that deletes the cached key on a `boot_id` mismatch.
* **No expiry**: `claim_expiration_seconds = -1` (prevents the 24-hour automatic expiry).
* *Limits*: it still tried to reuse the session after resume, so `65 E0` errors remained, and cancelling an authentication could still crash the daemon.

### Version 2 (current, in daily use: full fix)
* **`task_ssm` leak fix (`egismoc.c`)**:
  * `egismoc_close` now forces `fpi_ssm_free` and resets the pointer to `NULL` if a state machine is left over, which stops the daemon crash.
* **Forced SDCP reconnect (`fpi-sdcp-device.c`)**:
  * Always sets `priv->is_connected = FALSE` when loading the cache.
  * Every time `fprintd` wakes up (screen unlock, resume from suspend), it keeps the preserved host key but **always negotiates a new secure session (`SDCP Connect`)**, which resolves the sensor "amnesia" problem.
* **PAM 3 tries / 30 s timeout**:
  * A slightly off touch or a bad finger angle can be retried up to three times.

---

## 4. Requirements and dependencies

* **Packages**: `fprintd`, `libpam-fprintd` (installed automatically when the script runs)
* **Hardware**: Egis MoC sensor (`1c7a:05a1`, etc.)
* **Privileges**: root (`sudo`)

### Package hold (`libfprint-2-2`)
* The patched library is installed separately in `/usr/local/lib/x86_64-linux-gnu/`, and the dynamic linker searches this path before `/usr/lib/…`. So `apt upgrade` does not overwrite the patched library.
* The hold blocks upgrades of the stock `libfprint-2-2` package. If upstream changes the ABI, the patched library could stop matching `fprintd`, and the hold prevents that. The side effect is that security updates for this package are blocked too.
* Version the patched build is based on: `libfprint-2-2 1:1.95.1+tod1-0ubuntu2`
* To move to a newer version: `sudo apt-mark unhold libfprint-2-2 && sudo apt upgrade`, then rebuild the patch against the new version and run `sudo ./fingerprint_setup.sh` to hold again.
* Check: `apt-mark showhold`

---

## 5. Running and using it

### One-click restore
```bash
sudo ./fingerprint_setup.sh
```

### Enroll and test a fingerprint
```bash
# Enroll a new fingerprint (touch the sensor repeatedly as prompted)
fprintd-enroll

# List enrolled fingerprints
fprintd-list $USER

# Test fingerprint authentication
fprintd-verify
```

---

## 6. Rolling back to stock

```bash
sudo ./fingerprint_setup.sh --restore
```
* Removes `/usr/local/lib/x86_64-linux-gnu/libfprint-2.so*` and runs `ldconfig`, immediately falling back to the Ubuntu package's `libfprint-2.so`.
* Releases the hold on the `libfprint-2-2` package.
* Resets PAM to the stock Ubuntu defaults (`max-tries=1 timeout=10`).
