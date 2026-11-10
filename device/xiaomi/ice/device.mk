# device.mk - ICECROM for Xiaomi Redmi A1 (ice)
#
# The stock vendor, odm and boot images are reused exactly as they are, so
# this file stays minimal. Ship the Android 12 (VNDK 31) snapshot APEX inside
# system_ext so the Android 15 system provides the vendor libraries that the
# stock Android 12 vendor expects (apexd mounts it at
# /apex/com.android.vndk.v31 based on the stock ro.vndk.version=31).

PRODUCT_EXTRA_VNDK_VERSIONS := 31
