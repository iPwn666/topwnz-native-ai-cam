# ToPwnZ - native ai cam

Nativní iOS kamera v `Swift + UIKit + AVFoundation`, cílená primárně na `iPhone + TrollStore/jailbreak` workflow bez závislosti na Apple Developer teamu. Projekt vznikl jako praktická “pro camera + Vision + AI” appka pro konkrétní zařízení, ale build a kód jsou vedené tak, aby šly dál rozšiřovat.

Veřejné repo:

- `https://github.com/iPwn666/topwnz-native-ai-cam`

## Co appka dnes umí

- live camera preview přes `AVFoundation`
- foto a long-press video
- pinch-to-zoom, tap-to-focus, manual focus, AE/AF lock
- ruční `EXP / SHR / ISO / FOC`
- white balance preset, night boost, `30/60 FPS`
- grid, level, histogram, zebry, luma monitoring
- QR/barcode scanner s chytrými akcemi
- `Wi-Fi`, `URL`, `mailto`, `tel`, `sms`, `geo`, `FaceTime`, `vCard`, `VEVENT`
- `Scan Vault` s historií, oblíbenými položkami a AI rozborem skenů
- live OCR přes `Vision`
- OCR i nad pořízeným snímkem
- document mode:
  - live rectangle detection
  - perspektivní korekce po vyfocení
- on-device live ML klasifikace scény/objektů
- runtime `Core ML` model flow:
  - appka si stáhne oficiální Apple `MobileNetV2`
  - model se zkompiluje přímo na iPhonu
  - pak se používá pro live i captured klasifikaci
- on-device objektová detekce přes `YOLOv3TinyFP16`
  - live overlay boxy s labely
  - detekce i nad pořízeným snímkem
- AI analýza přes OpenAI `Responses API`
- české UI a TTS výstup pro AI/OCR výsledky

## Aktuální architektura

Hlavní cesta je nativní appka:

- [native/AIKameraNative](/home/pwn/Dokumenty/ai-kamera-cz/native/AIKameraNative)

Vedlejší Expo/React Native větev v repu zůstává jen jako experiment:

- [App.tsx](/home/pwn/Dokumenty/ai-kamera-cz/App.tsx)

Detaily architektury jsou v:

- [docs/ARCHITECTURE.md](/home/pwn/Dokumenty/ai-kamera-cz/docs/ARCHITECTURE.md)

## Build a instalace

Požadavky na hostu:

- lokální `Swift` toolchain
- `xtool`
- importovaný Darwin/iOS SDK
- SSH/TrollStore workflow pro cílový iPhone

Build:

```bash
cd /home/pwn/Dokumenty/ai-kamera-cz
npm run native:build
```

Package do `.tipa`:

```bash
npm run native:package
```

Instalace do telefonu přes TrollStore:

```bash
npm run native:install
```

Hlavní skripty:

- [scripts/xtool-native.sh](/home/pwn/Dokumenty/ai-kamera-cz/scripts/xtool-native.sh)
- [scripts/package_native_tipa.sh](/home/pwn/Dokumenty/ai-kamera-cz/scripts/package_native_tipa.sh)
- [scripts/install_native_on_phone.sh](/home/pwn/Dokumenty/ai-kamera-cz/scripts/install_native_on_phone.sh)

## Kde je logika

- UI kamery:
  - [CameraViewController.swift](/home/pwn/Dokumenty/ai-kamera-cz/native/AIKameraNative/Sources/UI/CameraViewController.swift)
- kamera, Vision, monitoring:
  - [CameraService.swift](/home/pwn/Dokumenty/ai-kamera-cz/native/AIKameraNative/Sources/Services/CameraService.swift)
- OpenAI vrstva:
  - [OpenAIVisionService.swift](/home/pwn/Dokumenty/ai-kamera-cz/native/AIKameraNative/Sources/Services/OpenAIVisionService.swift)
- vault:
  - [ScanVaultStore.swift](/home/pwn/Dokumenty/ai-kamera-cz/native/AIKameraNative/Sources/Services/ScanVaultStore.swift)
  - [ScanVaultViewController.swift](/home/pwn/Dokumenty/ai-kamera-cz/native/AIKameraNative/Sources/UI/ScanVaultViewController.swift)
- nastavení:
  - [SettingsViewController.swift](/home/pwn/Dokumenty/ai-kamera-cz/native/AIKameraNative/Sources/UI/SettingsViewController.swift)
  - [AppSettings.swift](/home/pwn/Dokumenty/ai-kamera-cz/native/AIKameraNative/Sources/Models/AppSettings.swift)

## OpenAI

OpenAI integrace běží nad `Responses API` a používá structured JSON výstup. API klíč se ukládá lokálně do Keychainu telefonu.

Použité oficiální zdroje:

- `https://api.openai.com/v1/responses`
- `https://developers.openai.com/api/docs/guides/structured-outputs/`

## Vision / Core ML

Lokální ML teď používá dva režimy:

- systémový `Vision` pro OCR, document detection a další live requesty
- vlastní runtime `Core ML` asset path pro klasifikaci přes Apple `MobileNetV2`
- vlastní runtime `Core ML` asset path pro objektovou detekci přes Apple `YOLOv3TinyFP16`

Model se nestaví při build time na hostu. Appka si ho připraví až na zařízení, takže i Linux/TrollStore workflow zůstává jednoduchý.

## Poznámky

- Projekt je optimalizovaný pro `iPhone XS / iOS 16.x / TrollStore`.
- Pro masovou distribuci by bylo potřeba dotáhnout signing, asset pipeline, onboarding a bezpečnější backend pro OpenAI volání.
- Pro další iterace dává největší smysl:
  - hlubší `Vision/Core ML`
  - pokročilejší video workflow
  - čistší product polish a export/import vrstvy
