# Architecture

## Goal

`ToPwnZ - native ai cam` je nativní kamera pro iPhone s důrazem na tři vrstvy:

- rychlá live kamera a ruční kontrola
- on-device `Vision`/ML pipeline bez cloudu
- cloud AI workflow přes OpenAI jen tam, kde to dává smysl

## Runtime vrstvy

### 1. Camera Core

Soubor:

- [CameraService.swift](/home/pwn/Dokumenty/ai-kamera-cz/native/AIKameraNative/Sources/Services/CameraService.swift)

Použitá technologie:

- `AVCaptureSession`
- `AVCapturePhotoOutput`
- `AVCaptureMovieFileOutput`
- `AVCaptureMetadataOutput`
- `AVCaptureVideoDataOutput`

Zodpovědnost:

- preview session
- capture photo/video
- flip camera
- zoom
- autofocus/manual focus
- exposure bias
- manual ISO
- manual shutter
- white balance
- AE/AF lock
- scanner rect of interest

### 2. Live Assist Pipeline

Stejný `AVCaptureVideoDataOutput` se používá jako zdroj framů pro live analýzu:

- histogram + luma
- zebra overlay
- live OCR
- document rectangle detection
- live ML klasifikace

Pipeline je throttleovaná, aby byla použitelná i na `iPhone XS`.

### 3. Vision / On-device intelligence

Současné `Vision` requesty:

- `VNRecognizeTextRequest`
- `VNDetectRectanglesRequest`
- `VNClassifyImageRequest`

Tyto requesty běží:

- nad live preview framy
- nebo nad pořízeným snímkem po capture

To umožňuje:

- live OCR boxy nad preview
- document outline a následnou perspektivní korekci
- lokální klasifikaci scény/objektů
- live objektovou detekci s boxy a labely

### 4. Runtime Core ML model path

Soubor:

- [CoreMLModelInstaller.swift](/home/pwn/Dokumenty/ai-kamera-cz/native/AIKameraNative/Sources/Services/CoreMLModelInstaller.swift)

Pro klasifikaci a detekci už appka nepoužívá jen systémové requesty. Nově umí:

- stáhnout oficiální Apple `MobileNetV2FP16.mlmodel`
- stáhnout oficiální Apple `YOLOv3TinyFP16.mlmodel`
- zkompilovat ho přímo na iPhonu přes `MLModel.compileModel(at:)`
- načíst ho jako `VNCoreMLModel`
- použít ho pro live i captured classification
- použít ho pro live i captured object detection

To je důležité proto, že build host je Linux a nechceme být závislí na macOS/Xcode asset compiler pipeline.

## UI vrstva

Soubor:

- [CameraViewController.swift](/home/pwn/Dokumenty/ai-kamera-cz/native/AIKameraNative/Sources/UI/CameraViewController.swift)

UI je rozdělené na:

- full-screen preview
- compact HUD
- capture controls
- result card
- side tools panel

Tools panel je zjednodušený do sekcí:

- `Quick`
- `Detect`
- `Pro`

To drží méně aktivních voleb najednou a snižuje kognitivní zátěž.

## Scanner

Scanner používá:

- `AVCaptureMetadataOutput` pro QR/barcode
- vlastní parser nad payloadem

Podporované typy:

- URL
- e-mail
- telefon
- SMS
- Wi‑Fi
- geolokace
- FaceTime
- vCard / MECARD
- VEVENT

Nad výsledkem se vrství:

- primary action
- copy/share
- vault persist
- AI follow-up

## Scan Vault

Soubory:

- [ScanVaultStore.swift](/home/pwn/Dokumenty/ai-kamera-cz/native/AIKameraNative/Sources/Services/ScanVaultStore.swift)
- [ScanVaultViewController.swift](/home/pwn/Dokumenty/ai-kamera-cz/native/AIKameraNative/Sources/UI/ScanVaultViewController.swift)
- [ScanVaultDetailViewController.swift](/home/pwn/Dokumenty/ai-kamera-cz/native/AIKameraNative/Sources/UI/ScanVaultDetailViewController.swift)

Vault ukládá:

- raw scan
- typ
- oblíbené
- AI rozbor
- metadata

## OpenAI vrstva

Soubor:

- [OpenAIVisionService.swift](/home/pwn/Dokumenty/ai-kamera-cz/native/AIKameraNative/Sources/Services/OpenAIVisionService.swift)

Používá se pouze pro:

- hlubší rozbor pořízeného snímku
- follow-up otázky
- AI rozbor skenů

Cloud AI není nutný pro:

- live OCR
- document detection
- live ML klasifikaci
- scanner workflow

## Distribution

Preferovaná distribuce:

- build na Linux hostu
- package do `.tipa`
- instalace přes `TrollStore`

Skripty:

- [package_native_tipa.sh](/home/pwn/Dokumenty/ai-kamera-cz/scripts/package_native_tipa.sh)
- [install_native_on_phone.sh](/home/pwn/Dokumenty/ai-kamera-cz/scripts/install_native_on_phone.sh)

## Next reasonable steps

- hlubší `Core ML` s vlastním bundlovaným nebo staženým modelem
- live object detection místo čisté klasifikace
- document export pipeline
- lepší video overlay a profily
- product polish a onboarding
