# Usable SDCP Versions Summary

This document records the features and differences of the main patch versions of the fingerprint driver for the Samsung Galaxy Book 4 Pro/Ultra (Egis 1c7a:05a1) that were usable in daily life.

## Version 1 (2026-09-20)
- **Location**: `archive/agy-workdir/usable_SDCP_version1.patch`
- **Background**: The first usable baseline patch. On top of the original driver, it was the first to get fingerprint enrollment (Enroll), authentication (Verify), PAM integration, and fingerprint retention across reboots (warm/cold) working.
- **Summary of main changes**:
  1. **Keep the host key permanently (`fpi-sdcp-device.c`)**
     - **Problem**: When the original SDCP driver saw the Linux kernel `boot_id` change at reboot, it discarded the existing cache and generated a new host key. But the sensor (Egis 05a1) cryptographically binds fingerprint templates to the host key, so with a new key it treated the host as a new owner, refused access to the existing fingerprints, and answered "0 enrolled fingerprints" (after which fprintd even deleted the local fingerprints automatically).
     - **Fix**: Removed the logic that deletes the cache and generates a new key on a `boot_id` mismatch (`delete_cached_claim`, `goto generate_new`), so the host's cryptographic identity (host key) is preserved.
  2. **Re-establish the session when a reboot is detected (`fpi-sdcp-device.c`)**
     - **Problem**: The sensor chipset itself loses its internal session when power is cut, so after a reboot a new secure channel (`SDCP Connect`) had to be established.
     - **Fix**: When `cached_boot_id` differs from the current `boot_id`, set `priv->is_connected = FALSE` so the driver opens a new session with the sensor using the preserved host key. (Within the same boot it stays `TRUE` and reuses the existing session.)
  3. **No session expiry (`egismoc.c`)**
     - **Problem**: A hard-coded 24-hour (86400 s) expiry timer discarded the session key after a day.
     - **Fix**: Changed to `claim_expiration_seconds = -1`, which disables the expiry timer.
- **Limits (what led to Version 2)**:
  - Within the same boot it reused the session with `is_connected = TRUE`, but after suspend, screen lock, or a USB reset the sensor forgot the session on its own, which still caused authentication mismatches (`65 E0`).
  - Cancelling a fingerprint authentication left `task_ssm` unreleased and crashed `fprintd`.

## Version 2 (2026-09-28)
- **Location**: `gb4p-05a1-sdcp-v2.patch` (patch) and `configs/libfprint/libfprint-2.so.2.0.0` (compiled binary)
- **Summary of main changes**:
  1. **Prevent fprintd crashes (fix the `task_ssm` leak)**
     - **Problem**: If an identification (Identify) was cancelled or the screen turned off mid-way, the old driver did not clean up its internal state machine (`task_ssm`), and `fprintd` crashed on the next use. This was a long-standing bug.
     - **Fix**: In `egismoc_close`, if `task_ssm` is left over, it is freed forcibly (`fpi_ssm_free`) and reset to `NULL`, which stops the daemon from crashing.
  2. **Forced SDCP reconnect (handles sensor amnesia / timeouts)**
     - **Problem**: Version 1 reused the existing session if there had been no reboot. But a USB reset (re-initialization) or hardware power saving (timeout) while the screen was locked or the machine was idle made the sensor erase its session key on its own. The daemon still believed the session was alive, which produced the `65 E0` error.
     - **Fix**: When loading the cache, `priv->is_connected = FALSE` is now always set. Every time `fprintd` wakes up (each time the screen is turned on), it keeps the existing host key but **always opens a new secure session (`SDCP Connect`)**, which fixes the session mismatch with the sensor.
