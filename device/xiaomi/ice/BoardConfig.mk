# BoardConfig.mk - Xiaomi Redmi A1 (ice)
#
# Base: mainline common config (the same base GSI builds use), then
# overridden for this device's hardware and stock partition layout.

include build/make/target/board/BoardConfigMainlineCommon.mk

# Architecture: 32-bit userspace only (stock is armeabi-v7a, MT6761/Cortex-A53)
TARGET_ARCH := arm
TARGET_ARCH_VARIANT := armv7-a-neon
TARGET_CPU_ABI := armeabi-v7a
TARGET_CPU_ABI2 := armeabi
TARGET_CPU_VARIANT := cortex-a53

# Platform
TARGET_BOARD_PLATFORM := mt6761
TARGET_BOOTLOADER_BOARD_NAME := ice

# Kernel, boot and recovery are never built: the stock boot.img
# (recovery-as-boot carrying TWRP) is flashed by the zip as-is.
TARGET_NO_KERNEL := true

# system_ext lives inside system.img; the stock ramdisk provides the
# /system_ext -> /system/system_ext symlink.
TARGET_COPY_OUT_SYSTEM_EXT := system/system_ext
BOARD_SYSTEM_EXTIMAGE_FILE_SYSTEM_TYPE :=

# No system_other partition exists: odex/vdex files stay inside their own
# images (this is what GSI builds do as well).
BOARD_USES_SYSTEM_OTHER_ODEX :=

# Dexpreopt: build the ART/boot image (fast zygote start) but skip per-app
# odex/vdex in system.img. This keeps system.img small enough to fit this
# device's super free space and keeps CI disk/RAM usage down; apps are
# dexopted on-device normally (first boot / background dexopt) because
# only build-time preopt is affected. Declared as a late board/product
# variable in build/make/core/product.mk, so it belongs here.
WITH_DEXPREOPT_ART_BOOT_IMG_ONLY := true

# system.img: ext4, raw (non-sparse), 64 MiB reserved headroom
BOARD_SYSTEMIMAGE_FILE_SYSTEM_TYPE := ext4
TARGET_USERIMAGES_SPARSE_EXT_DISABLED := true
BOARD_SYSTEMIMAGE_PARTITION_RESERVED_SIZE := 67108864

# product.img: a separate logical partition matching the stock fstab
# "/product ... logical,first_stage_mount,slotselect" entry.
BOARD_PRODUCTIMAGE_FILE_SYSTEM_TYPE := ext4

# AVB disabled for image building - the images are written raw, without avb
# footers. The flash zip ships its own algorithm-NONE flags-3 vbmeta trio,
# which short-circuits all verification on an unlocked bootloader.
BOARD_AVB_ENABLE := false
BOARD_AVB_ROLLBACK_INDEX := 0

# Declared only so PRODUCT_VENDOR_PROPERTIES resolves at build time.
# vendor.img is stock and is never built here.
BOARD_VENDORIMAGE_FILE_SYSTEM_TYPE := ext4

# No /cache partition exists on this device; declared so the build rules
# resolve (cache.img is never built, the size is irrelevant).
BOARD_CACHEIMAGE_FILE_SYSTEM_TYPE := ext4
BOARD_CACHEIMAGE_PARTITION_SIZE := 16777216

# Super partition layout - identical to stock and to the icetwrp tree
BOARD_SUPER_PARTITION_SIZE := 9126805504
BOARD_SUPER_PARTITION_GROUPS := xiaomi_dynamic_partitions
BOARD_XIAOMI_DYNAMIC_PARTITIONS_PARTITION_LIST := \
    system \
    vendor \
    product
BOARD_XIAOMI_DYNAMIC_PARTITIONS_SIZE := 9122611200
BOARD_FLASH_BLOCK_SIZE := 131072

# Bluetooth: the stock vendor provides its own buildcfg (b/123695686)
BOARD_BLUETOOTH_BDROID_BUILDCFG_INCLUDE_DIR :=

# 32-bit-only build: keep mediadrmserver 32-bit. MainlineCommon's
# TARGET_ENABLE_MEDIADRM_64 assumes a 64-bit-capable system, which this
# device's userspace is not.
TARGET_ENABLE_MEDIADRM_64 :=

# GSI-style system_ext properties: disable privapp-permission enforcement
# and RescueParty (A15 system + A12 vendor mix), unauthenticated adb on
# debug builds.
ifneq (,$(filter userdebug eng,$(TARGET_BUILD_VARIANT)))
TARGET_SYSTEM_EXT_PROP := build/make/target/board/gsi_system_ext.prop
else
TARGET_SYSTEM_EXT_PROP := build/make/target/board/gsi_system_ext_user.prop
endif
