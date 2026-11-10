#!/usr/bin/env bash
# package_zip.sh - verify the built images, generate the flags-3 vbmeta
# images and assemble the TWRP flashable zip.
#
# Output: dist/icecrom-ice-<run>.zip (split into <2 GiB parts if needed)
#         dist/images-size.txt
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/aosp/out/target/product/ice"
DIST="$ROOT/dist"
WORK="$DIST/pkg"
AVBTOOL="$ROOT/aosp/external/avb/avbtool.py"
PREBUILT_BOOT="$ROOT/device/xiaomi/ice/prebuilt/boot.img"
LPTOOLS="$ROOT/tools/lptools_static"
ZIPNAME="icecrom-ice-${GITHUB_RUN_NUMBER:-local}.zip"

log()  { echo "[package] $*"; }
die()  { echo "[package] ERROR: $*" >&2; exit 1; }

mkdir -p "$DIST" "$WORK"

# --- image helpers ---------------------------------------------------------
is_sparse() {
  local m
  m="$(od -An -tx1 -N4 "$1" | tr -d ' \n')"
  [ "$m" = "3aff26ed" ]
}

raw_ext4_ok() {
  local m
  m="$(dd if="$1" bs=1 skip=1080 count=2 2>/dev/null | od -An -tx1 | tr -d ' \n')"
  [ "$m" = "53ef" ]
}

ensure_raw_ext4() {
  # $1 = source image, $2 = raw ext4 output path
  if is_sparse "$1"; then
    log "$(basename "$1") is sparse - converting to raw"
    if ! command -v simg2img >/dev/null 2>&1; then
      sudo apt-get update -qq
      sudo apt-get install -y -qq android-sdk-libsparse-utils
    fi
    command -v simg2img >/dev/null 2>&1 || die "simg2img not available"
    simg2img "$1" "$2" || die "simg2img failed for $1"
  else
    cp -f "$1" "$2"
  fi
  raw_ext4_ok "$2" || die "$(basename "$2"): ext4 magic 53ef not found at offset 1080"
}

# --- preconditions ---------------------------------------------------------
log "checking build outputs"
[ -f "$OUT/system.img" ]   || die "system.img not found in $OUT (did the build run?)"
[ -f "$OUT/product.img" ]  || die "product.img not found in $OUT (did the build run?)"
[ -f "$PREBUILT_BOOT" ]    || die "prebuilt boot.img missing: $PREBUILT_BOOT"
[ -f "$LPTOOLS" ]          || die "lptools_static missing: $LPTOOLS"
[ -f "$AVBTOOL" ]          || die "avbtool.py missing: $AVBTOOL (aosp/external/avb not synced?)"

# --- normalize the filesystem images to raw ext4 ---------------------------
ensure_raw_ext4 "$OUT/system.img"  "$WORK/system.img"
ensure_raw_ext4 "$OUT/product.img" "$WORK/product.img"
log "system.img:  $(stat -c %s "$WORK/system.img") bytes"
log "product.img: $(stat -c %s "$WORK/product.img") bytes"

# --- vbmeta: algorithm NONE, flags 3 (disables verification) ---------------
log "generating flags-3 vbmeta images"
for v in vbmeta vbmeta_system vbmeta_vendor; do
  python3 "$AVBTOOL" make_vbmeta_image \
    --output "$WORK/$v.img" \
    --algorithm NONE \
    --flags 3 \
    || die "avbtool failed for $v"
  truncate -s 4096 "$WORK/$v.img" || die "truncate $v.img failed"
done

# --- payload ---------------------------------------------------------------
cp -f "$PREBUILT_BOOT" "$WORK/boot.img"
cp -f "$LPTOOLS" "$WORK/lptools_static"
chmod 755 "$WORK/lptools_static"

# images.txt: "<name> <size in bytes>" - the updater verifies every write
# against this file and grows logical partitions to these sizes.
: > "$WORK/images.txt"
for f in system.img product.img boot.img vbmeta.img vbmeta_system.img vbmeta_vendor.img; do
  printf '%s %s\n' "$f" "$(stat -c %s "$WORK/$f")" >> "$WORK/images.txt"
done
cp -f "$WORK/images.txt" "$DIST/images-size.txt"
log "image sizes:"
sed 's/^/  /' "$WORK/images.txt"

# --- build the zip ---------------------------------------------------------
ZIPFILE="$DIST/$ZIPNAME"
log "building $ZIPFILE"
rm -f "$ZIPFILE" "$ZIPFILE".part*
(
  cd "$WORK"
  zip -9 -q "$ZIPFILE" \
    system.img product.img boot.img \
    vbmeta.img vbmeta_system.img vbmeta_vendor.img \
    images.txt lptools_static
)
(
  cd "$ROOT"
  zip -9 -q "$ZIPFILE" \
    META-INF/com/google/android/update-binary \
    META-INF/com/google/android/updater-script
)

SIZE="$(stat -c %s "$ZIPFILE")"
log "zip size: $SIZE bytes"

# GitHub release assets are limited to 2 GiB - split when needed.
LIMIT=2000000000
if [ "$SIZE" -gt "$LIMIT" ]; then
  log "zip exceeds 2 GB - splitting into parts (cat part* to reassemble)"
  split -b 1950m -d -a 2 "$ZIPFILE" "$ZIPFILE.part"
  rm -f "$ZIPFILE"
  ls -la "$DIST"
else
  ls -la "$ZIPFILE"
fi

log "done"
