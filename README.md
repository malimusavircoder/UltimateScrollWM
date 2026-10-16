# UltimateScrollWM – MVP v0.1

macOS Scrolling Window Manager  
(TileMyMac + ChainYourMac birleşimi – ilk çalışır sürüm)

## Hızlı Başlangıç

**→ `XCODE_KURULUM.md` dosyasını aç ve adım adım takip et.**

Orada Xcode projesi oluşturma, Sandbox kapatma, dosya ekleme ve test etme adımları var.

## MVP Özellikleri

- Menü bar uygulaması
- Accessibility izni isteme
- Pencereleri otomatik keşfetme
- Yatay şeritte dizme
- `⌃⌥ ←` / `⌃⌥ →` ile gezinme
- Yeni pencereyi otomatik ekleme
- Pause / Resume
- Gap + varsayılan genişlik ayarı

## Proje Yapısı

```
UltimateScrollWM/
├── XCODE_KURULUM.md          ← Buradan başla
├── README.md
├── Package.swift
└── Sources/UltimateScrollWM/
    ├── App/
    │   └── UltimateScrollWMApp.swift
    ├── Engine/
    │   ├── AccessibilityManager.swift
    │   ├── StripEngine.swift
    │   └── HotKeyManager.swift
    ├── Models/
    │   ├── WindowInfo.swift
    │   └── StripState.swift
    ├── Views/
    │   ├── MenuBarView.swift
    │   └── SettingsView.swift
    └── Utilities/
        └── Extensions.swift
```

## Sonraki Sürümler

- v0.2 → Trackpad swipe + spring animasyon
- v0.3 → Stack + Tabbed columns
- v0.4 → Multi-monitor + layout restore
- v0.5 → Per-app rules + minimap

## Not

Bu kod Linux sandbox’ında yazıldı. Derleme ve test senin Mac’inde Xcode ile yapılacak.
