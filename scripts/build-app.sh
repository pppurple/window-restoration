#!/bin/zsh
set -euo pipefail

repo_dir="${0:A:h:h}"
app_dir="$repo_dir/dist/Window Restoration.app"
contents_dir="$app_dir/Contents"
build_dir="$repo_dir/.build/app"
module_cache="$build_dir/module-cache"
swiftc_path="${WINDOW_RESTORATION_SWIFTC:-$(xcrun --find swiftc)}"
target_arch="$(uname -m)"
bundle_identifier="io.github.pppurple.WindowRestoration"
configuration="${WINDOW_RESTORATION_CONFIGURATION:-debug}"

cd "$repo_dir"
mkdir -p "$build_dir" "$module_cache"

binary_path=""
build_description=""

# Prefer Swift Package Manager so recent SwiftUI macro implementations are
# loaded through the supported build pipeline. The disabled package sandbox is
# safe here because this package has no external dependencies or plugins.
if [[ -n "${WINDOW_RESTORATION_SDKROOT:-}" ]]; then
    if SDKROOT="$WINDOW_RESTORATION_SDKROOT" \
        CLANG_MODULE_CACHE_PATH="$module_cache" \
        SWIFTPM_MODULECACHE_OVERRIDE="$module_cache" \
        swift build --disable-sandbox -c "$configuration" --product WindowRestoration; then
        binary_dir="$(SDKROOT="$WINDOW_RESTORATION_SDKROOT" \
            CLANG_MODULE_CACHE_PATH="$module_cache" \
            SWIFTPM_MODULECACHE_OVERRIDE="$module_cache" \
            swift build --disable-sandbox -c "$configuration" --show-bin-path)"
        binary_path="$binary_dir/WindowRestoration"
        build_description="Swift Package Manager $configuration ($WINDOW_RESTORATION_SDKROOT)"
    fi
else
    if CLANG_MODULE_CACHE_PATH="$module_cache" \
        SWIFTPM_MODULECACHE_OVERRIDE="$module_cache" \
        swift build --disable-sandbox -c "$configuration" --product WindowRestoration; then
        binary_dir="$(CLANG_MODULE_CACHE_PATH="$module_cache" \
            SWIFTPM_MODULECACHE_OVERRIDE="$module_cache" \
            swift build --disable-sandbox -c "$configuration" --show-bin-path)"
        binary_path="$binary_dir/WindowRestoration"
        build_description="Swift Package Manager $configuration"
    fi
fi

# Fall back to direct compilation for older Command Line Tools installations
# where Swift Package Manager itself may not match the installed SDK.
if [[ -z "$binary_path" ]]; then
    sdk_candidates=()
    if [[ -n "${WINDOW_RESTORATION_SDKROOT:-}" ]]; then
        sdk_candidates+=("$WINDOW_RESTORATION_SDKROOT")
    else
        sdk_candidates+=("$(xcrun --sdk macosx --show-sdk-path)")
        while IFS= read -r sdk; do
            sdk_candidates+=("$sdk")
        done < <(find /Library/Developer/CommandLineTools/SDKs -maxdepth 1 -type d -name 'MacOSX*.sdk' | sort -Vr)
    fi

    selected_sdk=""
    for sdk in "${sdk_candidates[@]}"; do
        if "$swiftc_path" \
            -emit-library -static -emit-module \
            Sources/WindowRestorationCore/*.swift \
            -sdk "$sdk" \
            -target "$target_arch-apple-macosx13.0" \
            -module-cache-path "$module_cache" \
            -module-name WindowRestorationCore \
            -emit-module-path "$build_dir/WindowRestorationCore.swiftmodule" \
            -o "$build_dir/libWindowRestorationCore.a" \
            2>"$build_dir/compiler.log"; then
            selected_sdk="$sdk"
            break
        fi
    done

    if [[ -z "$selected_sdk" ]]; then
        echo "Swift compiler and macOS SDK are incompatible." >&2
        cat "$build_dir/compiler.log" >&2
        exit 1
    fi

    "$swiftc_path" \
        Sources/WindowRestoration/*.swift \
        -sdk "$selected_sdk" \
        -target "$target_arch-apple-macosx13.0" \
        -module-cache-path "$module_cache" \
        -I "$build_dir" \
        -L "$build_dir" \
        -lWindowRestorationCore \
        -o "$build_dir/WindowRestoration"
    binary_path="$build_dir/WindowRestoration"
    build_description="direct swiftc ($selected_sdk)"
fi

mkdir -p "$contents_dir/MacOS"
cp "$binary_path" "$contents_dir/MacOS/WindowRestoration"
cp "$repo_dir/Support/Info.plist" "$contents_dir/Info.plist"

# A plain ad-hoc signature uses the binary hash as its designated requirement.
# That hash changes on every rebuild, causing macOS to forget Accessibility
# permission. An explicit local-only requirement keeps the app identity stable.
signing_requirement="=designated => identifier \"$bundle_identifier\""
/usr/bin/codesign \
    --force \
    --sign - \
    --requirements "$signing_requirement" \
    "$app_dir"

echo "Build: $build_description"
echo "$app_dir"
