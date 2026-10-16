# UltimateScrollWM – geliştirme komutları

.PHONY: build app install dmg run clean

# Kod imzalama kimliği.
# Sabit bir kimlik, Erişilebilirlik izninin yeniden derlemelerde korunmasını
# sağlar; ad-hoc imzada izin her derlemede düşer. Ad-hoc'a dönmek için:
#   make install SIGN_IDENTITY=-
SIGN_IDENTITY ?= Developer ID Application: Murat TUFAN (Z54BS9LRA2)

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

run:
	swift run

clean:
	swift package clean
	rm -rf dist
