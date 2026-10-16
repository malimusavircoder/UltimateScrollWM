# Durum ve Yol Haritası

Bu belge projenin 16 Ekim 2026'daki incelemesini ve önerilen sıradaki adımları özetler.

## Özet

UltimateScrollWM, **Paneru motorunu sarmalayan** bir macOS menü çubuğu uygulamasıdır.
Asıl pencere yönetimini gömülü `paneru` binary'si (0.5.2) yapar; uygulama arayüz,
pencere değiştirici, kısayol yönetimi ve paketleme sağlar. Bu, TileMyMac'in ticari
sürümünün izlediği mimarinin aynısıdır.

Uygulama çalışır durumda ve günlük kullanımda pencereleri yönetiyor.

## Mimari

| Katman | Dosya | Görev |
| --- | --- | --- |
| Arayüz | `Views/*` | Menü çubuğu, ayarlar, pencere değiştirici |
| Motor köprüsü | `Engine/PaneruService.swift` | `paneru launch` başlatır, `send-cmd` ile komut yollar |
| Kısayollar | `Engine/HotKeyManager.swift` | Yalnız `⌥Tab` (Carbon `RegisterEventHotKey`) |
| Değiştirici | `Engine/WindowSwitcherController.swift` | `⌥Tab` panelini yönetir |
| AX | `Engine/AccessibilityManager.swift` | Pencere keşfi, izin, taşıma |
| Native motor | `Engine/StripEngine.swift` | **Pasif** (`managesLayout = false`) |

Aktif yol: SwiftUI arayüz + `PaneruService` + `HotKeyManager`.
`StripEngine` ve `AccessibilityManager`'ın taşıma kısmı çalışmıyor; sadece pencere
listesini (değiştirici için) besliyor.

Paneru yapılandırması: `~/Library/Application Support/UltimateScrollWM/config.toml`

## Bugün tamamlanan iyileştirmeler

1. **Sürüm kontrolü**: `git` deposu kuruldu, başlangıç commit'i alındı.
2. **Bozuk derleme giderildi**: eski/karışık `.build` kalıntısı codesign hatası veriyordu;
   temiz yeniden derleme düzeltildi.
3. **Tekrarlanabilir paketleme**: `Makefile` + `Scripts/build-app.sh`.
   İmzalama geçici dizinde yapılıyor (proje `~/Documents` altında olduğu için
   iCloud/fileprovider dosyalara `com.apple.FinderInfo` ekliyor ve codesign bunu
   reddediyordu). Gömülü motora çalışan kurulumdaki kimlik
   (`com.local.UltimateScrollWM.engine`) veriliyor.
4. **README** gerçek SwiftPM akışına göre güncellendi.
5. **Ayarlar → `config.toml` köprüsü**: `PaneruConfig` (minimal TOML düzenleyici) +
   `SettingsStore` (tipli okuma/yazma). Arayüzdeki anahtarlar artık gerçekten paneru
   yapılandırmasına yazılıyor; paneru canlı yeniden yüklediği için değişiklikler
   anında uygulanıyor. Dosyanın geri kalanı (kısayollar, pencere kuralları, yorumlar)
   korunuyor. `PaneruConfig` gerçek `default-config.toml` üzerinde 17 testle doğrulandı.
6. **Zarif kapatma + akıllı açılış**: kapatırken paneru'ya `quit` komutu gönderiliyor
   (gerekirse SIGTERM/SIGINT ile zorlanıyor); ayarlar penceresi artık her açılışta
   değil, yalnızca ilk açılışta, `--settings` bayrağıyla veya izin eksikken açılıyor.
7. **Karartma anahtarı düzeltildi**: yalnızca gündüz değerini (`opacity`) yazıyordu;
   gece değeri (`opacity_night`) dokunulmadığı için gece modunda karartma geri
   geliyordu. Artık ikisi birlikte yazılıyor. Ayrıca `SettingsStore.batch()` ile
   boşluk kaydırıcısı 4 ayrı dosya yazımı yerine tek yazım yapıyor.

## Tespit edilen sorunlar

### Yüksek öncelik

| # | Sorun | Yer |
| --- | --- | --- |
| ✅ | ~~`@AppStorage` anahtarları işlevsizdi~~ → `SettingsStore` ile `config.toml`'a bağlandı | çözüldü |
| ✅ | ~~Gap kaydırıcısı etkisizdi~~ → `[padding]` değerlerine yazıyor | çözüldü |
| ✅ | ~~`stop()` SIGINT gönderiyordu~~ → önce `send-cmd quit`, gerekirse SIGTERM/SIGINT | çözüldü |
| 4 | Motor her **0.8 sn**'de tüm pencereleri AX ile tarıyor, sadece değiştirici paneli için → gereksiz maliyet | `StripEngine.swift:38` |

### Orta öncelik

| # | Sorun | Yer |
| --- | --- | --- |
| ✅ | ~~Her açılışta ayarlar penceresi otomatik açılıyordu~~ → yalnızca ilk açılış / `--settings` / izin eksikse | çözüldü |
| 6 | `⌥Tab` global olarak çalınıyor → diğer uygulamalarda `⌥Tab` işlevi eziliyor | `HotKeyManager.swift` |
| 7 | Değiştirici, son tuştan **0.9 sn** sonra sabit gecikmeyle onaylıyor; "⌥ bırakınca seç" yok | `WindowSwitcherController.swift:69` |
| 8 | `focusedWindow()` `unsafeBitCast` kullanıyor (kırılgan) | `AccessibilityManager.swift:106` |
| 9 | Yinelenen minimized kontrolü (`isWindowVisible` + `isMinimized`) | `AccessibilityManager.swift:133` |
| 10 | Sürüm metni arayüzde sabit yazılı | `SettingsView.swift` |
| 11 | `default-config.toml` pencere kuralları Paneru şemasına göre doğrulanmalı | `Resources/default-config.toml` |
| 12 | `XCODE_KURULUM.md` güncelliğini yitirmiş | kök |

### Düşük öncelik

- Güncelleme kontrolü yok.
- Paneru sürümü elle gömülü; yükseltme akışı yok.
- Native `StripEngine`'in geleceği belirsiz (bitirilsin mi, kaldırılsın mı?).

## İmzalama ve Erişilebilirlik izni

`make install` uygulamayı **ad-hoc** (`codesign --sign -`) imzalar. Bu durumda macOS,
Erişilebilirlik iznini ikili dosyanın parmak izine (CDHash) bağlar; kod her
derlendiğinde parmak izi değişir ve izni yeniden vermek gerekir.

Kalıcı çözüm, sabit bir kimlikle imzalamaktır — bu makinede mevcut olan Developer ID
ile tek satır yeterlidir:

```bash
CODE_SIGN_IDENTITY="Developer ID Application: Ad Soyad (TEAMID)" make install
```

Böylece macOS izni sertifikaya bağlar ve yeniden derlemeler izni bozmaz.
(`Scripts/build-app.sh` bu değişkeni okur; değer verilmezse ad-hoc'a düşer.)

## Önerilen yol haritası

1. ✅ **Ayarlar → `config.toml` köprüsü.** Tamamlandı (bkz. yukarı). Genişletilebilir:
   kısayol düzenleyici, pencere kuralları (per-app), ileri düzey paneru seçenekleri.
2. ✅ **Zarif kapatma.** Çıkışta `send-cmd quit` gönderiliyor.
3. ✅ **Açılış davranışı.** Ayarlar penceresi yalnızca ilk açılışta (veya `--settings`
   bayrağıyla) gösteriliyor.
4. **Pencere değiştirici.** `⌥` bırakılınca seçimi onayla; istenirse gerçek pencere
   önizlemeleri (CGWindowList) ekle.
5. **Olay tabanlı tazeleme.** 0.8 sn polling yerine `AXObserver` + panel açılışında tazeleme.
6. **İlk kurulum sihirbazı.** İzin/eksik ayar kontrolü ("Mac Setup check").
7. **Karar**: `StripEngine` bitirilecek mi (paneru'suz çalışma) yoksa kaldırılacak mı?
