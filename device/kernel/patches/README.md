# Kernel patches

These patches are saved here so they can be reused without downloading them again. No build step applies them yet.

| File | Target | Source | SHA-256 |
|------|--------|--------|---------|
| `linux/0001-cpr.patch` | Linux 6.12.1 (applied by step 21). It is experimental, controls CPU voltage, and is not tested on the device. | Mio-sha512/OpenStick-Kernel-Compiler, `device/kernel/patches/cpr-6.12.1.patch` | `7785f46eb574ce2db55d89f79567a08fd0594d756a625127c580abb449e71b60` |
| `linux/0001-le9uo.patch` | Linux 6.12.118 (applied by step 21). Rebased from 6.12.1: one hunk in `mm/vmscan.c` changed. | sirlucjan/kernel-patches, `6.12/le9uo-patches/0001-mm-6.12-add-le9uo.patch` (base) | `d99d4a9893e349d293b1c1722fcdf8b9767fb53f2e4bad391a0fb01a22cb3f83` |
| `linux/0001-zstd-cachyos.patch` | Linux 6.12.118 (applied by step 21). Applies cleanly. | CachyOS/kernel-patches, `6.12/0007-zstd.patch` | `d1659eb3e4370a9eef0f79ced5761163d625f4946d47f4294a3be67823416793` |
| `linux/0001-smsm-skip-empty-mboxes.patch` | Linux 6.12.118 (applied by step 21, `PATCH_SMSM`). Skips `mboxes` entries that are empty (phandle 0), so the SMSM driver does not print `can't parse "mboxes" property` at boot. | Written for this repo: `drivers/soc/qcom/smsm.c`, `smsm_parse_mbox()`. | `c8f5934eb8684506181b49e1a83e083fee26158e13d17dfad33a4a01cadfbd82` |
| `linux/0001-tcp-bbr3-initial-import.patch` | Linux 6.12.118 (applied by step 21). Applies cleanly. | CachyOS/kernel-patches, `6.12/0002-bbr3.patch` | `15d1563b4696ee35455f02b21fad0508fb77e0364f8dd1f48e0e82671dd05299` |

Notes:
- The CPR patch does not apply to the pinned 6.6 tree. Four files fail.

Check a file before use:

```sh
sha256sum -c <<'EOF'
7785f46eb574ce2db55d89f79567a08fd0594d756a625127c580abb449e71b60  device/kernel/patches/linux/0001-cpr.patch
EOF
```
