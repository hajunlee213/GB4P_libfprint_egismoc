# GB4P libfprint egismoc (1c7a:05a1) SDCP patch

[**English**](README.md) | [한국어](README.ko.md)

An SDCP patch for libfprint's `egismoc` driver on the Galaxy Book4 Pro (Egis `1c7a:05a1`, ETU905A80-E), plus the built library, restore scripts, and working notes.

> **Status: archived, no longer maintained.**
> I use the fingerprint reader only on Windows with the stock driver. On Ubuntu I use another quick-login method instead (biopass face recognition).
> This repo was split out of [GB4P_ubuntu_my_preferences](https://github.com/hajunlee213/GB4P_ubuntu_my_preferences); the git history of these files is preserved there.

## Sources

- Code base: [TenSeventy7/libfprint-egismoc-sdcp](https://github.com/TenSeventy7/libfprint-egismoc-sdcp) `master` (`4d128d4`)
- Full patched source: [hajunlee213/libfprint-egismoc-sdcp `gb4p-05a1-sdcp-v2`](https://github.com/hajunlee213/libfprint-egismoc-sdcp/tree/gb4p-05a1-sdcp-v2) (commit `b7f55ff`)
- Install script reference: [antoskuu/libfprint-egismoc-sdcp-fix](https://github.com/antoskuu/libfprint-egismoc-sdcp-fix)
- My 05a1 observations, shared upstream: [TenSeventy7/libfprint-egismoc-sdcp PR #17](https://github.com/TenSeventy7/libfprint-egismoc-sdcp/pull/17#issuecomment-6913965276)

## Patch summary (v2)

`gb4p-05a1-sdcp-v2.patch` (apply on top of `4d128d4` with `git am`):

1. `fpi-sdcp-device.c`: keep the cached host key across reboots instead of discarding it. On the 05a1, a new key makes the enrolled fingerprint count read as 0.
2. `fpi-sdcp-device.c`: always set `is_connected = FALSE` when loading the cache, so every open performs a fresh `SDCP Connect` with the same key. This avoids `65 E0` after lock or suspend.
3. `egismoc.c`: set `claim_expiration_seconds = -1` so the key is not regenerated after 24 hours. This is a stopgap.
4. `egismoc.c`: free the leftover `task_ssm` in `egismoc_close()`. This works around fprintd crashing after an authentication is cancelled. See PR #17 for the root-cause fix.

The idea that the 05a1 binds fingerprint templates to the host key is inferred from test results, not confirmed from the firmware.

## Contents

| Path | Description |
| :--- | :--- |
| `gb4p-05a1-sdcp-v2.patch` | Final patch against the source tree (`git format-patch`) |
| `libfprint_egismoc_full_fix.patch` | The v2 patch (same changes as above) |
| `libfprint_egismoc_sdcp_reboot_fix.patch` / `.md` | Reboot fix patch and its write-up |
| `libfprint_egismoc_assert_fix.patch` | `task_ssm` assert fix patch |
| `usable_SDCP_versions_README.md` | Differences between v1 and v2 |
| `configs/libfprint/libfprint-2.so.2.0.0` | Built v2 binary. Source: fork branch `gb4p-05a1-sdcp-v2` (`b7f55ff`) |
| `configs/pam/fprintd` | PAM profile (`max-tries=3 timeout=30`) |
| `fingerprint_setup.sh` (+ `_README.md`) | Installs the patched library and PAM profile; `--restore` returns to stock |
| `pam_fprint_tuning.sh` (+ `_README.md`) | Applies the PAM options only |
| `scripts/` | Helper scripts called by the scripts above |
| `archive/agy-workdir/` | Notes and patches from the original agy session (`error_progress.md`, v1 patch, etc.) |
| `src/` (git-ignored) | Local source trees: `libfprint-egismoc-sdcp` (branch `gb4p-05a1-sdcp-v2`) and `libfprint-egismoc-sdcp-fix` |

## Usage

Install:

```bash
sudo ./fingerprint_setup.sh
```

Restore stock libfprint (removes the patched library and releases the `libfprint-2-2` hold):

```bash
sudo ./fingerprint_setup.sh --restore
```

`--restore` only removes the copy in `/usr/local/lib`. If you previously ran `meson install` from a source tree and overwrote the packaged files in `/usr/lib`, reinstall the package to get back to stock:

```bash
sudo apt install --reinstall libfprint-2-2
```

## Rebuilding from source

`src/libfprint-egismoc-sdcp` was moved, so the absolute paths in its old `builddir` no longer match. Reconfigure from scratch:

```bash
cd src/libfprint-egismoc-sdcp
meson setup --wipe builddir -Ddrivers=egismoc -Ddoc=false -Dgtk-examples=false
ninja -C builddir
```

If linking fails with OpenSSL symbol errors, add `'egismoc' : [ 'openssl' ],` to `driver_helper_mapping` in `meson.build` (the same fix antoskuu's `install.sh` applies). I have not verified a rebuild since the folder move.

To start from a fresh checkout:

```bash
git clone https://github.com/TenSeventy7/libfprint-egismoc-sdcp.git
cd libfprint-egismoc-sdcp && git checkout 4d128d4
git am /path/to/gb4p-05a1-sdcp-v2.patch
```

## License

The whole repository (patches, built binary, scripts, docs) is released under the **GNU LGPL v2.1 or later** (`LGPL-2.1-or-later`). The full text is in [`COPYING`](COPYING).

- The patches and `configs/libfprint/libfprint-2.so.2.0.0` are modified versions of libfprint (LGPL-2.1-or-later, copyright held by the original authors).
- Complete source for the binary: <https://github.com/hajunlee213/libfprint-egismoc-sdcp/tree/gb4p-05a1-sdcp-v2> (`b7f55ff`, a single commit on top of upstream `4d128d4`).
- Changes and their dates are described in "Patch summary" above and in the git history.
- Code from antoskuu/libfprint-egismoc-sdcp-fix is not included (link only).
