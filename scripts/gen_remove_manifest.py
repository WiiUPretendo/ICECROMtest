#!/usr/bin/env python3
"""Generate a repo local manifest that removes projects we never need.

Reads the manifest tree repo just checked out (source of truth for whatever
AOSP tag was selected) and writes .repo/local_manifests/ice-remove.xml so
`repo sync` never downloads: test harnesses (cts/test/tradefed/asuite...),
Pixel/Linaro/Amlogic device trees with prebuilt kernels, emulator/darwin
prebuilts, NDK prebuilts and unused VNDK snapshots. This keeps the AOSP
checkout small enough to build inside the ~60G disk of a GitHub-hosted
runner, which a full 1425-project shallow sync does not fit in.
"""
import os
import re
import sys

REMOVE_PREFIXES = (
    'platform/test/', 'platform/tools/test/', 'platform/tools/tradefederation',
    'platform/tools/asuite', 'platform/tools/acloud', 'platform/tools/aadevtools',
    'platform/tools/deviceinfra/', 'platform/tools/loganalysis',
    'platform/tools/carrier_settings', 'platform/tools/currysrc',
    'platform/tools/external_updater', 'platform/tools/doc_generation',
    'platform/tools/netsim', 'platform/tools/ndkports',
    'platform/tools/trebuchet', 'platform/tools/treble',
    'platform/cts', 'platform/pdk', 'platform/development',
    'platform/external/autotest', 'device/google', 'device/linaro',
    'device/amlogic', 'device/sample', 'device/google_car',
    'platform/prebuilts/abi-dumps/', 'platform/prebuilts/android-emulator',
    'platform/prebuilts/asuite', 'platform/prebuilts/bazel/',
    'platform/prebuilts/clang-tools', 'platform/prebuilts/devtools',
    'platform/prebuilts/ndk', 'platform/prebuilts/qemu-kernel',
    'platform/prebuilts/remoteexecution-client', 'platform/prebuilts/vndk/v29',
    'platform/prebuilts/vndk/v30', 'platform/prebuilts/vndk/v32',
    'platform/prebuilts/vndk/v33', 'platform/prebuilts/vndk/v34',
    'platform/prebuilts/go/darwin-x86', 'platform/prebuilts/clang/host/darwin-x86',
    'device/generic/goldfish', 'device/generic/goldfish-opengl',
    'device/generic/vulkan-cereal', 'device/generic/x86', 'device/generic/x86_64',
    'device/generic/car', 'device/generic/uml', 'device/generic/trusty',
    'device/generic/opengl-transport', 'device/generic/arm64',
)

PROTECT = (
    'platform/tools/metalava', 'platform/tools/security',
    'platform/tools/repohooks', 'platform/tools/apksig',
    'platform/tools/apkzlib',
    # Soong bootstrap embeds protos from here and some build tooling
    # references the bazel binary dir; without them soong_ui fails to
    # start ("Error parsing directory .../prebuilts/bazel/common/proto").
    'platform/prebuilts/bazel/common', 'platform/prebuilts/bazel/linux-x86_64',
    # Registers the "csuite_test" module type via a bootstrap Go plugin
    # (test/app_compat/csuite/tools/csuite_test); soong parses all
    # Android.bp files (art/test, frameworks/base use the type) and fails
    # with "unrecognized module type" without this repo.
    'platform/test/app_compat/csuite',
    # The CTS tree (yes, 2.3G) defines cts_defaults and
    # mts-target-sdk-version-current modules referenced by always-parsed
    # Android.bp files in kept projects (external/skia,
    # packages/modules/Permission, build/bazel examples). Removing it
    # fails soong with "depends on undefined module cts_defaults".
    'platform/cts',
    # Confusing failures, verified: platform_testing/tools/automotive/proxy
    # references cuttlefish_base and packages/modules/Virtualization/
    # microdroid references cuttlefish_crosvm; both kept-tree Android.bp
    # files fail soong if the cuttlefish device tree trio is absent
    # (also aosplite's verified stance: cuttlefish = NOT removed).
    'device/google/cuttlefish',
    'device/google/cuttlefish_prebuilts',
    'device/google/cuttlefish_vmm',
    # device/sample/etc/apns-full-conf.xml is copied to
    # system/etc/apns-conf.xml by the product config; without the repo
    # packaging fails with "missing and no known rule to make it".
    'device/sample',
    # Defines lint_api, imported by tools/ and packages/modules/*/lint.
    'platform/prebuilts/cmdline-tools',
    # Host tooling referenced by parts of the build; pruning it produces
    # confusing failures late in the build (per aosplite's verified tier
    # lists for android-15).
    'platform/development',
)


def main(manifest_path, out_dir):
    data = open(manifest_path, encoding='utf-8').read()
    names = sorted(set(re.findall(r'<project[^>]*\bname="([^"]+)"', data)))
    remove = [
        n for n in names
        if n not in PROTECT and n.startswith(REMOVE_PREFIXES)
    ]
    os.makedirs(out_dir, exist_ok=True)
    out = os.path.join(out_dir, 'ice-remove.xml')
    lines = '\n'.join('  <remove-project name="%s" />' % n for n in remove)
    open(out, 'w', newline='\n').write('<manifest>\n%s\n</manifest>\n' % lines)
    print('local manifest: removing %d of %d projects' % (len(remove), len(names)))


if __name__ == '__main__':
    manifest = sys.argv[1] if len(sys.argv) > 1 else '.repo/manifests/default.xml'
    outdir = sys.argv[2] if len(sys.argv) > 2 else '.repo/local_manifests'
    main(manifest, outdir)
