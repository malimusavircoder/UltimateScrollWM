# UltimateScrollWM

macOS için **kaydırmalı (scrolling) pencere yöneticisi** — menü çubuğunda yaşayan bir
SwiftUI arayüzü, altında [Paneru](https://github.com/karinushka/paneru) motoru (MIT).

Pencereler yan yana bir şeritte durur. Yeni bir pencere açıldığında diğerleri
**küçülmez**; sıradaki boşluğa girer ve şerit, odaktaki pencereyi göstermek için kayar.

## Hızlı Başlangıç

```bash
make install
```

Bu komut release derlemesini yapar, `.app` paketini üretir, geçici dizinde
imzalar ve `/Applications/UltimateScrollWM.app` içine kurar.

İlk açılışta macOS **Aygıt Denetimi ve Veri Erişimi** izni ister (macOS 27'de
"Erişilebilirlik" bölümünün yeni adı):

```
Sistem Ayarları › Gizlilik ve Güvenlik › Aygıt Denetimi ve Veri Erişimi
```

> İzni verdikten birkaç saniye sonra motor **kendiliğinden** başlar; uygulamayı
> yeniden başlatman gerekmez. Ayrıntılı kurulum: [Docs/KURULUM.md](Docs/KURULUM.md)

Diğer komutlar:

```bash
make app      # sadece dist/UltimateScrollWM.app üretir (kurulum yapmaz)
make dmg      # dağıtılabilir DMG üretir (dist/UltimateScrollWM-<sürüm>.dmg)
make run      # kaynaktan doğrudan çalıştırır (geliştirme)
make clean    # derleme çıktılarını temizler
```

## Özellikler

- Menü çubuğu uygulaması (Dock'ta görünmez)
- Gömülü Paneru 0.5.2 motoru ile otomatik pencereleri yönetme
- Ayarlar penceresi: Genel Bakış / Pencere Düzeni / Kısayollar / Gelişmiş
- `⌥Tab` / `⌥⇧Tab` ile Alt-Tab benzeri pencere değiştirici (`⌥` basılı tut,
  `Tab` ile gez, `⌥` bırakınca seç; `Esc` iptal)
- Erişilebilirlik izni yönlendirmesi
- Mac açılışında başlatma (login item)
- Motoru yeniden başlatma, yapılandırma dosyasını açma

## Varsayılan Kısayollar

Bunlar Paneru motoru tarafından doğrudan yakalanır:

| Kısayol | İşlev |
| --- | --- |
| `⌃⌥ ← / →` | Pencereler arasında geç |
| `⌃⌥⇧ ← / →` | Aktif pencereyi sola / sağa taşı |
| `⌃⌥ R` | Genişliği değiştir |
| `⌃⌥ F` | Tam genişlik |
| `⌃⌥ C` | Ortala |
| `⌃⌥ ] / ⇧]` | Stack'e al / çıkar |
| `⌃⌥ N` | Sonraki ekrana gönder |
| `⌥ Tab` | Pencere değiştirici (bu uygulama) |

## Mimari

Uygulama bir **Paneru sarmalayıcısıdır** (TileMyMac'in yaptığı gibi): asıl pencere
yönetimini gömülü `paneru` binary'si yapar, bu uygulama ona arayüz ve kolaylık sağlar.

```
UltimateScrollWMApp (SwiftUI)
├── MenuBarView / SettingsView / WindowSwitcherView   → arayüz
├── PaneruService        → gömülü paneru'yu başlatır, send-cmd ile komut gönderir
├── HotKeyManager        → ⌥Tab kısayolları (pencere değiştirici)
├── WindowSwitcherController → ⌥Tab panelini yönetir
├── AccessibilityManager → pencere keşfi / AX izni
└── StripEngine          → native Swift motor (şu an PASİF, managesLayout = false)
```

Paneru yapılandırması: `~/Library/Application Support/UltimateScrollWM/config.toml`

## Durum ve Yol Haritası

Ayrıntılı inceleme ve önceliklendirilmiş yol haritası: **[`Docs/DURUM.md`](Docs/DURUM.md)**.

## Proje Yapısı

```
UltimateScrollWM/
├── Makefile
├── Package.swift
├── AppBundle/Info.plist            → .app paketleme şablonu
├── Scripts/build-app.sh            → .app üretici/kurucu
├── Docs/DURUM.md                   → durum + yol haritası
└── Sources/UltimateScrollWM/
    ├── App/UltimateScrollWMApp.swift
    ├── Engine/  (PaneruService, StripEngine, AccessibilityManager, HotKeyManager,
    │             WindowSwitcherController, LoginItemManager)
    ├── Models/  (StripState, WindowInfo)
    ├── Views/   (MenuBarView, SettingsView, WindowSwitcherView)
    ├── Utilities/Extensions.swift
    └── Resources/ (paneru binary, default-config.toml, lisans)
```

## Notlar

- Gömülü `paneru` binary'si MIT lisanslıdır (bkz. `Sources/UltimateScrollWM/Resources/PANERU_LICENSE.txt`).
- `XCODE_KURULUM.md` eski, elle Xcode kurulumunu anlatır; artık gerekmiyor (SwiftPM kullanılıyor).
