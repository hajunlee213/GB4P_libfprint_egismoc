# Fingerprint Sensor (EgisTec 1c7a:05a1) Troubleshooting Progress Report

## Overview
- **Target device**: Samsung Galaxy Book 4 Pro/Ultra (USB ID: `1c7a:05a1`, LighTuning Technology Inc. ETU905A80-E)
- **Base project**: [TenSeventy7's libfprint-egismoc-sdcp](https://github.com/TenSeventy7/libfprint/tree/egismoc-sdcp)
- **Current symptoms**:
  - Enrolling a fingerprint with `fprintd-enroll` completes, but authentication with `fprintd-verify` right afterwards fails immediately (or does not match), and the fingerprint data stored inside the device is deleted straight away.

## Progress so far and root-cause analysis

### 1. `fprintd-verify` terminates immediately (fixed, then rolled back)
- **Symptom**: Running `fprintd-verify` returned `verify-no-match` (or abort) and exited right away, before the sensor was touched.
- **Cause**: When the number of fingerprints was queried with `cmd_list`, the device returned 0, so `fprintd-verify` terminated abnormally with `FP_DEVICE_ERROR_DATA_NOT_FOUND`. In other words, the fingerprint had not been committed to the device's internal storage during the enroll step.

### 2. Hardware `65 E0` error (fixed, then rolled back)
- **Symptom**: Log analysis showed the device returning error code `65 E0` for `cmd_new_print_prefix` (the command that saves the fingerprint) in the last step of `enroll`.
- **Cause and action**:
  1. **Ghost touch**: The first `enroll` step passed even though the sensor had not been touched. A leftover interrupt signal from earlier (`90 00 90 00`) stayed in the USB buffer and was read immediately, capturing a blank image. (Fixed by patching in a 100 ms timeout so leftover packets are ignored.)
  2. **Acer-specific command conflict**: The SDCP fork author (TenSeventy7) added `cmd_capture_post_wait_finger` (`50 7a`), which resets the sensor right after capture, for Acer (`0583`) devices. On the Samsung (`05a1`) device it may be clearing the buffer and making every captured image blank. (Patched to skip this command on `05a1`.)
- **Result**: With these patches, `fprintd-enroll` correctly waited for 10 real finger touches, and `verify` also waited for a touch.

### 3. Open issue: fingerprint deleted automatically after Verify
- **Symptom**: `verify` now waits for a touch, but it still returns `verify-no-match`, and the fingerprint is deleted from the device right afterwards (a `NoEnrolledPrints` error appears).
- **Suspected causes**:
  - **SDCP HMAC hash generation format**: Functions such as `fpi_sdcp_generate_enrollment_id` use `sizeof("enroll")` when generating the HMAC signature, so the `\0` (null terminator) is included in the hash. If the device firmware does not expect the null character, it may treat this as an `Enrollment ID` mismatch or integrity error and invalidate the fingerprint internally.
  - **Small 05a1-specific protocol differences**: The `cmd_new_print_prefix` command bytes and similar may need extra TYPE2-only bytes (such as `0x80`) that are specific to Samsung devices.

## Rollback record (2026-09-19)
As the session grew long, to re-analyze from scratch I **removed all custom patches applied so far**, **fully rolled back the repository to the initial state from GitHub (TenSeventy7) (`git reset --hard`, `git clean -fd`), and rebuilt it**.

- **Working directory**: `/home/hajun/.gemini/antigravity/scratch/libfprint-egismoc-sdcp/`
- **State**: Restored to the original TenSeventy7 `egismoc-sdcp` branch source.

---
**Recommended next steps for the next session:**
1. From the rolled-back stock state, verify the SDCP HMAC generation logic (`sizeof` -> `strlen`).
2. Analyze the exact SDCP payloads of the `EnrollCommit` and `Identify` steps of the `05a1` on Windows to confirm the protocol differences.
