#!/bin/sh
set -eu

project_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
app_version=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$project_dir/Resources/Info.plist")
dmg_path="$project_dir/dist/Bitcoin-Ticker-Universal-$app_version.dmg"
dmg_stage_dir=$(mktemp -d /private/tmp/bitcoin-ticker-dmg.XXXXXX)

case "$dmg_stage_dir" in
    /private/tmp/bitcoin-ticker-dmg.*) ;;
    *) exit 1 ;;
esac
trap 'rm -rf "$dmg_stage_dir"' EXIT

"$project_dir/scripts/package_app.sh"

ditto \
    "$project_dir/dist/Bitcoin Ticker Universal.app" \
    "$dmg_stage_dir/Bitcoin Ticker Universal.app"
ditto \
    "$project_dir/dist/Uninstall Bitcoin Ticker Universal.app" \
    "$dmg_stage_dir/Uninstall Bitcoin Ticker Universal.app"
ln -s /Applications "$dmg_stage_dir/Applications"

hdiutil create \
    -volname "Bitcoin Ticker Universal" \
    -srcfolder "$dmg_stage_dir" \
    -format UDZO \
    -ov \
    "$dmg_path"

hdiutil verify "$dmg_path"
echo "$dmg_path"
