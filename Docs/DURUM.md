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
8. **Tanılama + izin bekçisi**: `Engine/Diagnostics.swift` uygulamanın
   Erişilebilirlik durumunu `~/Library/Application Support/UltimateScrollWM/durum.txt`
   dosyasına yazar; motorun çıktısı `paneru.log`'a gider. İzin eksikse uygulama 3
   saniyede bir yoklar ve izin gelir gelmez motoru kendisi canlandırır — böylece
   Sistem Ayarları'ndan sonra yeniden başlatmak gerekmez.
9. **Varsayılan config'deki kısayol hatası**: `window_stack` / `window_unstack`
   için `]` yazıyordu; paneru'nun tuş adları arasında `]` yok, bu yüzden
   `invalid key ']'` hatası verip **iki kısayolu sessizce devre dışı bırakıyordu**.
   Doğru ad `rightbracket` (paneru `src/config.rs` sanal tuş haritasından
   doğrulandı). Şablon ve canlı yapılandırma düzeltildi.
10. **Pencere değiştirici düzeltmesi**: Seçici, son tuştan 0.9 sn sonra
    kendiliğinden onaylıyordu; bu yüzden "hemen kapanıyor" gibi görünüp
    gezmek imkânsızdı. Artık macOS `⌘Tab` mantığı var: `⌥` basılı tutulur,
    `Tab` ile gezilir, **`⌥` bırakılınca seçim uygulanır**; `Esc` iptal eder.
    (`⌥` bırakılışı global `flagsChanged` izleyicisiyle yakalanır; kaçırılırsa
    10 sn'lik emniyet zamanlayıcısı paneli kapatır.)
11. **DMG paketleme**: `Scripts/package-dmg.sh` + `make dmg`. Uygulama ve gömülü
    `paneru` Developer ID ile imzalanır, sürükle-bırak DMG üretilir, DMG'nin
    kendisi de imzalanır ve doğrulanır. Kurulum kılavuzu: `Docs/KURULUM.md`.
    Notarization yok (kişisel kullanım); paket yalnızca `arm64`.
12. **Pencere seçici düzeltmesi (⌥Tab)**: Seçici yalnızca iki pencere arasında
    gidip geliyordu ve en fazla 6 pencere gösteriyordu. İki neden vardı:
    (a) 0.8 sn'lik yoklama sayacı ile her basışta çağrılan `refreshWindows()`
    seçimi **gerçek odaktaki pencereye geri sıfırlıyordu** — `Tab` → o+1, sayaç
    sıfırla, `Tab` → yine o+1;
    (b) panelde `min(count, 6)` sınırı vardı.
    Artık liste **oturum başında bir kez** alınır (`beginSwitcherSession`),
    seçici açıkken `refreshWindows` hiç çalışmaz, panel ızgara hâlinde **tüm
    pencereleri** gösterir ve `⌘M` ile simge durumuna küçültülmüş pencereler de
    listelenir (⊖ işaretiyle) — seçilince `raiseWindow` önce uygulamayı öne
    getirip sonra minimize'i kaldırır. Seçicinin gördüğü liste, dışarıdan
    doğrulanabilsin diye `secici.txt` dosyasına yazılır.
13. **Masaüstü filtresi**: Finder'ın masaüstü "penceresi" (başlıksız, ekran
    boyutunda) `⌥Tab` listesinden çıkarıldı — 10 pencere 9'a indi. Filtre
    başlık + boyut + uygulama kimliği üçlüsünü **birlikte** arar, böylece
    gerçek Finder pencereleri yanlışlıkla elenmez. Boyut her ekranla **tek tek**
    karşılaştırılır: ekranların birleşik alanıyla karşılaştırılsaydı çok ekranlı
    kurulumda hiçbir masaüstü birleşik alanı kaplamadığı için filtre çalışmazdı.
    `WindowInfo`'ya `subrole` alanı eklendi ve `secici.txt`'e "rol" sütunu olarak
    yazılıyor (gözlem: hepsi `AXStandardWindow` — yani filtreyi role dayamak
    ayrım sağlamazdı).
14. **Olay tabanlı tazeleme**: 0.8 sn'lik yoklama sayacı kaldırıldı. Pencere
    düzenini paneru yaptığı için (`managesLayout = false`) bu motorun pencere
    listesi **yalnızca arayüzü** besliyordu (menü çubuğundaki pencere sayısı,
    seçici) — buna rağmen her 0.8 sn'de tüm uygulamaların pencereleri
    Erişilebilirlik API'siyle taranıyordu. Artık tazeleme yalnızca:
    `NSWorkspace` bildirimleri (uygulama açıldı/kapandı/ön plana geldi,
    gizlendi/gösterildi, çalışma alanı değişti), menü her açıldığında
    (`onAppear`) ve seçici oturumu başında. Bildirimler 0.35 sn'de birleştirilir.
    **Ölçüm**: uygulama boşta 15 saniyede **0.00 s** CPU harcadı (öncesinde
    sürekli tarama vardı).

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

`make install` uygulamayı makinede bulunan **Developer ID** kimliğiyle imzalar
(`Makefile` içindeki `SIGN_IDENTITY`). Ad-hoc'a dönmek için `make install SIGN_IDENTITY=-`.

Bu önemli, çünkü ad-hoc imzada (`codesign --sign -`) macOS Erişilebilirlik iznini
ikili dosyanın parmak izine (CDHash) bağlar; kod her derlendiğinde parmak izi
değişir ve izni elle yeniden vermek gerekir. Sabit bir kimlikte macOS izni
sertifikaya bağlar ve izin yeniden derlemelerde korunur.
(`Scripts/build-app.sh` `CODE_SIGN_IDENTITY` değişkenini okur.)

### İzin verirken dikkat

- **macOS 27**, "Erişilebilirlik" bölümünü **"Aygıt Denetimi ve Veri Erişimi"**
  olarak yeniden adlandırdı. Aynı izin, aynı anahtar — sadece adı değişti.
  paneru da hatasında bu yeni adı kullanır.
- İmza kimliği değiştiğinde (ör. ad-hoc → Developer ID) izin bir kez daha
  istenir; macOS `AXIsProcessTrusted` yanıtını **süreç başına önbelleğe** aldığı
  için bayat kaydı **`−` ile silip uygulamanın kendi isteğiyle** yeniden
  eklemek gerekebilir. Anahtarı kapat-aç tek başına yetmeyebilir.
- Sorun çıkarsa tek bakılacak yer: `durum.txt` ve `paneru.log`.

## Dağıtım (DMG) ve bilinen kısıtlar

`make dmg` → `dist/UltimateScrollWM-<sürüm>.dmg`. Uygulama ve gömülü `paneru`
Developer ID ile imzalanır, DMG'nin kendisi de imzalanır ve doğrulanır.
DMG'deki uygulamanın *Designated Requirement*'ı kurulu sürümle birebir aynı
olduğu için **Erişilebilirlik izni güncellemede korunur**.
Son kullanıcı kılavuzu: `Docs/KURULUM.md`.

### Not 1 — Paket yalnızca `arm64` (Intel Mac'lerde çalışmaz)

Hem uygulama hem gömülü `paneru` `arm64` olarak derleniyor. Evrensel (universal)
paket gerekirse:

1. Rust hedefini ekle: `rustup target add x86_64-apple-darwin`
2. paneru'yu iki mimari için derle:
   `cargo build --release --target aarch64-apple-darwin` ve
   `cargo build --release --target x86_64-apple-darwin`
3. İkisini birleştir:
   `lipo -create -output paneru <arm64>/paneru <x86_64>/paneru`
4. Uygulamayı evrensel derle: `swift build -c release --arch arm64 --arch x86_64`
5. `Scripts/build-app.sh` kopyalama adımı evrensel ikiliyle olduğu gibi çalışır.

### Not 2 — Notarization (başkalarına dağıtım için)

Şu an **notarize edilmiyor** (kişisel kullanım); bu yüzden başka bir Mac'te ilk
açılışta Gatekeeper uyarısı çıkar (çözümü `Docs/KURULUM.md`'de). Dağıtmak
istenirse:

1. Kimlik bilgisi kaydet (Apple Developer hesabı gerekir):
   `xcrun notarytool store-credentials`
   (uygulamaya özel parola **veya** App Store Connect API anahtarı)
2. İkileri hardened runtime ile imzala: `codesign --options runtime --timestamp`
3. Gönder: `xcrun notarytool submit <dosya> --keychain-profile <ad> --wait`
4. Bileti iliştir: `xcrun stapler staple <dosya>`

> ⚠️ **Tuzak:** paneru **LuaJIT** ile derlenmiştir; Lua betiği kullanıldığında
> JIT çalışması gerekir ve hardened runtime bunu engeller. Bu yüzden paneru'ya
> `com.apple.security.cs.allow-jit` (gerekirse ayrıca
> `com.apple.security.cs.allow-unsigned-executable-memory`) entitlement'ı
> verilmelidir. Şimdilik `Scripts/package-dmg.sh` runtime bayrağını
> kullanmıyor — notarization'a geçilirse önce bu entitlement eklenmeli.

## Önerilen yol haritası

1. ✅ **Ayarlar → `config.toml` köprüsü.** Tamamlandı (bkz. yukarı). Genişletilebilir:
   kısayol düzenleyici, pencere kuralları (per-app), ileri düzey paneru seçenekleri.
2. ✅ **Zarif kapatma.** Çıkışta `send-cmd quit` gönderiliyor.
3. ✅ **Açılış davranışı.** Ayarlar penceresi yalnızca ilk açılışta (veya `--settings`
   bayrağıyla) gösteriliyor.
4. ✅ **Pencere değiştirici.** `⌥` bırakılınca onaylama yapıldı (bkz. 10. madde).
   Kalan isteğe bağlı iş: gerçek pencere önizlemeleri (CGWindowList).
5. ✅ **Olay tabanlı tazeleme.** 0.8 sn'lik yoklama kaldırıldı; `NSWorkspace`
   bildirimleri + menü açılışı (bkz. 14. madde).
6. **İlk kurulum sihirbazı.** İzin/eksik ayar kontrolü ("Mac Setup check").
7. **Karar**: `StripEngine` bitirilecek mi (paneru'suz çalışma) yoksa kaldırılacak mı?
