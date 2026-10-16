#!/bin/bash
#
# UltimateScrollWM DMG üretici
#
# Kullanım:
#   Scripts/package-dmg.sh              # -> dist/UltimateScrollWM-<sürüm>.dmg
#   Scripts/package-dmg.sh cikti        # -> cikti/UltimateScrollWM-<sürüm>.dmg
#
# İmzalama:
#   Varsayılan kimlik Makefile üzerinden gelir (CODE_SIGN_IDENTITY).
#   Doğrudan çalıştırırsan: CODE_SIGN_IDENTITY="Developer ID Application: ..." Scripts/package-dmg.sh
#
# Not (notarization):
#   Bu betik notarization YAPMAZ. Kendi makinelerinde kurmak için gerekmez.
#   Başkalarına dağıtmak istersen: notarytool submit + staple eklenmeli ve
#   ikililer --options runtime ile imzalanmalı. DİKKAT: paneru LuaJIT kullanıyor;
#   hardened runtime açılırsa paneru için com.apple.security.cs.allow-jit
#   entitlement'ı gerekir. Bu yüzden burada runtime bayrağı kullanılmıyor.
#
set -euo pipefail

cd "$(dirname "$0")/.."

APP="UltimateScrollWM"
INFO="AppBundle/Info.plist"
VERSION="$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$INFO")"
OUT="${1:-dist}"
DMG="$OUT/$APP-$VERSION.dmg"
SIGN_ID="${CODE_SIGN_IDENTITY:--}"

echo "==> $APP $VERSION için DMG hazırlanıyor"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# 1) İmzalı .app'i geçici dizinde üret.
#    (~/Documents iCloud/fileprovider xattr ekleyebiliyor; imzalama temiz bir
#     dizinde yapılmalı, o yüzden build-app.sh'a geçici hedef veriyoruz.)
Scripts/build-app.sh "$TMP/app"

# 2) DMG içeriği: uygulama + Applications kısayolu (sürükle-bırak için).
STAGE="$TMP/dmg"
mkdir -p "$STAGE"
ditto "$TMP/app/$APP.app" "$STAGE/$APP.app"
ln -s /Applications "$STAGE/Applications"

# 3) DMG'yi oluştur.
#    macOS 27'de "hdiutil create" kullanımdan kaldırıldı; yeni komut tercih
#    edilir, desteklemeyen sistemlerde hdiutil'e düşülür.
mkdir -p "$OUT"
rm -f "$DMG"
if ! diskutil image create from --format UDZO --volumeName "$APP" "$STAGE" "$DMG" >/dev/null 2>&1; then
    hdiutil create -volname "$APP" -srcfolder "$STAGE" -ov -format UDZO "$DMG" >/dev/null
fi

# 4) DMG'yi de imzala. (Kendi makinende şart değil ama indirildiğinde
#    dosyanın kime ait olduğu görünür ve ileride notarization için hazır olur.)
if [ "$SIGN_ID" = "-" ]; then
    echo "==> DMG imzalanmadı (ad-hoc)"
else
    codesign --force --sign "$SIGN_ID" --timestamp "$DMG" >/dev/null 2>&1 \
        || codesign --force --sign "$SIGN_ID" "$DMG"
    echo "==> DMG imzalandı: $SIGN_ID"
fi

# 5) Doğrula.
if hdiutil verify "$DMG" >/dev/null 2>&1; then
    echo "==> Doğrulandı"
else
    echo "==> UYARI: DMG doğrulanamadı"
fi
echo "==> Hazır: $DMG"
echo "    Boyut: $(du -h "$DMG" | cut -f1)"
