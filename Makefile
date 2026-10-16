# UltimateScrollWM – geliştirme komutları

.PHONY: build app install run clean

build:
	swift build -c release

# dist/UltimateScrollWM.app üretir (imzalı)
app:
	Scripts/build-app.sh dist

# /Applications içine kurar (çalışan sürümü kapatır)
install:
	Scripts/build-app.sh install

run:
	swift run

clean:
	swift package clean
	rm -rf dist
