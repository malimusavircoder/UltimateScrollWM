# Kurulum Kılavuzu

UltimateScrollWM — macOS için kaydırmalı (scrolling) pencere yöneticisi.
Arka planda [paneru](https://github.com/karinushka/paneru) motorunu çalıştırır.

## Gereksinimler

| | |
|---|---|
| **İşlemci** | Apple Silicon (M1 ve sonrası) — paket yalnızca `arm64` |
| **macOS** | 13 (Ventura) veya üzeri |

> Intel Mac'lerde çalışmaz. İhtiyaç olursa `x86_64` için ayrı derleme gerekir.

## Kurulum

1. `UltimateScrollWM-0.5.0.dmg` dosyasını aç (çift tıkla).
2. Açılan pencerede **UltimateScrollWM**'i **Applications** kısayoluna sürükle.
3. Diski çıkar (Finder'da yanındaki ⏏).
4. **Uygulamalar** klasöründen UltimateScrollWM'i çalıştır.

## İlk açılışta Gatekeeper uyarısı

Bu paket **notarize edilmemiştir** (kişisel kullanım için üretildi). Uygulama
Developer ID ile imzalıdır, yani kimliği doğrulanabilir — ama Apple'ın
doğrulama sunucusundan geçmediği için ilk açılışta uyarı çıkar.

Şu yollardan biriyle geç:

**A) Sistem Ayarları'ndan**
1. Uyarıyı kapat.
2. **Sistem Ayarları ▸ Gizlilik ve Güvenlik**'i aç.
3. Aşağı kaydır → *"UltimateScrollWM engellendi"* satırında **Yine de Aç**'a bas.
4. Onayla, uygulamayı yeniden çalıştır.

**B) Sağ tık ile**
Uygulamaya **sağ tıkla ▸ Aç** → çıkan uyarıda tekrar **Aç**.

**C) Terminal ile** (uyarıyı tamamen kaldırır)
```bash
xattr -dr com.apple.quarantine /Applications/UltimateScrollWM.app
```

> Yalnızca kendi makinene kopyalarken hiç uyarı çıkmayabilir; uyarı genelde
> AirDrop/indirme ile gelen dosyalarda (quarantine etiketi) görülür.

## İzin verme — en önemli adım

Uygulama **tek bir izne** ihtiyaç duyar: pencereleri taşıma yetkisi.

1. Uygulamayı çalıştırınca zaten **Ayarlar penceresi** açılır ve menü çubuğunda
   bir uyarı görünür.
2. Menü çubuğu simgesine tıkla (**▭▯▭**) → **İzin İste**'ye bas.
3. macOS'un çıkardığı pencere onay ister → **Sistem Ayarlarını Aç**.
4. **Sistem Ayarları ▸ Gizlilik ve Güvenlik ▸ Aygıt Denetimi ve Veri Erişimi**
   bölümünde **UltimateScrollWM**'i bul ve anahtarı **aç**.
   *(macOS 27'de "Erişilebilirlik" bölümünün yeni adı budur — aynı izin.)*
5. Birkaç saniye bekle. Uygulama izni kendisi fark eder ve motoru otomatik
   başlatır — **uygulamayı yeniden başlatman gerekmez**.

### Çalışıp çalışmadığını anlama

Pencereleri yan yana dizmesi gerekir. Bakmak için:

```bash
cat ~/Library/Application\ Support/UltimateScrollWM/durum.txt
```

Şunu görmelisin:
```
uygulamaErisilebilirlikIzni: true
motorIzni: true
```

### İzin "tutmuyorsa"

Nadir de olsa macOS bayat bir kaydı tutabiliyor:

1. Sistem Ayarları'nda **UltimateScrollWM** satırını **−** ile **sil**.
2. Menü çubuğundan **İzin İste**'ye bas ve izni **yeniden** ver.
3. 5–10 saniye bekle.

## Hızlı kullanım

| Kısayol | Ne yapar |
|---|---|
| `⌃⌥ →` / `⌃⌥ ←` | Şeritte sonraki / önceki pencere |
| `⌃⌥ R` | Genişliği döndür: ¼ → ⅓ → ½ → ⅔ → ¾ → tam |
| `⌃⌥ F` | Tam genişlik / geri |
| `⌃⌥ C` | Pencereyi ekranda ortala |
| `⌃⌥ T` | Karo ↔ serbest (floating) |
| `⌃⌥ ]` / `⌃⌥⇧ ]` | Stack'le / stack'ten çıkar |
| `⌃⌥ 0` | Stack yüksekliklerini eşitle |
| `⌥Tab` | Pencere seçici (`⌥` basılı tut, `Tab`'la gez, bırakınca seç) |
| `⌥Tab` → hücredeki `✕` | Seçici açıkken pencereyi kapat (`⌥` basılıyken tıkla) |

- **4 parmak yatay** kaydırma → şeridi kaydır
- **4 parmak dikey** kaydırma → sanal çalışma alanı
- Menü çubuğu → **Ayarlar…** → boşluk, çerçeve, karartma vb.
- Menü çubuğu → **Yapılandırma Dosyasını Göster** → `config.toml`'u elle düzenle
  (kaydedince anında etki eder)

### Pencere önizlemeleri (isteğe bağlı)

`⌥Tab` seçicisi pencerelerin **gerçek görüntüsünü** gösterebilir. Bunun için
menü çubuğu menüsünden **İzin İste**'ye bas ve
**Sistem Ayarları → Gizlilik ve Güvenlik → Ekran Kaydı** bölümünde
UltimateScrollWM'i aç.

- İzin verilmezse seçici yine çalışır; hücrelerde uygulama simgesi görünür.
- macOS, iznin etkili olması için **uygulamayı yeniden başlatmanı** ister.

## Kaldırma

```bash
osascript -e 'quit app "UltimateScrollWM"'
rm -rf /Applications/UltimateScrollWM.app
rm -rf ~/Library/Application\ Support/UltimateScrollWM
```

İzni de temizlemek için: Sistem Ayarları ▸ Aygıt Denetimi ve Veri Erişimi →
**UltimateScrollWM** satırını **−** ile sil.

## Sürüm yükseltme

Yeni DMG'yi açıp eskisinin üzerine sürükle. İmza kimliği sabit kaldığı için
**Erişilebilirlik izni korunur** — yeniden izin vermen gerekmez.

## Paket üretimi (geliştirici)

```bash
make dmg      # dist/UltimateScrollWM-<sürüm>.dmg
make install  # doğrudan /Applications'a
```
