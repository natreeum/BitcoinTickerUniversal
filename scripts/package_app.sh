#!/bin/sh
set -eu

project_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
configuration=${CONFIGURATION:-release}
app_dir="$project_dir/dist/Bitcoin Ticker Universal.app"
contents_dir="$app_dir/Contents"
uninstaller_dir="$project_dir/dist/Uninstall Bitcoin Ticker Universal.app"
uninstaller_contents_dir="$uninstaller_dir/Contents"

swift build --package-path "$project_dir" -c "$configuration" --arch arm64 --arch x86_64

binary_path=$(swift build --package-path "$project_dir" -c "$configuration" --arch arm64 --arch x86_64 --show-bin-path)
mkdir -p "$contents_dir/MacOS" "$contents_dir/Resources"
cp "$binary_path/BitcoinTickerUniversal" "$contents_dir/MacOS/BitcoinTickerUniversal"
cp "$project_dir/Resources/Info.plist" "$contents_dir/Info.plist"
cp "$project_dir/Resources/AppIcon.icns" "$contents_dir/Resources/AppIcon.icns"
mkdir -p "$uninstaller_contents_dir/MacOS" "$uninstaller_contents_dir/Resources"
cp "$binary_path/BitcoinTickerUninstaller" "$uninstaller_contents_dir/MacOS/BitcoinTickerUninstaller"
cp "$project_dir/Resources/Uninstaller-Info.plist" "$uninstaller_contents_dir/Info.plist"
cp "$project_dir/Resources/UninstallerIcon.icns" "$uninstaller_contents_dir/Resources/UninstallerIcon.icns"

codesign --force --deep --sign - "$app_dir"
codesign --force --deep --sign - "$uninstaller_dir"

architectures=$(lipo -archs "$contents_dir/MacOS/BitcoinTickerUniversal")
uninstaller_architectures=$(lipo -archs "$uninstaller_contents_dir/MacOS/BitcoinTickerUninstaller")
case " $architectures " in *" arm64 "*) ;; *)
    echo "arm64 verification failed: $architectures" >&2
    exit 1
esac
case " $architectures " in *" x86_64 "*) ;; *)
    echo "x86_64 verification failed: $architectures" >&2
    exit 1
esac
case " $uninstaller_architectures " in *" arm64 "*) ;; *)
    echo "Uninstaller arm64 verification failed: $uninstaller_architectures" >&2
    exit 1
esac
case " $uninstaller_architectures " in *" x86_64 "*) ;; *)
    echo "Uninstaller x86_64 verification failed: $uninstaller_architectures" >&2
    exit 1
esac

echo "$app_dir ($architectures)"
echo "$uninstaller_dir ($uninstaller_architectures)"
