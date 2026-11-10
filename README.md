# ICECROM — AOSP for the Xiaomi Redmi A1 (`ice`)

A custom **Android 15 AOSP ROM** for the Xiaomi Redmi A1 (MediaTek MT6761,
32-bit ARM), built entirely on **GitHub Actions** and flashed through **TWRP**
([icetwrp](https://github.com/WiiUPretendo/icetwrp)).

- **System + product only.** The stock `vendor`, `odm`, `boot`, `dtbo` and
  `super` metadata stay untouched — the ROM reuses the stock Android 12
  vendor exactly as shipped.
- **VNDK 31 snapshot** (`com.android.vndk.v31`) is packed into `system_ext`
  inside `system.img`, so the Android 15 system still provides the libraries
  the stock Android 12 vendor expects (`ro.vndk.version=31` comes from the
  stock vendor build.prop).
- **No kernel build.** `TARGET_NO_KERNEL := true` — the stock `boot.img`
  (recovery-as-boot carrying TWRP) is included in the zip and flashed as-is.
- **AVB disabled at build time.** The zip carries its own `vbmeta`,
  `vbmeta_system` and `vbmeta_vendor` images generated with
  `avbtool --algorithm NONE --flags 3`, which short-circuits all verified-boot
  processing on an unlocked bootloader (no dm-verity, no descriptor checks).

## Requirements

- Xiaomi Redmi A1 (`ice`) with an **unlocked bootloader**
  (`Settings → Developer options → OEM unlocking`, then `fastboot flashing unlock`)
- [icetwrp](https://github.com/WiiUPretendo/icetwrp) flashed to `boot`
  ([twrp-ice-boot.img](https://github.com/WiiUPretendo/icetwrp/releases/download/asd/twrp-ice-boot.img))
- The release zip from this repository's **Releases** page

## Installation

1. Download `icecrom-ice-<run>.zip` (or its `.part*` pieces — see below) to the
   phone.
2. Boot into TWRP (recovery key combo, or `adb reboot recovery`).
3. **Optional but recommended:** `Wipe → Format Data` (type `yes`) if you are
   coming from a heavily modified ROM or if the ROM does not boot — see
   *Known risks* below.
4. Install the zip in TWRP (Swipe to confirm flash). The updater:
   - grows the `system` / `product` logical partitions if needed (using free
     space in the super partition group),
   - streams `system.img` and `product.img` into them and verifies every write
     (byte count + ext4 magic read back from the device),
   - writes the three flags-3 `vbmeta` images,
   - flashes `boot` **last** — this replaces TWRP with the stock boot image.
5. Reboot. The device boots the new system with the stock kernel/ramdisk.

### Re-entering TWRP afterwards

Because the zip restores the stock `boot.img`, TWRP is gone after flashing.
To get it back (any time):

```sh
fastboot flash boot twrp-ice-boot.img
```

### If the zip was split (larger than 2 GB)

GitHub release assets are limited to 2 GB, so big zips are shipped as
`icecrom-ice-<run>.zip.part00`, `.part01`, … Reassemble **before** copying to
the phone (or on the phone with a file manager that supports concatenation):

```sh
cat icecrom-ice-<run>.zip.part* > icecrom-ice-<run>.zip
```

The parts are ordered by their numeric suffix, so plain `cat` is safe.

## Building

Everything runs in GitHub Actions — no local Linux required.

1. Fork this repository.
2. (Optional) set the repository variable `AOSP_TAG` — defaults to
   `android15-release`. `android-16*` / `android-17*` tags are also wired up
   (JDK 21 is installed automatically for Android 17).
3. Push a change under `device/`, `scripts/`, `META-INF/`, `tools/` or
   `.github/workflows/` (or run the workflow manually via *Actions → ICECROM
   build → Run workflow*).
4. The job: frees runner disk, enables a 24 GB swap file, shallow-syncs AOSP
   (3 retry attempts), guarantees `prebuilts/vndk/v31`, prunes
   `cts development pdk test prebuilts/{fullsdk-*,ndk,abi-dumps,vndk/v29,v30,v32,v33,v34}`
   and `.repo`, runs `lunch aosp_ice-userdebug && m systemimage productimage`,
   packages the zip (`scripts/package_zip.sh`), verifies the images with
   `debugfs` (`/bin/init`, `/system_ext`, the VNDK 31 APEX, the
   `ro.icecrom.build=1` marker, ext4 magic), and publishes a
   `build-<run>` GitHub release.
5. On failure, the raw `build.log` is uploaded as an artifact.

### Repository layout

```
device/xiaomi/ice/          device tree (aosp_ice.mk, BoardConfig.mk, device.mk)
scripts/package_zip.sh      image verification + vbmeta generation + zip assembly
META-INF/com/google/android/  TWRP updater (update-binary runs on-device)
tools/lptools_static        logical-partition tool bundled into the zip
.github/workflows/build.yml the entire build pipeline
aosp/                       AOSP checkout (created by CI, git-ignored)
```

## How the flash works (on-device)

The updater (`#!/sbin/sh`, TWRP's mksh) runs with the zip path as `$3`:

1. Finds the partition nodes (`/dev/block/platform/bootdevice/by-name`, with a
   `/dev/block/by-name` symlink fallback for `lptools`), determines the slot
   from `ro.boot.slot_suffix` (or `/proc/cmdline`), and extracts
   `images.txt` + `lptools_static`.
2. Unmounts `/system`, `/vendor`, `/product`, … (**never `/data`**).
3. For `system` and `product`: resolves the logical partition name
   (`system_a` → `system` probe), maps it writable, grows it with
   `lptools free/resize` when the image is larger than the current logical
   size, then `unzip -p … | dd` and verifies the byte count against
   `images.txt` plus the ext4 magic (`53ef` at offset 1080) read back from
   the device.
4. Writes `vbmeta`, `vbmeta_system<slot>`, `vbmeta_vendor<slot>` (each a
   4096-byte, algorithm-NONE, flags-3 image) and finally `boot<slot>`.
5. `sync` and exits 0 (INSTALL_SUCCESS).

## Known risks / notes

- **FBE & the beanpod TEE.** The stock userdata is FBE v2
  (`fileencryption=…,keydirectory=/metadata/vold/metadata_encryption`) keyed
  through the stock beanpod keymaster. Android 15's keystore2 talks to it
  through the stock vendor HAL; if first boot loops in encryption, boot to
  TWRP, **Format Data** and retry (this wipes `/data`).
- **A15 system + A12 vendor sepolicy.** Expected to boot like a GSI on an
  Android 12 vendor (the gsi-style system_ext properties disable privapp
  permission enforcement and RescueParty to smooth this over), but oddities
  with vendor HALs are possible and will be iterated on device.
- **Dexpreopt policy.** Only the ART boot image is preopted at build time;
  per-app odex/vdex files are left out of `system.img` (this keeps the
  image small enough for the device's super free space and the CI disk
  budget). Apps are dexopted on-device as usual, so expect a slower first
  boot and background optimization (`bg-dexopt`) afterwards.
- **SELinux** runs per the stock boot image's policy (the TWRP image's
  permissive cmdline is *not* used after flashing, because the stock
  `boot.img` is what gets written).
- `ro.icecrom.build=1` marks this ROM (`getprop ro.icecrom.build`).
- After flashing, TWRP is replaced — see *Re-entering TWRP* above.

## Credits

- [icetwrp](https://github.com/WiiUPretendo/icetwrp) — TWRP device tree used
  as the base for partition layout and board configuration
- [AnyKernel3](https://github.com/osm0sis/AnyKernel3) — source of the bundled
  `lptools_static`
- [gudang-dump/redmi_ice_dump](https://github.com/gudang-dump/redmi_ice_dump) —
  stock dump used for reference (fstab, boot image, vendor props)
- The Android Open Source Project
