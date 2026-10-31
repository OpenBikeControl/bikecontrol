#!/usr/bin/env bash
# Packages a `flutter build linux` / `shorebird release linux` bundle as a .deb.
#
#   linux/packaging/build_deb.sh <bundle dir> <version> <amd64|arm64> <output dir>
#
# Installs the app under /opt/bikecontrol, a launcher, the icon, the
# bikecontrol:// handler (sign-in and checkout come back through it) and the
# udev rule that lets the logged-in user create virtual input devices for the
# Local connection method.
set -euo pipefail

BUNDLE=$1
VERSION=$2
ARCH=$3
OUT=$4

HERE=$(cd "$(dirname "$0")" && pwd)
APP_ID=app.bikecontrol.BikeControl
ROOT=$(mktemp -d)
trap 'rm -rf "$ROOT"' EXIT

install -d "$ROOT/opt/bikecontrol" "$ROOT/usr/bin" "$ROOT/DEBIAN" \
  "$ROOT/usr/share/applications" "$ROOT/usr/share/icons/hicolor/512x512/apps" "$ROOT/usr/lib/udev/rules.d"
cp -a "$BUNDLE"/. "$ROOT/opt/bikecontrol/"
ln -s /opt/bikecontrol/bikecontrol "$ROOT/usr/bin/bikecontrol"
install -m 644 "$HERE/$APP_ID.desktop" "$ROOT/usr/share/applications/$APP_ID.desktop"
install -m 644 "$HERE/$APP_ID.png" "$ROOT/usr/share/icons/hicolor/512x512/apps/$APP_ID.png"
install -m 644 "$HERE/60-bikecontrol-uinput.rules" "$ROOT/usr/lib/udev/rules.d/60-bikecontrol-uinput.rules"

# Flutter loads EGL/GLES with dlopen, so they do not show up in ldd.
cat > "$ROOT/DEBIAN/control" <<EOF
Package: bikecontrol
Version: $VERSION
Architecture: $ARCH
Maintainer: BikeControl <support@bikecontrol.app>
Homepage: https://bikecontrol.app
Section: utils
Priority: optional
Installed-Size: $(du -sk "$ROOT" | cut -f1)
Depends: libgtk-3-0t64 | libgtk-3-0, libegl1, libgles2, libsecret-1-0, libasound2t64 | libasound2, libstdc++6, libc6 (>= 2.35)
Recommends: bluez, avahi-daemon
Description: Use your bike's controllers with any training app
 BikeControl connects Zwift Click, Ride and Play, Shimano Di2, SRAM AXS and
 other bike controllers and smart trainers to MyWhoosh, Zwift, Rouvy,
 TrainingPeaks Virtual and more, with virtual shifting for any smart trainer.
EOF

cat > "$ROOT/DEBIAN/postinst" <<'EOF'
#!/bin/sh
set -e
if command -v udevadm >/dev/null 2>&1; then
  udevadm control --reload-rules || true
  udevadm trigger --name-match=uinput || true
fi
command -v update-desktop-database >/dev/null 2>&1 && update-desktop-database -q /usr/share/applications || true
command -v gtk-update-icon-cache >/dev/null 2>&1 && gtk-update-icon-cache -q -t -f /usr/share/icons/hicolor || true
exit 0
EOF

cat > "$ROOT/DEBIAN/postrm" <<'EOF'
#!/bin/sh
set -e
command -v udevadm >/dev/null 2>&1 && udevadm control --reload-rules || true
command -v update-desktop-database >/dev/null 2>&1 && update-desktop-database -q /usr/share/applications || true
exit 0
EOF
chmod 755 "$ROOT/DEBIAN/postinst" "$ROOT/DEBIAN/postrm"

mkdir -p "$OUT"
dpkg-deb --root-owner-group -Zxz --build "$ROOT" "$OUT/BikeControl-linux-$ARCH.deb"
