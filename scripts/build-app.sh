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

cd "$repo_dir"
mkdir -p "$build_dir" "$module_cache"

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

mkdir -p "$contents_dir/MacOS"
cp "$build_dir/WindowRestoration" "$contents_dir/MacOS/WindowRestoration"
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

echo "SDK: $selected_sdk"
echo "$app_dir"
