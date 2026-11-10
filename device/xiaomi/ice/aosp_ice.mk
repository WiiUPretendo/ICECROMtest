# aosp_ice.mk - ICECROM system image for the Xiaomi Redmi A1 (ice)
#
# Structure mirrors build/make/target/product/aosp_arm.mk (Android 15),
# minus the GSI-release specifics and the x86 emulator device config.

PRODUCT_USE_DYNAMIC_PARTITIONS := true

#
# All components inherited here go to the system image
#
$(call inherit-product, $(SRC_TARGET_DIR)/product/generic_system.mk)

# Enable mainline artifact path checking for exactly this product name
ifeq (aosp_ice,$(TARGET_PRODUCT))
PRODUCT_ENFORCE_ARTIFACT_PATH_REQUIREMENTS := relaxed
endif

PRODUCT_ARTIFACT_PATH_REQUIREMENT_ALLOWED_LIST +=

#
# All components inherited here go to the system_ext image (packed inside
# system.img, see TARGET_COPY_OUT_SYSTEM_EXT in BoardConfig.mk)
#
$(call inherit-product, $(SRC_TARGET_DIR)/product/handheld_system_ext.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/telephony_system_ext.mk)

#
# All components inherited here go to the product image
#
$(call inherit-product, $(SRC_TARGET_DIR)/product/aosp_product.mk)

#
# Device-specific configuration (VNDK 31 snapshot for the stock vendor)
#
$(call inherit-product, device/xiaomi/ice/device.mk)

# Build mainline modules from source instead of prebuilts
MODULE_BUILD_FROM_SOURCE := true

PRODUCT_NAME := aosp_ice
PRODUCT_DEVICE := ice
PRODUCT_BRAND := Redmi
PRODUCT_MODEL := Redmi A1
PRODUCT_MANUFACTURER := Xiaomi

# Matches the stock device launch API level (vendor ro.product.first_api_level=31)
PRODUCT_SHIPPING_API_LEVEL := 31

PRODUCT_USE_DYNAMIC_PARTITION_SIZE := true

PRODUCT_SYSTEM_PROPERTIES += \
    ro.sf.lcd_density=320 \
    ro.icecrom.build=1
