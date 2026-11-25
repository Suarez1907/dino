# Dino Kazı — Notlar

Çocuklar için 3B dinozor kazı/müze oyunu. Godot 4 (4.7.2 CI) Android APK + web (Vite) prototipi.

## Yapı
- `godot/` — Godot projesi (ana uygulama). `project.godot`, `scripts/`, `data/`, `assets/`.
- `shared/data/` — kaynak JSON (catalog, dinosaurs, sites, strings); `tools/sync_data.py` ile `godot/data/`'a kopyalanır.
- `web/` — Vite/JS web prototipi (aynı içerik, `web/src/content.js`).
- `.github/workflows/` — android-debug.yml, android-release.yml (tag/workflow_dispatch), pages.yml (Web prototype → GitHub Pages).

## Derleme / test
- Android: Actions "Android debug APK" (push) veya "Android Release APK" (`v*` tag ya da dispatch, `version` input).
- Web: `cd web && npm ci && npm test && npm run build` (BASE_PATH=/dino/).
- Veri doğrulama: `python tools/validate_data.py`.

## Tuzaklar
- Godot sürümü 4.7.2'ye sabit (`barichello/godot-ci:4.7.2`); `config/features` "4.8" der, karıştırma.
- GitHub Pages API ile `build_type=workflow` olarak AÇIK olmalı; kapalıysa pages.yml "Deploy to GitHub Pages" 404/"Not Found" verir.
- Release imzalama: repo secret'larında gerçek keystore yok; workflow debug-key fallback kullanır.
- `shared/data/*.json` ile `godot/data/*.json` senkron kalmalı (tools/sync_data.py çalıştır).
