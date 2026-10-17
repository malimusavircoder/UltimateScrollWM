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

# İmzalama kimliği (varsayılan: ad-hoc "-").
#
# Neden önemli:
#   Ad-hoc imzada macOS, Erişilebilirlik iznini ikili dosyanın parmak izine
#   (CDHash) bağlar. Kod her derlendiğinde parmak izi değişir ve izin
#   sıfırlanır. Sabit bir kimlikle imzalarsan izin kalıcı olur:
#
#     CODE_SIGN_IDENTITY="Developer ID Application: Ad Soyad (TEAMID)" make install
#
SIGN_ID="${CODE_SIGN_IDENTITY:--}"

if [ "$SIGN_ID" = "-" ]; then
    echo "==> İmzalama: ad-hoc (her derlemede Erişilebilirlik izni sıfırlanabilir)"
    echo "    Kalıcı izin için: CODE_SIGN_IDENTITY=\"...\" make install"
else
    echo "==> İmzalama: $SIGN_ID"
fi

xattr -cr "$BUNDLE"

PANERU="$BUNDLE/Contents/Resources/$RES_BUNDLE/Contents/Resources/Resources/paneru"
RES_BUNDLE_PATH="$BUNDLE/Contents/Resources/$RES_BUNDLE"

# Hardened runtime + güvenli zaman damgası: notarization'ın ön koşulu.
# Ad-hoc imzada (SIGN_ID="-") ikisi de kullanılmaz — timestamp için gerçek
# bir Developer ID sertifikası gerekir.
if [ "$SIGN_ID" = "-" ]; then
    codesign --force --sign "$SIGN_ID" -i "$ENGINE_ID" "$PANERU"
    codesign --force --sign "$SIGN_ID" "$RES_BUNDLE_PATH"
    codesign --force --sign "$SIGN_ID" "$BUNDLE"
else
    # İçten dışa imzala: paneru → SwiftPM kaynak paketi → uygulama.
    # paneru'ya entitlement gerekir (LuaJIT/MAP_JIT), diğerlerine gerekmez.
    codesign --force --options runtime --timestamp --sign "$SIGN_ID" \
        -i "$ENGINE_ID" --entitlements AppBundle/paneru.entitlements "$PANERU"
    codesign --force --options runtime --timestamp --sign "$SIGN_ID" "$RES_BUNDLE_PATH"
    codesign --force --options runtime --timestamp --sign "$SIGN_ID" "$BUNDLE"
fi

codesign --verify --deep --strict --verbose=1 "$BUNDLE"

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
