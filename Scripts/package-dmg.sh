#!/bin/bash
#
# UltimateScrollWM DMG üretici
#
# Kullanım:
#   Scripts/package-dmg.sh              # -> dist/UltimateScrollWM-<sürüm>.dmg
#   Scripts/package-dmg.sh cikti        # -> cikti/UltimateScrollWM-<sürüm>.dmg
#   Scripts/package-dmg.sh --notarize   # Apple'a gönder + damgala (aşağıya bak)
#
# İmzalama:
#   Varsayılan kimlik Makefile üzerinden gelir (CODE_SIGN_IDENTITY).
#   Doğrudan çalıştırırsan: CODE_SIGN_IDENTITY="Developer ID Application: ..." Scripts/package-dmg.sh
#
# Notarization (--notarize):
#   Developer ID ile imzalanan paketlerde artık **hardened runtime** açıktır
#   (build-app.sh). paneru LuaJIT kullandığı için AppBundle/paneru.entitlements
#   ile com.apple.security.cs.allow-jit verilir — yoksa paneru çalışmaz.
#
#   Önce kimliği anahtarlığa kaydet (bir kez, şifre güvenli istemde sorulur):
#     xcrun notarytool store-credentials UltimateScrollWM \
#       --apple-id "APPLE_ID" --team-id "TEAM_ID"
#
#   Sonra:  make notarize         (veya NOTARY_PROFILE=... ile başka profil)

#
set -euo pipefail

cd "$(dirname "$0")/.."

APP="UltimateScrollWM"
INFO="AppBundle/Info.plist"
VERSION="$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$INFO")"
NOTARY_PROFILE="${NOTARY_PROFILE:-UltimateScrollWM}"

# Argümanlar: [--notarize] [çıktı dizini]
NOTARIZE=0
OUT="dist"
for arg in "$@"; do
    case "$arg" in
        --notarize) NOTARIZE=1 ;;
        *) OUT="$arg" ;;
    esac
done

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

# 6) Notarization: Apple'a gönder, onayı bekle ve bilet damgala.
#    Damgalanmış DMG çevrimdışıyken bile Gatekeeper'dan uyarısız geçer.
if [ "$NOTARIZE" = 1 ]; then
    if [ "$SIGN_ID" = "-" ]; then
        echo "==> HATA: notarization için Developer ID kimliği gerekir." >&2
        exit 1
    fi

    echo "==> Apple'a gönderiliyor (profil: $NOTARY_PROFILE) — birkaç dakika sürebilir"
    if ! xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait; then
        echo "==> HATA: gönderim/onay başarısız. Ayrıntı için: xcrun notarytool log <id> --keychain-profile $NOTARY_PROFILE" >&2
        exit 1
    fi

    echo "==> Bilet damgalanıyor"
    xcrun stapler staple "$DMG"
    xcrun stapler validate "$DMG"

    # Gatekeeper gerçekten kabul ediyor mu? (asıl kanıt bu)
    if spctl --assess --type install --verbose=2 "$DMG"; then
        echo "==> Gatekeeper: kabul edildi (notarized)"
    else
        echo "==> UYARI: Gatekeeper hâlâ reddediyor" >&2
    fi
fi

echo "==> Hazır: $DMG"
echo "    Boyut: $(du -h "$DMG" | cut -f1)"
