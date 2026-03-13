import Foundation

enum AppStrings {
    static var isCzech: Bool {
        Locale.preferredLanguages.first?.hasPrefix("cs") == true
    }

    static var brand: String { "ToPwnZ - native ai cam" }
    static var title: String { isCzech ? "Nativní kamera s AI" : "Native camera with AI" }
    static var settings: String { isCzech ? "Nastavení" : "Settings" }
    static var scanVault: String { isCzech ? "Scan Vault" : "Scan Vault" }
    static var vaultEmpty: String { isCzech ? "Vault je zatím prázdný." : "The vault is empty." }
    static var vaultAll: String { isCzech ? "Vše" : "All" }
    static var vaultFavorites: String { isCzech ? "Oblíbené" : "Favorites" }
    static var vaultWithAI: String { isCzech ? "S AI" : "With AI" }
    static var vaultDetail: String { isCzech ? "Detail skenu" : "Scan detail" }
    static var capture: String { isCzech ? "Vyfotit" : "Capture" }
    static var retake: String { isCzech ? "Nový snímek" : "Retake" }
    static var analyze: String { isCzech ? "Analyzovat" : "Analyze" }
    static var analyzeScan: String { isCzech ? "AI sken" : "AI scan" }
    static var askAI: String { isCzech ? "Zeptat se AI" : "Ask AI" }
    static var askAISend: String { isCzech ? "Poslat" : "Send" }
    static var askAITitle: String { isCzech ? "Dotaz k aktuálnímu záběru" : "Question about the current capture" }
    static var askAIPlaceholder: String { isCzech ? "Na co se chceš zeptat?" : "What do you want to ask?" }
    static var askAIMessage: String { isCzech ? "AI dostane aktuální snímek nebo sken a odpoví česky." : "AI will use the current image or scan and answer in English." }
    static var aiAnswerTitle: String { isCzech ? "AI odpověď" : "AI answer" }
    static var speakResult: String { isCzech ? "Přečíst" : "Speak" }
    static var stopSpeaking: String { isCzech ? "Zastavit hlas" : "Stop speech" }
    static var analyzing: String { isCzech ? "Analyzuji..." : "Analyzing..." }
    static var capturing: String { isCzech ? "Fotím..." : "Capturing..." }
    static var recording: String { isCzech ? "Nahrávám..." : "Recording..." }
    static var videoReady: String { isCzech ? "Video připraveno" : "Video ready" }
    static var scannerReady: String { isCzech ? "Scanner aktivní" : "Scanner ready" }
    static var codeDetected: String { isCzech ? "Kód zachycen" : "Code detected" }
    static var scannerAimHint: String { isCzech ? "Zarovnej QR nebo čárový kód do rámečku." : "Align the QR or barcode inside the frame." }
    static var flashOn: String { isCzech ? "Blesk zap" : "Flash on" }
    static var flashOff: String { isCzech ? "Blesk vyp" : "Flash off" }
    static var flash: String { isCzech ? "Blesk" : "Flash" }
    static var torchOn: String { isCzech ? "Světlo zap" : "Torch on" }
    static var torchOff: String { isCzech ? "Světlo vyp" : "Torch off" }
    static var flipCamera: String { isCzech ? "Přepnout" : "Flip" }
    static var zoom: String { isCzech ? "Zoom" : "Zoom" }
    static var fps: String { isCzech ? "FPS" : "FPS" }
    static var nightModeOn: String { isCzech ? "Noční režim zap" : "Night mode on" }
    static var nightModeOff: String { isCzech ? "Noční režim vyp" : "Night mode off" }
    static var night: String { isCzech ? "Noc" : "Night" }
    static var scannerOn: String { isCzech ? "Scanner zap" : "Scanner on" }
    static var scannerOff: String { isCzech ? "Scanner vyp" : "Scanner off" }
    static var scanner: String { isCzech ? "Sken" : "Scan" }
    static var locationMetadata: String { isCzech ? "GPS tagy" : "GPS tags" }
    static var locationMetadataOn: String { isCzech ? "GPS tagy zap" : "GPS tags on" }
    static var locationMetadataOff: String { isCzech ? "GPS tagy vyp" : "GPS tags off" }
    static var locationWaiting: String { isCzech ? "Čekám na polohu" : "Waiting for location" }
    static var locationBlocked: String { isCzech ? "Poloha blokována" : "Location blocked" }
    static var locationPermissionDenied: String { isCzech ? "Přístup k poloze je zamítnutý." : "Location access is denied." }
    static var locationHint: String { isCzech ? "Do fotek se uloží GPS metadata." : "GPS metadata will be embedded into photos." }
    static var liveOCR: String { isCzech ? "Live OCR" : "Live OCR" }
    static var liveOCRReady: String { isCzech ? "OCR aktivní" : "OCR ready" }
    static var liveOCRHint: String { isCzech ? "Klepni na textový blok pro výběr." : "Tap a text block to select it." }
    static var liveOCRText: String { isCzech ? "Live text" : "Live text" }
    static var liveOCRNoText: String { isCzech ? "Zatím žádný text." : "No text yet." }
    static var liveML: String { isCzech ? "Live ML" : "Live ML" }
    static var liveMLReady: String { isCzech ? "ML aktivní" : "ML ready" }
    static var liveMLHint: String { isCzech ? "Lokální klasifikace scény běží přímo v zařízení." : "On-device scene classification is running locally." }
    static var liveMLText: String { isCzech ? "Live klasifikace" : "Live classification" }
    static var liveMLNoResult: String { isCzech ? "Zatím bez klasifikace." : "No classification yet." }
    static var capturedMLText: String { isCzech ? "Klasifikace snímku" : "Captured classification" }
    static var capturedMLHint: String { isCzech ? "Scéna byla klasifikována lokálně v zařízení." : "The scene was classified locally on-device." }
    static var objectDetect: String { isCzech ? "Objekty" : "Objects" }
    static var objectDetectReady: String { isCzech ? "Detekce objektů aktivní" : "Object detection ready" }
    static var objectDetectHint: String { isCzech ? "Lokální detekce objektů běží přímo v zařízení." : "On-device object detection is running locally." }
    static var objectDetectText: String { isCzech ? "Detekované objekty" : "Detected objects" }
    static var objectDetectNoResult: String { isCzech ? "Zatím bez objektů." : "No objects yet." }
    static var capturedObjectText: String { isCzech ? "Objekty ze snímku" : "Captured objects" }
    static var capturedObjectHint: String { isCzech ? "Objekty byly detekované lokálně v zařízení." : "Objects were detected locally on-device." }
    static var coreMLPreparing: String { isCzech ? "Připravuji Core ML model" : "Preparing Core ML model" }
    static var coreMLReady: String { isCzech ? "Core ML model připraven" : "Core ML model ready" }
    static var coreMLHint: String { isCzech ? "Stáhne se a zkompiluje oficiální Apple MobileNetV2 model." : "The official Apple MobileNetV2 model will be downloaded and compiled." }
    static var documentMode: String { isCzech ? "Dokument" : "Document" }
    static var documentReady: String { isCzech ? "Dokument připraven" : "Document ready" }
    static var documentHint: String { isCzech ? "Zarovnej dokument do obrysu a vyfoť ho." : "Align the document inside the frame and capture it." }
    static var capturedOCRText: String { isCzech ? "Text ze snímku" : "Captured text" }
    static var capturedOCRHint: String { isCzech ? "Text byl rozpoznaný lokálně přes Vision." : "Text was recognized locally with Vision." }
    static var openLink: String { isCzech ? "Otevřít" : "Open" }
    static var openMail: String { isCzech ? "Mail" : "Mail" }
    static var openPhone: String { isCzech ? "Volat" : "Call" }
    static var openMessage: String { isCzech ? "Zpráva" : "Message" }
    static var openWiFiSettings: String { isCzech ? "Wi-Fi" : "Wi-Fi" }
    static var openMaps: String { isCzech ? "Mapy" : "Maps" }
    static var openFaceTime: String { isCzech ? "FaceTime" : "FaceTime" }
    static var addContact: String { isCzech ? "Kontakt" : "Contact" }
    static var addEvent: String { isCzech ? "Kalendář" : "Calendar" }
    static var scannedCode: String { isCzech ? "Naskenovaný kód" : "Scanned code" }
    static var recentScans: String { isCzech ? "Poslední skeny" : "Recent scans" }
    static var wifiSSID: String { isCzech ? "Síť" : "SSID" }
    static var wifiPassword: String { isCzech ? "Heslo" : "Password" }
    static var wifiSecurity: String { isCzech ? "Zabezpečení" : "Security" }
    static var wifiHidden: String { isCzech ? "Skrytá síť" : "Hidden network" }
    static var contactName: String { isCzech ? "Jméno" : "Name" }
    static var contactPhone: String { isCzech ? "Telefon" : "Phone" }
    static var contactEmail: String { isCzech ? "E-mail" : "Email" }
    static var contactOrganization: String { isCzech ? "Organizace" : "Organization" }
    static var eventTitle: String { isCzech ? "Událost" : "Event" }
    static var eventStart: String { isCzech ? "Začátek" : "Start" }
    static var eventEnd: String { isCzech ? "Konec" : "End" }
    static var eventLocation: String { isCzech ? "Místo" : "Location" }
    static var eventNotes: String { isCzech ? "Poznámky" : "Notes" }
    static var locationCoordinates: String { isCzech ? "Souřadnice" : "Coordinates" }
    static var autoAnalyze: String { isCzech ? "Auto AI po focení" : "Auto AI after capture" }
    static var locationForCaptures: String { isCzech ? "GPS metadata do fotek" : "GPS metadata in photos" }
    static var permissionTitle: String { isCzech ? "Povol kameru" : "Allow camera access" }
    static var permissionBody: String {
        isCzech
            ? "Pro živý náhled a focení potřebuje aplikace přístup ke kameře. Bez toho ji na tomto iPhonu nespustíš naplno."
            : "The app needs camera access for live preview and photo capture."
    }
    static var allowCamera: String { isCzech ? "Povolit kameru" : "Allow camera" }
    static var openSystemSettings: String { isCzech ? "Otevřít nastavení iOS" : "Open iOS settings" }
    static var ready: String { isCzech ? "Připraveno" : "Ready" }
    static var latestShot: String { isCzech ? "Poslední snímek" : "Latest shot" }
    static var latestVideo: String { isCzech ? "Poslední video" : "Latest video" }
    static var latestCode: String { isCzech ? "Poslední kód" : "Latest code" }
    static var livePreview: String { isCzech ? "Živý náhled" : "Live preview" }
    static var resultTitle: String { isCzech ? "AI výstup" : "AI result" }
    static var resultActions: String { isCzech ? "Práce s výstupem" : "Result actions" }
    static var noResultTitle: String { isCzech ? "Zatím bez analýzy" : "No analysis yet" }
    static var noResultBody: String {
        isCzech
            ? "Vyfoť scénu, dokument nebo objekt. Appka pak pošle snímek do OpenAI a vrátí český rozbor."
            : "Capture a scene, document, or object. The app will send it to OpenAI and return a structured analysis."
    }
    static var summary: String { isCzech ? "Shrnutí" : "Summary" }
    static var findings: String { isCzech ? "Zjištění" : "Findings" }
    static var recommendations: String { isCzech ? "Doporučení" : "Recommendations" }
    static var detectedText: String { isCzech ? "Detekovaný text" : "Detected text" }
    static var tags: String { isCzech ? "Tagy" : "Tags" }
    static var confidence: String { isCzech ? "Jistota" : "Confidence" }
    static var mode: String { isCzech ? "Režim" : "Mode" }
    static var cameraTuning: String { isCzech ? "Kamera a obraz" : "Camera and image" }
    static var exposure: String { isCzech ? "Expozice" : "Exposure" }
    static var shutter: String { isCzech ? "Čas" : "Shutter" }
    static var shutterAuto: String { isCzech ? "Auto čas" : "Auto shutter" }
    static var iso: String { isCzech ? "ISO" : "ISO" }
    static var isoAuto: String { isCzech ? "Auto ISO" : "Auto ISO" }
    static var whiteBalance: String { isCzech ? "Bílá" : "White balance" }
    static var focus: String { isCzech ? "Fokus" : "Focus" }
    static var autofocus: String { isCzech ? "Autofokus" : "Autofocus" }
    static var manualFocus: String { isCzech ? "Manuální fokus" : "Manual focus" }
    static var focusPeaking: String { isCzech ? "Focus peaking" : "Focus peaking" }
    static var focusScore: String { isCzech ? "Ostrost" : "Focus" }
    static var focusLockedHint: String { isCzech ? "Manuální fokus je aktivní." : "Manual focus is active." }
    static var focusExposureLock: String { isCzech ? "AE/AF lock" : "AE/AF lock" }
    static var focusExposureLocked: String { isCzech ? "AE/AF zamčeno" : "AE/AF locked" }
    static var focusExposureUnlocked: String { isCzech ? "AE/AF odemčeno" : "AE/AF unlocked" }
    static var recordingTimer: String { isCzech ? "Záznam" : "Recording" }
    static var grid: String { isCzech ? "Mřížka" : "Grid" }
    static var level: String { isCzech ? "Horizont" : "Level" }
    static var histogram: String { isCzech ? "Histogram" : "Histogram" }
    static var zebras: String { isCzech ? "Zebry" : "Zebras" }
    static var luma: String { isCzech ? "Jas" : "Luma" }
    static var captureEffect: String { isCzech ? "Efekt" : "Effect" }
    static var tools: String { isCzech ? "Nástroje" : "Tools" }
    static var toolsOpen: String { isCzech ? "Otevřít panel" : "Open panel" }
    static var toolsClose: String { isCzech ? "Zavřít panel" : "Close panel" }
    static var toolsQuick: String { isCzech ? "Rychlé" : "Quick" }
    static var toolsDetect: String { isCzech ? "Detekce" : "Detect" }
    static var toolsPro: String { isCzech ? "Pro" : "Pro" }
    static var toolsQuickHint: String { isCzech ? "Kamera, světlo, FPS, GPS a přístup." : "Camera, light, FPS, GPS, and access." }
    static var toolsDetectHint: String { isCzech ? "Scanner, OCR, dokumenty a on-device AI." : "Scanner, OCR, documents, and on-device AI." }
    static var toolsProHint: String { isCzech ? "WB, AF, lock a ruční kontrola obrazu." : "WB, AF, lock, and manual image control." }
    static var resetPro: String { isCzech ? "Reset" : "Reset" }
    static var swipeTuningHint: String {
        isCzech ? "Tahem vlevo a vpravo upravíš aktivní parametr." : "Swipe left and right to adjust the active parameter."
    }
    static var swipeTuningCompactHint: String {
        isCzech ? "↕ přepnutí • ↔ ladění" : "↕ switch • ↔ tune"
    }
    static var tuningResetHint: String {
        isCzech ? "Pro nastavení resetováno na Auto." : "Pro settings reset to Auto."
    }
    static var activeTuningPrefix: String {
        isCzech ? "Aktivní" : "Active"
    }
    static var error: String { isCzech ? "Chyba" : "Error" }
    static var cameraUnavailable: String {
        isCzech
            ? "Na zařízení se nepodařilo připravit kameru."
            : "The camera could not be prepared on this device."
    }
    static var missingAPIKey: String {
        isCzech
            ? "Nejdřív ulož OpenAI API klíč v nastavení."
            : "Save your OpenAI API key in Settings first."
    }
    static var settingsTitle: String { isCzech ? "AI a zařízení" : "AI and device" }
    static var settingsBody: String {
        isCzech
            ? "API klíč se ukládá lokálně do Keychainu telefonu. Výchozí model je nastavený na gpt-5.4, ale můžeš ho změnit."
            : "The API key is stored locally in the phone Keychain. The default model is gpt-5.4, but you can change it."
    }
    static var apiRequestHint: String {
        isCzech
            ? "Výstup používá Structured Outputs přes Responses API, takže JSON je stabilnější než čistý prompt."
            : "The output uses Structured Outputs via the Responses API, making JSON more stable than prompt-only formatting."
    }
    static var apiKey: String { isCzech ? "OpenAI API klíč" : "OpenAI API key" }
    static var model: String { isCzech ? "Model" : "Model" }
    static var save: String { isCzech ? "Uložit" : "Save" }
    static var cancel: String { isCzech ? "Zrušit" : "Cancel" }
    static var delete: String { isCzech ? "Smazat" : "Delete" }
    static var export: String { isCzech ? "Export" : "Export" }
    static var restore: String { isCzech ? "Obnovit" : "Restore" }
    static var favorite: String { isCzech ? "Oblíbit" : "Favorite" }
    static var unfavorite: String { isCzech ? "Odebrat" : "Unfavorite" }
    static var copyResult: String { isCzech ? "Kopírovat" : "Copy" }
    static var shareResult: String { isCzech ? "Sdílet" : "Share" }
    static var copiedResult: String { isCzech ? "Výstup zkopírován." : "Result copied." }
    static var privacyHint: String {
        isCzech
            ? "Tahle nativní varianta je cílená na TrollStore workflow. Nepotřebuje Apple Developer účet."
            : "This native variant targets TrollStore workflow and does not need an Apple Developer account."
    }
    static var analyzingHint: String {
        isCzech
            ? "Po odeslání snímku vrátím strukturovaný český rozbor s objekty, textem a doporučeními."
            : "After sending the shot, the app returns a structured analysis with objects, text, and recommendations."
    }
    static var usingModel: String { isCzech ? "Model" : "Model" }

    static func modeLabel(_ mode: AnalysisMode) -> String {
        switch mode {
        case .scene: return isCzech ? "Scéna" : "Scene"
        case .text: return isCzech ? "Text / OCR" : "Text / OCR"
        case .shopping: return isCzech ? "Objekty" : "Objects"
        case .creative: return isCzech ? "Nápady" : "Ideas"
        }
    }

    static func captureEffectLabel(_ effect: CaptureEffect) -> String {
        switch effect {
        case .natural: return isCzech ? "Natural" : "Natural"
        case .vivid: return isCzech ? "Vivid" : "Vivid"
        case .mono: return isCzech ? "Mono" : "Mono"
        case .noir: return isCzech ? "Noir" : "Noir"
        }
    }

    static func whiteBalanceLabel(_ preset: WhiteBalancePreset) -> String {
        switch preset {
        case .auto: return isCzech ? "Auto" : "Auto"
        case .warm: return isCzech ? "Teplá" : "Warm"
        case .cool: return isCzech ? "Studená" : "Cool"
        }
    }

    static func focusModeLabel(_ mode: FocusModePreset) -> String {
        switch mode {
        case .auto: return isCzech ? "AF" : "AF"
        case .manual: return isCzech ? "MF" : "MF"
        }
    }

    static func tuningLabel(_ title: String, active: Bool) -> String {
        if active {
            return isCzech ? "\(title) aktivní" : "\(title) active"
        }
        return title
    }

    static func confidenceLabel(_ value: String?) -> String {
        switch value?.lowercased() {
        case "high":
            return isCzech ? "Vysoká" : "High"
        case "low":
            return isCzech ? "Nízká" : "Low"
        default:
            return isCzech ? "Střední" : "Medium"
        }
    }
}
