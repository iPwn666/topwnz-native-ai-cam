# ToPwnZ - native ai cam

Nativní iOS kamera v `Swift + UIKit + AVFoundation`, cílená primárně na `iPhone + TrollStore/jailbreak` workflow bez závislosti na Apple Developer teamu. Projekt vznikl jako praktická “pro camera + Vision + AI” appka pro konkrétní zařízení, ale build a kód jsou vedené tak, aby šly dál rozšiřovat.

Veřejné repo:

- `https://github.com/iPwn666/topwnz-native-ai-cam`

## Co appka dnes umí

- live camera preview přes `AVFoundation`
- foto a long-press video
- VisionCamera-inspired camera UX:
  - pravý floating rail s kruhovými hlavními ovladači
  - větší shutter ring
  - vertikální drag na spoušti pro rychlý zoom
- pinch-to-zoom, tap-to-focus, manual focus, AE/AF lock
- ruční `EXP / SHR / ISO / FOC`
- gesture tuning: `↕` přepínání aktivního parametru + `↔` jemné ladění
- rychlý reset Pro nastavení přes `2-finger double tap` (návrat na Auto)
- focus polish:
  - při přepnutí `AF -> MF` se nově zamkne aktuální reálná poloha čočky
  - live `focus peaking` overlay při `MF` nebo focus tuningu
  - live focus score v HUD a u `AF/MF` tile
- minimalistický side-panel sheet:
  - rychlé / detekční / pro sekce
  - dvousloupcová mřížka ovládacích tiles
  - přímý `Reset` pro návrat Pro režimu na Auto
- white balance preset, night boost, `30/60 FPS`
- GPS metadata do fotek:
  - quick tile `GPS` i přepínač v nastavení
  - `when-in-use` oprávnění přes `CoreLocation`
  - zápis EXIF GPS tagů přímo do pořízených fotek
- grid, level, histogram, zebry, luma monitoring
- QR/barcode scanner s chytrými akcemi
- `Wi-Fi`, `URL`, `mailto`, `tel`, `sms`, `geo`, `FaceTime`, `vCard`, `VEVENT`
- `Scan Vault` s historií, oblíbenými položkami a AI rozborem skenů
- live OCR přes `Vision`
- OCR i nad pořízeným snímkem
- OCR/document post-processing:
  - skládání fragmentů do čistších řádků
  - extrakce `e-mail`, `telefon`, `URL`, `IBAN`, `částka`, `datum`
  - strukturovaný český výstup přímo v appce bez AI roundtripu
- document mode:
  - live rectangle detection
  - perspektivní korekce po vyfocení
- on-device live ML klasifikace scény/objektů
- frame pipeline profily:
  - `OFF`, `SMART`, `DOC`, `DET`, `FULL`
  - více on-device processorů může běžet současně
  - target FPS throttling pro Vision/Core ML processing
- české on-device labely:
  - objektová detekce i klasifikace se teď překládají do češtiny přímo v appce
- stabilnější live Core ML:
  - krátké temporální vyhlazení klasifikace i objektové detekce
  - object detection teď filtruje slabé boxy agresivněji
  - zapnutí jednoho Core ML režimu potichu předehřívá i druhý model
- runtime `Core ML` model flow:
  - appka si stáhne oficiální Apple `MobileNetV2`
  - model se zkompiluje přímo na iPhonu
  - pak se používá pro live i captured klasifikaci
- on-device objektová detekce přes `YOLOv3FP16`
  - live overlay boxy s labely
  - detekce i nad pořízeným snímkem
  - skupinové české shrnutí typu `2x osoba`, `3x auto`
  - Vision face detection se přimíchává do stejné live pipeline, takže se v overlay i výstupu ukazují i `tváře`
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

`native:install` teď preferuje USB (`127.0.0.1:2222`) a až pak zkouší Tailscale fallback.

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
- vlastní runtime `Core ML` asset path pro objektovou detekci přes Apple `YOLOv3FP16`

Model se nestaví při build time na hostu. Appka si ho připraví až na zařízení, takže i Linux/TrollStore workflow zůstává jednoduchý.

## Poznámky

- Projekt je optimalizovaný pro `iPhone XS / iOS 16.x / TrollStore`.
- Pro masovou distribuci by bylo potřeba dotáhnout signing, asset pipeline, onboarding a bezpečnější backend pro OpenAI volání.
- Pro další iterace dává největší smysl:
  - hlubší `Vision/Core ML`
  - pokročilejší video workflow
  - čistší product polish a export/import vrstvy
