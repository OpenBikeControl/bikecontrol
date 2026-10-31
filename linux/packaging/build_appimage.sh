#!/usr/bin/env bash
# Packages a `flutter build linux` / `shorebird release linux` bundle as an
# AppImage.
#
#   linux/packaging/build_appimage.sh <bundle dir> <version> <x86_64|aarch64> <output dir>
#
# An AppImage cannot install the udev rule for /dev/uinput; the app explains
# the rule when the Local connection method needs it. Machines with Steam
# installed already have an equivalent rule.
set -euo pipefail

BUNDLE=$1
VERSION=$2
ARCH=$3
OUT=$4

HERE=$(cd "$(dirname "$0")" && pwd)
APP_ID=app.bikecontrol.BikeControl
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
APPDIR=$WORK/BikeControl.AppDir

install -d "$APPDIR/usr/lib/bikecontrol" "$APPDIR/usr/share/applications" \
  "$APPDIR/usr/share/icons/hicolor/512x512/apps"
cp -a "$BUNDLE"/. "$APPDIR/usr/lib/bikecontrol/"
install -m 644 "$HERE/$APP_ID.desktop" "$APPDIR/$APP_ID.desktop"
install -m 644 "$HERE/$APP_ID.desktop" "$APPDIR/usr/share/applications/$APP_ID.desktop"
install -m 644 "$HERE/$APP_ID.png" "$APPDIR/$APP_ID.png"
install -m 644 "$HERE/$APP_ID.png" "$APPDIR/usr/share/icons/hicolor/512x512/apps/$APP_ID.png"
ln -s "$APP_ID.png" "$APPDIR/.DirIcon"

cat > "$APPDIR/AppRun" <<'EOF'
#!/bin/sh
HERE=$(dirname "$(readlink -f "$0")")
exec "$HERE/usr/lib/bikecontrol/bikecontrol" "$@"
EOF
chmod 755 "$APPDIR/AppRun"

TOOL=$WORK/appimagetool
curl -fsSL -o "$TOOL" "https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-$ARCH.AppImage"
chmod 755 "$TOOL"

mkdir -p "$OUT"
# Extract-and-run: CI runners and containers have no FUSE.
ARCH=$ARCH VERSION=$VERSION "$TOOL" --appimage-extract-and-run --no-appstream \
  "$APPDIR" "$OUT/BikeControl-linux-$ARCH.AppImage"
