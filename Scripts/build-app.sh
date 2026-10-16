#!/bin/bash
#
# UltimateScrollWM .app üretici / kurucu
#
# Kullanım:
#   Scripts/build-app.sh            # -> dist/UltimateScrollWM.app
#   Scripts/build-app.sh dist       # aynısı
#   Scripts/build-app.sh install    # -> /Applications/UltimateScrollWM.app
#
# Neden geçici dizin?
#   Proje ~/Documents altında ve iCloud/fileprovider senkronu dosyalara
#   com.apple.FinderInfo ekliyor. codesign bunu "detritus" sayıp reddediyor.
#   Bu yüzden paketleyip imzalıyoruz, sonra hazır ürünü hedefe kopyalıyoruz.
#
set -euo pipefail

cd "$(dirname "$0")/.."

APP="UltimateScrollWM"
RES_BUNDLE="${APP}_${APP}.bundle"
ENGINE_ID="com.local.UltimateScrollWM.engine"
TARGET="${1:-dist}"

echo "==> Release derleniyor"
swift build -c release

echo "==> Geçici dizinde paketleniyor"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
BUNDLE="$TMP/$APP.app"

mkdir -p "$BUNDLE/Contents/MacOS" "$BUNDLE/Contents/Resources"
cp ".build/release/$APP" "$BUNDLE/Contents/MacOS/$APP"
cp -R ".build/release/$RES_BUNDLE" "$BUNDLE/Contents/Resources/"
cp "AppBundle/Info.plist" "$BUNDLE/Contents/Info.plist"

xattr -cr "$BUNDLE"
# Gömülü motora, çalışan kurulumdaki kimliği ver (mach service adıyla eşleşir).
codesign --force --sign - -i "$ENGINE_ID" \
    "$BUNDLE/Contents/Resources/$RES_BUNDLE/Contents/Resources/Resources/paneru"
codesign --force --sign - "$BUNDLE"
codesign --verify --verbose=1 "$BUNDLE"

if [ "$TARGET" = "install" ]; then
    DEST="/Applications/$APP.app"
    osascript -e "quit app \"$APP\"" >/dev/null 2>&1 || true
    sleep 1
    rm -rf "$DEST"
    ditto "$BUNDLE" "$DEST"
    echo "==> Kuruldu: $DEST"
    echo "    İlk açılışta: Sistem Ayarları > Gizlilik ve Güvenlik > Erişilebilirlik"
else
    rm -rf "$TARGET"
    mkdir -p "$TARGET"
    ditto "$BUNDLE" "$TARGET/$APP.app"
    echo "==> Üretildi: $TARGET/$APP.app"
fi
