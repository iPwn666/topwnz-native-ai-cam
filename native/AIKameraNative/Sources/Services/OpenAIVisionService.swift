import Foundation

enum OpenAIVisionServiceError: LocalizedError {
    case invalidRequest
    case invalidResponse
    case missingOutput
    case httpError(status: Int, body: String)

    var errorDescription: String? {
        switch self {
        case .invalidRequest:
            return AppStrings.isCzech ? "Nepodařilo se sestavit OpenAI request." : "Failed to build the OpenAI request."
        case .invalidResponse:
            return AppStrings.isCzech ? "OpenAI vrátil nečitelnou odpověď." : "OpenAI returned an unreadable response."
        case .missingOutput:
            return AppStrings.isCzech ? "OpenAI nevrátil žádný textový výstup." : "OpenAI returned no text output."
        case let .httpError(status, body):
            return "OpenAI \(status): \(body)"
        }
    }
}

struct OpenAIVisionService {
    private let endpoint = URL(string: "https://api.openai.com/v1/responses")!
    private let urlSession: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 120
        configuration.timeoutIntervalForResource = 180
        return URLSession(configuration: configuration)
    }()

    func analyze(imageData: Data, settings: AppSettings) async throws -> CameraAnalysis {
        do {
            return try await performAnalysis(imageData: imageData, settings: settings, useStructuredOutputs: true)
        } catch let error as OpenAIVisionServiceError {
            if case let .httpError(status, body) = error,
               status == 400,
               body.lowercased().contains("json_schema") || body.lowercased().contains("text.format") {
                return try await performAnalysis(imageData: imageData, settings: settings, useStructuredOutputs: false)
            }
            throw error
        } catch {
            throw error
        }
    }

    func analyze(imageData: Data, settings: AppSettings, question: String) async throws -> CameraAnalysis {
        do {
            return try await performQuestionAnalysis(imageData: imageData, settings: settings, question: question, useStructuredOutputs: true)
        } catch let error as OpenAIVisionServiceError {
            if case let .httpError(status, body) = error,
               status == 400,
               body.lowercased().contains("json_schema") || body.lowercased().contains("text.format") {
                return try await performQuestionAnalysis(imageData: imageData, settings: settings, question: question, useStructuredOutputs: false)
            }
            throw error
        } catch {
            throw error
        }
    }

    func analyze(scannedCode: ScannedCode, settings: AppSettings) async throws -> CameraAnalysis {
        do {
            return try await performScanAnalysis(scannedCode: scannedCode, settings: settings, useStructuredOutputs: true)
        } catch let error as OpenAIVisionServiceError {
            if case let .httpError(status, body) = error,
               status == 400,
               body.lowercased().contains("json_schema") || body.lowercased().contains("text.format") {
                return try await performScanAnalysis(scannedCode: scannedCode, settings: settings, useStructuredOutputs: false)
            }
            throw error
        } catch {
            throw error
        }
    }

    func analyze(scannedCode: ScannedCode, settings: AppSettings, question: String) async throws -> CameraAnalysis {
        do {
            return try await performQuestionScanAnalysis(scannedCode: scannedCode, settings: settings, question: question, useStructuredOutputs: true)
        } catch let error as OpenAIVisionServiceError {
            if case let .httpError(status, body) = error,
               status == 400,
               body.lowercased().contains("json_schema") || body.lowercased().contains("text.format") {
                return try await performQuestionScanAnalysis(scannedCode: scannedCode, settings: settings, question: question, useStructuredOutputs: false)
            }
            throw error
        } catch {
            throw error
        }
    }

    private func performAnalysis(imageData: Data, settings: AppSettings, useStructuredOutputs: Bool) async throws -> CameraAnalysis {
        let payload = buildPayload(imageData: imageData, settings: settings, useStructuredOutputs: useStructuredOutputs)
        guard JSONSerialization.isValidJSONObject(payload) else {
            throw OpenAIVisionServiceError.invalidRequest
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(settings.apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload, options: [])

        let (data, response) = try await urlSession.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenAIVisionServiceError.invalidResponse
        }

        if !(200 ... 299).contains(httpResponse.statusCode) {
            let body = String(data: data, encoding: .utf8) ?? "<empty>"
            throw OpenAIVisionServiceError.httpError(status: httpResponse.statusCode, body: body)
        }

        let envelope = try JSONDecoder().decode(OpenAIResponseEnvelope.self, from: data)
        let rawText = extractOutputText(from: envelope)

        guard !rawText.isEmpty else {
            throw OpenAIVisionServiceError.missingOutput
        }

        guard let parsed = parsePayload(from: rawText) else {
            return CameraAnalysis.fallback(from: rawText)
        }

        return CameraAnalysis(
            title: sanitized(parsed.title, fallback: AppStrings.resultTitle),
            summary: sanitized(parsed.summary, fallback: rawText),
            tags: parsed.tags?.map(\.trimmed).filter { !$0.isEmpty } ?? [],
            findings: parsed.findings?.map(\.trimmed).filter { !$0.isEmpty } ?? [],
            recommendations: parsed.recommendations?.map(\.trimmed).filter { !$0.isEmpty } ?? [],
            detectedText: parsed.detectedText?.map(\.trimmed).filter { !$0.isEmpty } ?? [],
            confidenceLabel: AppStrings.confidenceLabel(parsed.confidence),
            rawText: rawText
        )
    }

    private func performQuestionAnalysis(imageData: Data, settings: AppSettings, question: String, useStructuredOutputs: Bool) async throws -> CameraAnalysis {
        let payload = buildQuestionPayload(imageData: imageData, settings: settings, question: question, useStructuredOutputs: useStructuredOutputs)
        guard JSONSerialization.isValidJSONObject(payload) else {
            throw OpenAIVisionServiceError.invalidRequest
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(settings.apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload, options: [])

        let (data, response) = try await urlSession.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenAIVisionServiceError.invalidResponse
        }

        if !(200 ... 299).contains(httpResponse.statusCode) {
            let body = String(data: data, encoding: .utf8) ?? "<empty>"
            throw OpenAIVisionServiceError.httpError(status: httpResponse.statusCode, body: body)
        }

        let envelope = try JSONDecoder().decode(OpenAIResponseEnvelope.self, from: data)
        let rawText = extractOutputText(from: envelope)

        guard !rawText.isEmpty else {
            throw OpenAIVisionServiceError.missingOutput
        }

        guard let parsed = parsePayload(from: rawText) else {
            return CameraAnalysis.fallback(from: rawText)
        }

        return CameraAnalysis(
            title: sanitized(parsed.title, fallback: AppStrings.aiAnswerTitle),
            summary: sanitized(parsed.summary, fallback: rawText),
            tags: parsed.tags?.map(\.trimmed).filter { !$0.isEmpty } ?? [],
            findings: parsed.findings?.map(\.trimmed).filter { !$0.isEmpty } ?? [],
            recommendations: parsed.recommendations?.map(\.trimmed).filter { !$0.isEmpty } ?? [],
            detectedText: parsed.detectedText?.map(\.trimmed).filter { !$0.isEmpty } ?? [],
            confidenceLabel: AppStrings.confidenceLabel(parsed.confidence),
            rawText: rawText
        )
    }

    private func performScanAnalysis(scannedCode: ScannedCode, settings: AppSettings, useStructuredOutputs: Bool) async throws -> CameraAnalysis {
        let payload = buildScanPayload(scannedCode: scannedCode, settings: settings, useStructuredOutputs: useStructuredOutputs)
        guard JSONSerialization.isValidJSONObject(payload) else {
            throw OpenAIVisionServiceError.invalidRequest
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(settings.apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload, options: [])

        let (data, response) = try await urlSession.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenAIVisionServiceError.invalidResponse
        }

        if !(200 ... 299).contains(httpResponse.statusCode) {
            let body = String(data: data, encoding: .utf8) ?? "<empty>"
            throw OpenAIVisionServiceError.httpError(status: httpResponse.statusCode, body: body)
        }

        let envelope = try JSONDecoder().decode(OpenAIResponseEnvelope.self, from: data)
        let rawText = extractOutputText(from: envelope)

        guard !rawText.isEmpty else {
            throw OpenAIVisionServiceError.missingOutput
        }

        guard let parsed = parsePayload(from: rawText) else {
            return CameraAnalysis.fallback(from: rawText)
        }

        return CameraAnalysis(
            title: sanitized(parsed.title, fallback: AppStrings.scannedCode),
            summary: sanitized(parsed.summary, fallback: rawText),
            tags: parsed.tags?.map(\.trimmed).filter { !$0.isEmpty } ?? [],
            findings: parsed.findings?.map(\.trimmed).filter { !$0.isEmpty } ?? [],
            recommendations: parsed.recommendations?.map(\.trimmed).filter { !$0.isEmpty } ?? [],
            detectedText: parsed.detectedText?.map(\.trimmed).filter { !$0.isEmpty } ?? [],
            confidenceLabel: AppStrings.confidenceLabel(parsed.confidence),
            rawText: rawText
        )
    }

    private func performQuestionScanAnalysis(scannedCode: ScannedCode, settings: AppSettings, question: String, useStructuredOutputs: Bool) async throws -> CameraAnalysis {
        let payload = buildQuestionScanPayload(scannedCode: scannedCode, settings: settings, question: question, useStructuredOutputs: useStructuredOutputs)
        guard JSONSerialization.isValidJSONObject(payload) else {
            throw OpenAIVisionServiceError.invalidRequest
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(settings.apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload, options: [])

        let (data, response) = try await urlSession.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenAIVisionServiceError.invalidResponse
        }

        if !(200 ... 299).contains(httpResponse.statusCode) {
            let body = String(data: data, encoding: .utf8) ?? "<empty>"
            throw OpenAIVisionServiceError.httpError(status: httpResponse.statusCode, body: body)
        }

        let envelope = try JSONDecoder().decode(OpenAIResponseEnvelope.self, from: data)
        let rawText = extractOutputText(from: envelope)

        guard !rawText.isEmpty else {
            throw OpenAIVisionServiceError.missingOutput
        }

        guard let parsed = parsePayload(from: rawText) else {
            return CameraAnalysis.fallback(from: rawText)
        }

        return CameraAnalysis(
            title: sanitized(parsed.title, fallback: AppStrings.aiAnswerTitle),
            summary: sanitized(parsed.summary, fallback: rawText),
            tags: parsed.tags?.map(\.trimmed).filter { !$0.isEmpty } ?? [],
            findings: parsed.findings?.map(\.trimmed).filter { !$0.isEmpty } ?? [],
            recommendations: parsed.recommendations?.map(\.trimmed).filter { !$0.isEmpty } ?? [],
            detectedText: parsed.detectedText?.map(\.trimmed).filter { !$0.isEmpty } ?? [],
            confidenceLabel: AppStrings.confidenceLabel(parsed.confidence),
            rawText: rawText
        )
    }

    private func buildPayload(imageData: Data, settings: AppSettings, useStructuredOutputs: Bool) -> [String: Any] {
        let dataURL = "data:image/jpeg;base64,\(imageData.base64EncodedString())"
        var payload: [String: Any] = [
            "model": settings.model,
            "max_output_tokens": 900,
            "input": [
                [
                    "role": "user",
                    "content": [
                        [
                            "type": "input_text",
                            "text": buildPrompt(mode: settings.analysisMode, useStructuredOutputs: useStructuredOutputs),
                        ],
                        [
                            "type": "input_image",
                            "image_url": dataURL,
                        ],
                    ],
                ],
            ],
        ]

        if useStructuredOutputs {
            payload["text"] = [
                "format": [
                    "type": "json_schema",
                    "name": "camera_analysis",
                    "strict": true,
                    "schema": analysisSchema,
                ],
            ]
        }

        return payload
    }

    private func buildQuestionPayload(imageData: Data, settings: AppSettings, question: String, useStructuredOutputs: Bool) -> [String: Any] {
        let dataURL = "data:image/jpeg;base64,\(imageData.base64EncodedString())"
        var payload: [String: Any] = [
            "model": settings.model,
            "max_output_tokens": 900,
            "input": [
                [
                    "role": "user",
                    "content": [
                        [
                            "type": "input_text",
                            "text": buildQuestionPrompt(mode: settings.analysisMode, question: question, useStructuredOutputs: useStructuredOutputs),
                        ],
                        [
                            "type": "input_image",
                            "image_url": dataURL,
                        ],
                    ],
                ],
            ],
        ]

        if useStructuredOutputs {
            payload["text"] = [
                "format": [
                    "type": "json_schema",
                    "name": "camera_question_analysis",
                    "strict": true,
                    "schema": analysisSchema,
                ],
            ]
        }

        return payload
    }

    private func buildScanPayload(scannedCode: ScannedCode, settings: AppSettings, useStructuredOutputs: Bool) -> [String: Any] {
        let text = [
            buildScanPrompt(scannedCode: scannedCode, useStructuredOutputs: useStructuredOutputs),
            "",
            "Type: \(scannedCode.type)",
            "Kind: \(String(describing: scannedCode.kind))",
            "Payload:",
            scannedCode.payload,
        ].joined(separator: "\n")

        var payload: [String: Any] = [
            "model": settings.model,
            "max_output_tokens": 900,
            "input": [
                [
                    "role": "user",
                    "content": [
                        [
                            "type": "input_text",
                            "text": text,
                        ],
                    ],
                ],
            ],
        ]

        if useStructuredOutputs {
            payload["text"] = [
                "format": [
                    "type": "json_schema",
                    "name": "scan_analysis",
                    "strict": true,
                    "schema": analysisSchema,
                ],
            ]
        }

        return payload
    }

    private func buildQuestionScanPayload(scannedCode: ScannedCode, settings: AppSettings, question: String, useStructuredOutputs: Bool) -> [String: Any] {
        let text = [
            buildQuestionScanPrompt(scannedCode: scannedCode, question: question, useStructuredOutputs: useStructuredOutputs),
            "",
            "Type: \(scannedCode.type)",
            "Kind: \(String(describing: scannedCode.kind))",
            "Payload:",
            scannedCode.payload,
        ].joined(separator: "\n")

        var payload: [String: Any] = [
            "model": settings.model,
            "max_output_tokens": 900,
            "input": [
                [
                    "role": "user",
                    "content": [
                        [
                            "type": "input_text",
                            "text": text,
                        ],
                    ],
                ],
            ],
        ]

        if useStructuredOutputs {
            payload["text"] = [
                "format": [
                    "type": "json_schema",
                    "name": "scan_question_analysis",
                    "strict": true,
                    "schema": analysisSchema,
                ],
            ]
        }

        return payload
    }

    private func buildPrompt(mode: AnalysisMode, useStructuredOutputs: Bool) -> String {
        let languageInstruction = AppStrings.isCzech
            ? "Odpověz česky a naplň přesně požadovanou JSON strukturu."
            : "Reply in English and fill the required JSON structure exactly."

        let modeInstruction: String
        switch mode {
        case .scene:
            modeInstruction = AppStrings.isCzech
                ? "Vrať vyvážený rozbor celé scény, nejdůležitější objekty a praktická doporučení."
                : "Return a balanced analysis of the entire scene, the most important objects, and practical recommendations."
        case .text:
            modeInstruction = AppStrings.isCzech
                ? "Zaměř se na text, dokumenty, cedule a čitelnost. Pokud je něco nejisté, přiznej to."
                : "Focus on text, documents, signs, and legibility. If something is uncertain, say so."
        case .shopping:
            modeInstruction = AppStrings.isCzech
                ? "Zaměř se na produkty, materiály, značky a praktickou identifikaci objektů."
                : "Focus on products, materials, brands, and practical object identification."
        case .creative:
            modeInstruction = AppStrings.isCzech
                ? "Kromě popisu přidej i kreativní nápady, návrhy použití nebo titulky."
                : "In addition to description, add creative ideas, suggested uses, or captions."
        }

        var instructions = [
            languageInstruction,
            modeInstruction,
            AppStrings.isCzech
                ? "Vrať stručný, praktický a věcný výstup. Pole confidence nastav na high, medium nebo low."
                : "Return a concise, practical, and factual result. Set confidence to high, medium, or low.",
        ]

        if !useStructuredOutputs {
            instructions.append(
                AppStrings.isCzech
                    ? #"Vrať pouze čistý JSON bez markdownu v tvaru {"title":"","summary":"","tags":[],"findings":[],"recommendations":[],"detected_text":[],"confidence":"high|medium|low"}"#
                    : #"Return raw JSON only, with no markdown, using {"title":"","summary":"","tags":[],"findings":[],"recommendations":[],"detected_text":[],"confidence":"high|medium|low"}"#
            )
        }

        return instructions.joined(separator: "\n")
    }

    private func buildQuestionPrompt(mode: AnalysisMode, question: String, useStructuredOutputs: Bool) -> String {
        var instructions = [
            AppStrings.isCzech
                ? "Analyzuješ aktuální snímek z iPhone kamery. Odpověz česky."
                : "You are analyzing the current iPhone camera image. Reply in English.",
            AppStrings.isCzech
                ? "Primárně odpověz na uživatelovu otázku. Buď konkrétní, věcný a praktický."
                : "Answer the user's question first. Be concrete, factual, and practical.",
            "Question: \(question.trimmed)",
            AppStrings.isCzech
                ? "Pole summary použij jako přímou odpověď. findings dej jako důkazy a recommendations jako další kroky."
                : "Use summary as the direct answer. Put supporting evidence into findings and next steps into recommendations.",
            "Mode context: \(mode.rawValue)",
        ]

        if !useStructuredOutputs {
            instructions.append(
                AppStrings.isCzech
                    ? #"Vrať pouze čistý JSON bez markdownu v tvaru {"title":"","summary":"","tags":[],"findings":[],"recommendations":[],"detected_text":[],"confidence":"high|medium|low"}"#
                    : #"Return raw JSON only, with no markdown, using {"title":"","summary":"","tags":[],"findings":[],"recommendations":[],"detected_text":[],"confidence":"high|medium|low"}"#
            )
        }

        return instructions.joined(separator: "\n")
    }

    private func buildScanPrompt(scannedCode: ScannedCode, useStructuredOutputs: Bool) -> String {
        var instructions = [
            AppStrings.isCzech
                ? "Analyzuješ naskenovaný QR nebo čárový kód. Odpověz česky."
                : "You are analyzing a scanned QR or barcode payload. Reply in English.",
            AppStrings.isCzech
                ? "Stručně vysvětli, co payload znamená, jestli působí důvěryhodně, a jaký je nejlepší další krok pro uživatele."
                : "Briefly explain what the payload means, whether it appears trustworthy, and the best next step for the user.",
            AppStrings.isCzech
                ? "Pokud jde o URL, zhodnoť srozumitelně možné bezpečnostní signály. Pokud jde o Wi-Fi, kontakt nebo událost, vysvětli prakticky, co bude následovat."
                : "If it's a URL, assess obvious safety signals. If it's Wi-Fi, contact, or an event, explain practically what happens next.",
            AppStrings.isCzech
                ? "Pole confidence nastav na high, medium nebo low."
                : "Set confidence to high, medium, or low.",
        ]

        if !useStructuredOutputs {
            instructions.append(
                AppStrings.isCzech
                    ? #"Vrať pouze čistý JSON bez markdownu v tvaru {"title":"","summary":"","tags":[],"findings":[],"recommendations":[],"detected_text":[],"confidence":"high|medium|low"}"#
                    : #"Return raw JSON only, with no markdown, using {"title":"","summary":"","tags":[],"findings":[],"recommendations":[],"detected_text":[],"confidence":"high|medium|low"}"#
            )
        }

        return instructions.joined(separator: "\n")
    }

    private func buildQuestionScanPrompt(scannedCode: ScannedCode, question: String, useStructuredOutputs: Bool) -> String {
        var instructions = [
            AppStrings.isCzech
                ? "Analyzuješ naskenovaný payload z QR nebo čárového kódu. Odpověz česky."
                : "You are analyzing a scanned QR or barcode payload. Reply in English.",
            AppStrings.isCzech
                ? "Primárně odpověz na uživatelovu otázku a vysvětli praktické důsledky payloadu."
                : "Answer the user's question first and explain the practical implications of the payload.",
            "Question: \(question.trimmed)",
            AppStrings.isCzech
                ? "summary má být přímá odpověď, findings důvody a recommendations další krok."
                : "Use summary as the direct answer, findings as supporting reasons, and recommendations as next steps.",
            "Scan type: \(scannedCode.type)",
        ]

        if !useStructuredOutputs {
            instructions.append(
                AppStrings.isCzech
                    ? #"Vrať pouze čistý JSON bez markdownu v tvaru {"title":"","summary":"","tags":[],"findings":[],"recommendations":[],"detected_text":[],"confidence":"high|medium|low"}"#
                    : #"Return raw JSON only, with no markdown, using {"title":"","summary":"","tags":[],"findings":[],"recommendations":[],"detected_text":[],"confidence":"high|medium|low"}"#
            )
        }

        return instructions.joined(separator: "\n")
    }

    private func extractOutputText(from envelope: OpenAIResponseEnvelope) -> String {
        envelope.output
            .flatMap(\.content)
            .compactMap { part in
                guard part.type == "output_text" else { return nil }
                return part.text?.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func parsePayload(from rawText: String) -> ParsedAnalysisPayload? {
        let cleaned = rawText
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let data = cleaned.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(ParsedAnalysisPayload.self, from: data)
    }

    private func sanitized(_ value: String?, fallback: String) -> String {
        guard let value = value?.trimmed, !value.isEmpty else {
            return fallback
        }
        return value
    }

    private var analysisSchema: [String: Any] {
        [
            "type": "object",
            "additionalProperties": false,
            "properties": [
                "title": ["type": "string"],
                "summary": ["type": "string"],
                "tags": [
                    "type": "array",
                    "items": ["type": "string"],
                ],
                "findings": [
                    "type": "array",
                    "items": ["type": "string"],
                ],
                "recommendations": [
                    "type": "array",
                    "items": ["type": "string"],
                ],
                "detected_text": [
                    "type": "array",
                    "items": ["type": "string"],
                ],
                "confidence": [
                    "type": "string",
                    "enum": ["high", "medium", "low"],
                ],
            ],
            "required": [
                "title",
                "summary",
                "tags",
                "findings",
                "recommendations",
                "detected_text",
                "confidence",
            ],
        ]
    }
}

private struct OpenAIResponseEnvelope: Decodable {
    let output: [OpenAIOutputItem]
}

private struct OpenAIOutputItem: Decodable {
    let content: [OpenAIOutputContent]
}

private struct OpenAIOutputContent: Decodable {
    let type: String
    let text: String?
}

private extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
