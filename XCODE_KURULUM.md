# UltimateScrollWM — Xcode Kurulum Rehberi

Bu rehberi adım adım takip et. 5-7 dakikada çalışır hale gelir.

---

## 1. Yeni Xcode Projesi Oluştur

1. Xcode’u aç
2. **File → New → Project**
3. **macOS** sekmesi → **App** seç → Next
4. Ayarlar:
   - **Product Name:** `UltimateScrollWM`
   - **Team:** Kendi hesabın
   - **Organization Identifier:** `com.seninadin` (istediğin gibi)
   - **Interface:** `SwiftUI`
   - **Language:** `Swift`
   - **Storage:** None
5. **Create**

---

## 2. App Sandbox’ı Kapat (Çok Önemli)

1. Sol tarafta proje adına tıkla (mavi ikon)
2. **TARGET** → `UltimateScrollWM` seç
3. **Signing & Capabilities** sekmesi
4. **App Sandbox** satırının yanındaki **×** ile sil  
   (Accessibility API Sandbox içinde çalışmaz)

---

## 3. Info.plist Ayarları

1. Hâlâ aynı TARGET’ta **Info** sekmesine geç
2. Şu anahtarı ekle (sağ tık → Add Row):

| Key | Type | Value |
|-----|------|-------|
| `Application is agent (UIElement)` | Boolean | `YES` |

Bu sayede Dock’ta ikon çıkmaz, sadece menü bar’da görünür.

---

## 4. Kaynak Dosyaları Ekle

1. Xcode’da sol panelde proje klasörüne sağ tıkla → **Add Files to "UltimateScrollWM"…**
2. Bu repodaki şu klasörleri ekle:

```
Sources/UltimateScrollWM/App/
Sources/UltimateScrollWM/Engine/
Sources/UltimateScrollWM/Models/
Sources/UltimateScrollWM/Views/
Sources/UltimateScrollWM/Utilities/
```

3. Seçenekler:
   - **Copy items if needed** → işaretle
   - **Create groups** → seç
   - Target: `UltimateScrollWM` işaretli olsun

4. Xcode’un otomatik oluşturduğu şu dosyaları **sil**:
   - `ContentView.swift` (varsa)
   - `UltimateScrollWMApp.swift` (Xcode’un kendi oluşturduğu — bizimkini kullanacağız)

> Not: Bizim `UltimateScrollWMApp.swift` dosyamız `@main` içeriyor.  
> Xcode’un oluşturduğu aynı isimli dosyayı mutlaka sil, yoksa “multiple main” hatası alırsın.

---

## 5. Framework Bağımlılıkları

HotKeyManager Carbon kullanıyor. Genelde otomatik linklenir ama emin olmak için:

1. TARGET → **Build Phases** → **Link Binary With Libraries**
2. `+` → `Carbon.framework` ekle (yoksa)

---

## 6. Çalıştır

1. Üstten hedef olarak **My Mac** seç
2. **⌘R** ile çalıştır
3. Menü bar’da `rectangle.split.3x1` ikonu görünmeli
4. İkona tıkla → **“İzin Ver”** butonuna bas
5. **Sistem Ayarları → Gizlilik ve Güvenlik → Erişilebilirlik**  
   listeden `UltimateScrollWM`’i aç
6. Uygulamayı bir kez kapatıp tekrar aç (⌘R)

---

## 7. Test

Birkaç uygulama aç (Safari, Notes, Terminal vb.)

- `⌃⌥ →` → sonraki pencereye geç + şerit kayar
- `⌃⌥ ←` → önceki pencereye geç
- Menü bar’dan **Aktif** anahtarını kapatıp aç (Pause/Resume)

Pencereler yan yana dizilmeli.

---

## Olası Hatalar ve Çözümleri

| Hata | Çözüm |
|------|-------|
| `Multiple commands produce...` veya `@main` hatası | Xcode’un kendi `App` dosyasını sil |
| Accessibility izni sormuyor | Sandbox’ın kapalı olduğundan emin ol |
| Kısayollar çalışmıyor | Başka bir uygulama aynı kısayolu kullanıyor olabilir. Menü bar’dan “Pencereleri Yenile” dene |
| Pencereler hareket etmiyor | Erişilebilirlik iznini kontrol et, uygulamayı yeniden başlat |
| `Carbon` bulunamadı | Build Phases’e Carbon.framework ekle |

---

## Sonraki Adım

Her şey çalışınca buraya yaz:
- “Çalıştı” veya
- Hata mesajını kopyala

Sonra v0.2’ye (Trackpad + animasyon veya Stack) geçeriz.
