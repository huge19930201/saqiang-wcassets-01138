#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
mkdir -p build/SaoqiangUI.app build/ui-check
SDK="$(xcrun --sdk iphonesimulator --show-sdk-path)"
ARCH="$(uname -m)"
xcrun --sdk iphonesimulator clang -target "$ARCH-apple-ios15.0-simulator" -isysroot "$SDK" -I. -DSAOQIANG_WCASSETS_TESTING=1 -fobjc-arc -fblocks -O1 -Wall -Wextra -Wno-unused-parameter -framework Foundation -framework UIKit -framework ImageIO -framework CoreGraphics -framework QuartzCore -framework UniformTypeIdentifiers tests/UIDemo.m tests/NamingChecks.m tests/FeatureChecks.m tests/ProviderChecks.m tests/Engine308Checks.m SaoqiangWCAssetsStore.m SaoqiangWCAssetsHooks.m SaoqiangWCAssetsUI.m SaoqiangWCAssetsInspector.m SaoqiangWCAssetsBubbles.m SaoqiangWCAssetsTheme.m SaoqiangWCAssetsThemePack.m SaoqiangWCAssetsReference.m SaoqiangWCAssetsPage.m SaoqiangWCAssetsNative.m SaoqiangWCAssetsPackNames.m SaoqiangWCAssetsZIP.c -o build/SaoqiangUI.app/SaoqiangUI
python3 -c 'import plistlib; plistlib.dump({"CFBundleIdentifier":"com.saoqiang.wcassets.uitest","CFBundleExecutable":"SaoqiangUI","CFBundleName":"SaoqiangUI","CFBundlePackageType":"APPL","CFBundleVersion":"1","CFBundleShortVersionString":"0.11.5","MinimumOSVersion":"15.0","LSRequiresIPhoneOS":True,"UILaunchScreen":{},"UIDeviceFamily":[1,2]},open("build/SaoqiangUI.app/Info.plist","wb"))'
codesign --force --sign - build/SaoqiangUI.app
xcrun simctl list devices available --json > build/ui-check/devices.json
DEVICE=$(python3 -c 'import json; d=json.load(open("build/ui-check/devices.json")); a=[x for group in d["devices"].values() for x in group if x.get("isAvailable") and "iPhone" in x["name"]]; assert a; print(a[0]["udid"])')
xcrun simctl boot "$DEVICE" || true
xcrun simctl bootstatus "$DEVICE" -b
xcrun simctl status_bar "$DEVICE" override --time '09:41' --batteryState charged --batteryLevel 100
xcrun simctl install "$DEVICE" build/SaoqiangUI.app
trap 'xcrun simctl spawn "$DEVICE" log show --last 3m --predicate '\''process == "SaoqiangUI"'\'' --style compact > build/ui-check/runtime.log || true' EXIT
xcrun simctl launch "$DEVICE" com.saoqiang.wcassets.uitest
CONTAINER=$(xcrun simctl get_app_container "$DEVICE" com.saoqiang.wcassets.uitest data)
python3 -c 'import time,sys,pathlib; p=pathlib.Path(sys.argv[1]); end=time.time()+210
while time.time()<end and not (p/"exports-done.txt").exists() and not (p/"capture-failed.txt").exists(): time.sleep(0.5)' "$CONTAINER/Documents"
if [ -f "$CONTAINER/Documents/engine308-done.txt" ]; then
  cp "$CONTAINER/Documents/engine308-checks.json" build/ui-check/
  cp -R "$CONTAINER/Documents/engine308-cases" build/ui-check/
  python3 tests/verify_engine308.py build/ui-check
fi
xcrun simctl io "$DEVICE" screenshot build/ui-check/list.png
if [ -f "$CONTAINER/Documents/capture-failed.txt" ]; then
  cp "$CONTAINER/Documents/capture-failed.txt" build/ui-check/
  cat "$CONTAINER/Documents/capture-failed.txt"
  exit 1
fi
mkdir -p build/ui-check/export
cp -R "$CONTAINER/Documents/test-folder" "$CONTAINER/Documents/single-bubble.png" "$CONTAINER/Documents/naming-checks.json" "$CONTAINER/Documents/exports-done.txt" build/ui-check/export/
python3 tests/verify_export.py build/ui-check/export
cp -R "$CONTAINER/Documents/test-theme-folder" "$CONTAINER/Documents/case-folders" "$CONTAINER/Documents/expected-source.json" "$CONTAINER/Documents/failures.json" "$CONTAINER/Documents/theme-full-result.json" "$CONTAINER/Documents/provider-checks.json" "$CONTAINER/Documents/features-done.txt" "$CONTAINER/Documents/engine308-checks.json" "$CONTAINER/Documents/engine308-done.txt" "$CONTAINER/Documents/engine308-cases" build/ui-check/export/
python3 tests/verify_features.py build/ui-check/export
xcrun simctl terminate "$DEVICE" com.saoqiang.wcassets.uitest
xcrun simctl launch "$DEVICE" com.saoqiang.wcassets.uitest tools
python3 -c 'import time; time.sleep(7)'
xcrun simctl io "$DEVICE" screenshot build/ui-check/tools.png
xcrun simctl terminate "$DEVICE" com.saoqiang.wcassets.uitest
xcrun simctl launch "$DEVICE" com.saoqiang.wcassets.uitest icons
python3 -c 'import time; time.sleep(7)'
xcrun simctl io "$DEVICE" screenshot build/ui-check/icons.png
xcrun simctl terminate "$DEVICE" com.saoqiang.wcassets.uitest
xcrun simctl launch "$DEVICE" com.saoqiang.wcassets.uitest home
python3 -c 'import time,sys,pathlib; p=pathlib.Path(sys.argv[1])/"home-done.txt"; end=time.time()+15
while time.time()<end and not p.exists(): time.sleep(0.5)
if not p.exists(): sys.exit("返回微信首页 button check timed out")' "$CONTAINER/Documents"
# 0.11.41: the gesture card is a different presentation path (child navigation
# controller inside a resizable card). Assert 3/5 → 4.5/5 and that the page title
# clears the navigation bar, then keep a screenshot for the record.
xcrun simctl terminate "$DEVICE" com.saoqiang.wcassets.uitest
rm -f "$CONTAINER/Documents/card-done.txt" "$CONTAINER/Documents/capture-failed.txt"
xcrun simctl launch "$DEVICE" com.saoqiang.wcassets.uitest card
python3 -c 'import time,sys,pathlib; d=pathlib.Path(sys.argv[1]); end=time.time()+20
while time.time()<end and not (d/"card-done.txt").exists() and not (d/"capture-failed.txt").exists(): time.sleep(0.5)
if (d/"capture-failed.txt").exists(): sys.exit("card layout check failed: "+(d/"capture-failed.txt").read_text())
if not (d/"card-done.txt").exists(): sys.exit("card layout check timed out")' "$CONTAINER/Documents"
xcrun simctl io "$DEVICE" screenshot build/ui-check/card.png
xcrun simctl spawn "$DEVICE" log show --last 2m --predicate 'process == "SaoqiangUI"' --style compact > build/ui-check/runtime.log
