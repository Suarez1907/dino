# Dino Kazı

Çocuklar (yaklaşık 5–10 yaş) için reklamsız, internetsiz oynanan 3B bir kazı oyunu. Kayıp dinozor kemikleri bir kazı kampında gömülüdür. İpuçları siliktir. Her toprağın doğru bir aleti vardır. Kemikler müzede hayalet iskelete oturur. İskelet tamamlanınca dinozor uyanır, yürür, yer, kükretir ve kısa bir bilgi anlatır.

Godot **4.7.2** (GDScript, masaüstünde Forward+, Android'de Mobile renderer) asıl uygulamadır. `web/` aynı akışın Three.js ile hızlı önizlemesidir.

[Web önizleme](http://127.0.0.1:47321) bu makinede çalışıyorsa tarayıcıdan açılır. Kalıcı adres, projeyi kendin `npm run dev` ile başlattığında oluşur.

## Nasıl oynanır

1. Kazı yerini seç. İlk kamp açıktır. Bir dinozor uyanınca sıradaki kamp açılır: çöl, kanyon, orman, açıklık, buz.
2. Yürü (sol alttaki daire, ya da WASD / ok tuşları). Toprağın rengindeki küçük farka, tümseğe, kemik ucuna, çatlağa, ayak izine, ışıltıya ya da gagalayan kuşlara bak.
3. Toprak kartı hassasiyeti gösterir. İpucu düğmesi aletin adını söyler. Yanlış alet kırılgan kemikte ince bir çatlak bırakır; kemik yine de müzeye gider, yıldız azalır.
4. Aletler: kürek (gevşek), mala (sıkı), fırça (kırılgan kemik), sprey (kurumuş kil), kazma (kaya), çekiç ve keski (taş yatak). Dedektör 8 saniye dinlenir ve yakındaki noktaları çınlatır.
5. Müze çadırında kemiği tut, hayalet iskeletin üstüne bırak. Yaklaşınca yerine oturur.
6. **Canlandır.** İsim, yıldız, yürüyüş, yaprak ya da tabaktaki eti, kükreme ve altyazılı bilgi. Ses, cihazın Türkçe TTS'idir. Kayıtlı bir `.ogg` varsa o çalar (`godot/assets/voice/README.md`).

Beş dinozor, veri dosyasında: Triceratops, Velociraptor, Stegosaurus, Tiranozor, Brachiosaurus. Ad, kemikler, beslenme, Türkçe ve İngilizce bilgiler `shared/data/` içindedir. Godot kopyası `godot/data/` dosyasıdır; değiştirdikten sonra `python3 tools/sync_data.py`.

Pati ilk kazıda rehberlik eder. Pasaportta uyanan dinozorlar ve çıkartmalar durur. Ayarlarda büyük yazı, renk körü dostu şekilli ipuçları, yol oku, titreşim, parıltı ve ses vardır. Ebeveyn köşesi bir toplama sorusunun arkasındadır; süre sınırı ve ilerlemeyi sıfırlama oradadır. Kayıt `user://` altına kendi kendine yazılır.

## Godot'da açmak

1. [Godot 4.7.2](https://godotengine.org/download/archive/) kur.
2. Godot'ta **Import** ile `godot/project.godot` dosyasını aç.
3. F5. Masaüstünde Forward+ çalışır. Android dışa aktarımında renderer `mobile` olur (Vulkan, gerekirse OpenGL'e düşer).

Komut satırından içe aktarma ve kontrol:

```bash
godot --headless --path godot --import
godot --headless --path godot --quit-after 30
godot --headless --path godot -- --validate
```

`--validate` beş kampı, müze iskeletini ve veri bağlarını kurar, sonra `VALIDATE_OK` yazıp çıkar.

## Android APK

Ayrıntı: [docs/SIGNING.md](docs/SIGNING.md).

- Paket: `com.akincolak.dinokazi`
- ABI: `arm64-v8a`
- min SDK 24, target SDK 35 (Gradle açıkken)
- Ön ayar: `godot/export_presets.cfg`, ad **Android**

Yerel hata ayıklama APK'sı (Godot 4.7.2, dışa aktarma şablonları, JDK 17, Android SDK):

```bash
cd godot
godot --headless --export-debug "Android" build/dino-kazi-debug.apk
```

GitHub Actions (`.github/workflows/android-debug.yml`) `barichello/godot-ci:4.7.2` imajıyla aynı dışa aktarmayı yapar ve `dino-kazi-debug-apk` artifact'ını yükler. Akış `main`'e her itmede, `main`'e açılan pull request'lerde ve Actions sekmesinden elle (`workflow_dispatch`) çalışır. Hata ayıklama anahtarı imajın içindedir; bu iş için depo secret'ı gerekmez. Yayın anahtarı repoya konmaz.

Godot 4.7 şablonu derlemeyi Android 36 ile yapar. Uygulamanın hedeflediği seviye yine 35'tir. CI bu yüzden `platforms;android-36` ve `build-tools;36.1.0` kurar.

## Web önizleme

```bash
cd web
npm ci
npm test
npm run dev
```

Adres: `http://127.0.0.1:47321`. Üretim derlemesi `npm run build` (`web/dist`). Yerelde taban yol `/` dir. GitHub Pages derlemesi `BASE_PATH=/dino/` kullanır.

`main`'e her itmede ve elle çalıştırmada `.github/workflows/pages.yml` testi ve derlemeyi yapar, ardından `web/dist` klasörünü GitHub Pages'e yollar. Pull request'lerde yalnızca test ve derleme çalışır. Site adresi: <https://suarez1907.github.io/dino/>.

Pages'in yayınlaması için depo ayarı bir kez yapılır: **Settings → Pages → Build and deployment → Source: GitHub Actions**. Actions kapalıysa **Settings → Actions → General** altından açılır. İlk başarılı dağıtım `github-pages` ortamını oluşturur. Bu ayar yapılmadan dağıtım işi hata verir; derleme işi yine de geçer.

Kamera, aletler, toprak kartı, müze sürükle-bırak ve uyanış aynı kurallarla çalışır. `?shot=dig` gibi adresler ekran görüntüsü içindir. Konuşma `speechSynthesis` kullanır; kayıtlı ses için `web/src/audio.js`.

Görseller: [docs/concept/STYLE.md](docs/concept/STYLE.md).

## Veri ve modeller

| Dosya | İçerik |
| --- | --- |
| `shared/data/dinosaurs.json` | 5 dinozor, kemikler, renk, gerçek, ses anahtarı |
| `shared/data/sites.json` | 5 kamp, ipucu, katman, alet |
| `shared/data/catalog.json` | alet, toprak, çıkartma |
| `shared/data/strings.json` | arayüz metni, TR ve EN |

Modeller prosedüreldir. Bir `.glb` koymak için `godot/assets/models/README.md`. Lisanslar: [docs/LICENSES.md](docs/LICENSES.md). Nunito, SIL OFL 1.1.

## Sınırlar

- Dinozorlar düşük çokgen ve sevimli. Yayın kalitesinde bir iskelet için glTF takılır.
- Godot TTS, cihazda Türkçe ses yoksa altyazıyı bırakır ve sessiz kalabilir.
- SSAO ve ışıltı zayıf telefonlarda ayardan kapanır. Varsayılan açıktır.
- Bu ortamda APK üretilmedi. Şablonlar ve Android SDK CI imajında var. Yerelde `--import` ve `--validate` Godot 4.7.2 ile temiz bitti.
- Headless Godot 3B kare yazmaz. Ekran görüntüleri web prototipinden.

---

# Dino Dig

An offline, ad-free 3D dig game for children about 5–10. Dinosaur bones are buried at a camp. Clues are faint. Each soil wants a different tool. Bones snap onto a ghost skeleton in the museum. The finished dinosaur wakes, walks, eats, roars, and tells a short fact.

The Android app is Godot **4.7.2** (GDScript, Forward+ on desktop, Mobile renderer on Android). `web/` is a Three.js preview of the same loop.

## How to play

1. Pick a dig. The first camp is open. Waking a dinosaur opens the next: desert, canyon, forest, clearing, ice.
2. Walk with the circle at the bottom left, or WASD / arrow keys. Look for a slight color change, a bump, a bone tip, cracks, a footprint, a sparkle, or pecking birds.
3. The soil card shows how gentle to be. Hint speaks the tool. The wrong tool on a fragile bone leaves a small crack. The bone still goes to the museum, with fewer stars.
4. Tools: shovel (loose), trowel (compact), brush (fragile bone), spray (dried clay), pickaxe (rock), hammer and chisel (stone matrix). The detector rests for 8 seconds, then rings nearby spots.
5. In the museum tent, drag a bone onto the ghost. It snaps when you are close.
6. **Bring to life.** Name, stars, a walk, leaves or a cartoon plate of meat, a roar, and a subtitle. Speech is the device TTS. An `.ogg` file replaces that line when you add one (`godot/assets/voice/README.md`).

Five dinosaurs live in data: Triceratops, Velociraptor, Stegosaurus, T-Rex, Brachiosaurus. Names, bones, diet, and facts in Turkish and English are in `shared/data/`. Godot reads the copy in `godot/data/`. After an edit, run `python3 tools/sync_data.py`.

Pati guides the first dig. The passport keeps woken dinosaurs and stickers. Settings cover large text, shape-based color-blind clues, a guide arrow, haptics, glow, and volume. The parent corner sits behind a small addition question and holds the session timer and reset. The game writes its own save under `user://`.

## Open in Godot

1. Install [Godot 4.7.2](https://godotengine.org/download/archive/).
2. Import `godot/project.godot`.
3. Press F5. Desktop uses Forward+. The Android export uses the Mobile renderer (Vulkan, with an OpenGL fallback).

```bash
godot --headless --path godot --import
godot --headless --path godot --quit-after 30
godot --headless --path godot -- --validate
```

`--validate` builds all five camps and a museum skeleton, then prints `VALIDATE_OK`.

## Android APK

Details: [docs/SIGNING.md](docs/SIGNING.md).

- Package: `com.akincolak.dinokazi`
- ABI: `arm64-v8a`
- min SDK 24, target SDK 35 (with Gradle enabled)
- Preset name in `godot/export_presets.cfg`: **Android**

Local debug APK (Godot 4.7.2, export templates, JDK 17, Android SDK):

```bash
cd godot
godot --headless --export-debug "Android" build/dino-kazi-debug.apk
```

GitHub Actions (`.github/workflows/android-debug.yml`) runs the same export in `barichello/godot-ci:4.7.2` and uploads the `dino-kazi-debug-apk` artifact. It runs on every push to `main`, on pull requests into `main`, and from the Actions tab (`workflow_dispatch`). The debug key lives in the CI image, so this job needs no repository secrets. The release keystore stays out of the repo.

Godot 4.7's template compiles against Android 36. The app's target SDK stays 35. CI installs `platforms;android-36` and `build-tools;36.1.0` for that compiler.

## Web preview

```bash
cd web
npm ci
npm test
npm run dev
```

Open `http://127.0.0.1:47321`. `npm run build` writes `web/dist` with base path `/`. The Pages build sets `BASE_PATH=/dino/`.

On every push to `main`, and when started by hand, `.github/workflows/pages.yml` runs the tests and the build, then deploys `web/dist` to GitHub Pages. Pull requests only test and build. The site is <https://suarez1907.github.io/dino/>.

Pages will not publish until the repository setting is switched once: **Settings → Pages → Build and deployment → Source: GitHub Actions**. If Actions are disabled, turn them on under **Settings → Actions → General**. The first successful deploy creates the `github-pages` environment. Until that setting is saved, the deploy job fails and the build job still passes.

Camera, tools, the soil card, museum drag-and-snap, and the wake-up use the same rules. URLs such as `?shot=dig` frame a screenshot. Speech uses `speechSynthesis`. See `web/src/audio.js` for recorded clips.

Pictures: [docs/concept/STYLE.md](docs/concept/STYLE.md).

## Data and models

| File | Contents |
| --- | --- |
| `shared/data/dinosaurs.json` | 5 dinosaurs, bones, colors, facts, sound ids |
| `shared/data/sites.json` | 5 camps, clues, layers, tools |
| `shared/data/catalog.json` | tools, soils, stickers |
| `shared/data/strings.json` | interface copy, Turkish and English |

Models are procedural. Drop a `.glb` using `godot/assets/models/README.md`. Licenses: [docs/LICENSES.md](docs/LICENSES.md). Nunito is SIL OFL 1.1.

## Limits

- Dinosaurs are low-poly and friendly. A production skeleton can replace them with glTF.
- If the device has no Turkish TTS voice, the subtitle still shows and speech may be silent.
- SSAO and glow can be turned off for a weak phone. They start on.
- This workspace did not produce an APK. Templates and the Android SDK live in the CI image. Locally, `--import` and `--validate` completed cleanly on Godot 4.7.2.
- Headless Godot does not save a 3D frame. Screenshots are from the web prototype.
