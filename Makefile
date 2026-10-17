# UltimateScrollWM – geliştirme komutları

.PHONY: build app install dmg notarize run clean

# Kod imzalama kimliği.
# Sabit bir kimlik, Erişilebilirlik izninin yeniden derlemelerde korunmasını
# sağlar; ad-hoc imzada izin her derlemede düşer. Ad-hoc'a dönmek için:
#   make install SIGN_IDENTITY=-
SIGN_IDENTITY ?= Developer ID Application: Murat TUFAN (Z54BS9LRA2)

# notarytool kimlik profilinin adı (anahtarlıkta saklanır). Değiştirmek için:
#   make notarize NOTARY_PROFILE=profilim
NOTARY_PROFILE ?= UltimateScrollWM

build:
	swift build -c release

# dist/UltimateScrollWM.app üretir (imzalı)
app:
	CODE_SIGN_IDENTITY="$(SIGN_IDENTITY)" Scripts/build-app.sh dist

# /Applications içine kurar (çalışan sürümü kapatır)
install:
	CODE_SIGN_IDENTITY="$(SIGN_IDENTITY)" Scripts/build-app.sh install

# dağıtılabilir DMG üretir (dist/UltimateScrollWM-<sürüm>.dmg)
dmg:
	CODE_SIGN_IDENTITY="$(SIGN_IDENTITY)" Scripts/package-dmg.sh

# DMG'yi Apple'a gönderir, onayı bekler ve bileti damgalar.
# Önce kimliği bir kez kaydet (şifre güvenli istemde sorulur):
#   xcrun notarytool store-credentials $(NOTARY_PROFILE) \
#     --apple-id "APPLE_ID" --team-id "TEAM_ID"
notarize:
	CODE_SIGN_IDENTITY="$(SIGN_IDENTITY)" NOTARY_PROFILE="$(NOTARY_PROFILE)" \
		Scripts/package-dmg.sh --notarize

run:
	swift run

clean:
	swift package clean
	rm -rf dist
