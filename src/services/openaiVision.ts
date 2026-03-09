export type AnalysisMode = 'scene' | 'text' | 'shopping' | 'creative';

export type CameraAnalysis = {
  title: string;
  summary: string;
  tags: string[];
  findings: string[];
  recommendations: string[];
  detectedText: string[];
  confidenceLabel: string;
  rawText: string;
};

type AnalyzeImageArgs = {
  apiKey: string;
  model: string;
  mode: AnalysisMode;
  locale: 'cs' | 'en';
  imageDataUrl: string;
};

type ParsedPayload = {
  title?: unknown;
  summary?: unknown;
  tags?: unknown;
  findings?: unknown;
  recommendations?: unknown;
  detected_text?: unknown;
  confidence?: unknown;
};

const endpoint = 'https://api.openai.com/v1/responses';

function modeInstruction(mode: AnalysisMode, locale: 'cs' | 'en'): string {
  const isCzech = locale === 'cs';

  switch (mode) {
    case 'text':
      return isCzech
        ? 'Zaměř se na čtení textu, cedulí, dokumentů a nápisů. Pokud je text špatně čitelný, přiznej nejistotu.'
        : 'Focus on reading visible text, signs, and documents. Be explicit about uncertainty when text is unclear.';
    case 'shopping':
      return isCzech
        ? 'Zaměř se na objekty, produkty, materiály a praktickou identifikaci věcí v záběru.'
        : 'Focus on objects, products, materials, and practical item identification.';
    case 'creative':
      return isCzech
        ? 'Kromě popisu navrhni i kreativní nápady, titulky, využití nebo další postup.'
        : 'In addition to description, suggest creative ideas, captions, or next steps.';
    case 'scene':
    default:
      return isCzech
        ? 'Vrať vyvážený popis celé scény, nejdůležitější prvky a praktická doporučení.'
        : 'Return a balanced description of the scene, important elements, and practical recommendations.';
  }
}

function buildPrompt(mode: AnalysisMode, locale: 'cs' | 'en'): string {
  const isCzech = locale === 'cs';
  const languageInstruction = isCzech
    ? 'Odpověz česky. Vrať pouze čistý JSON bez markdownu a bez vysvětlujícího textu navíc.'
    : 'Reply in English. Return only raw JSON without markdown or extra narration.';

  return [
    languageInstruction,
    modeInstruction(mode, locale),
    isCzech
      ? 'Použij přesně tento JSON tvar: {"title":"","summary":"","tags":[],"findings":[],"recommendations":[],"detected_text":[],"confidence":"high|medium|low"}'
      : 'Use exactly this JSON shape: {"title":"","summary":"","tags":[],"findings":[],"recommendations":[],"detected_text":[],"confidence":"high|medium|low"}',
    isCzech
      ? 'Pole tags, findings, recommendations a detected_text vrať jako krátká pole stringů.'
      : 'Return tags, findings, recommendations, and detected_text as short arrays of strings.',
  ].join('\n');
}

function extractOutputText(payload: any): string {
  const output = Array.isArray(payload?.output) ? payload.output : [];
  const textParts = output
    .flatMap((item: any) => (Array.isArray(item?.content) ? item.content : []))
    .filter((content: any) => content?.type === 'output_text' && typeof content?.text === 'string')
    .map((content: any) => content.text.trim())
    .filter(Boolean);

  return textParts.join('\n').trim();
}

function parseJsonFromText(text: string): ParsedPayload | null {
  const cleaned = text
    .trim()
    .replace(/^```json\s*/i, '')
    .replace(/^```\s*/i, '')
    .replace(/```$/i, '')
    .trim();

  try {
    return JSON.parse(cleaned) as ParsedPayload;
  } catch {
    return null;
  }
}

function normalizeStringArray(value: unknown): string[] {
  if (!Array.isArray(value)) return [];
  return value
    .filter((item): item is string => typeof item === 'string')
    .map((item) => item.trim())
    .filter(Boolean);
}

function confidenceLabel(value: unknown, locale: 'cs' | 'en'): string {
  const normalized = typeof value === 'string' ? value.toLowerCase() : 'medium';
  const cs = {
    high: 'Vysoká',
    medium: 'Střední',
    low: 'Nízká',
  } as const;
  const en = {
    high: 'High',
    medium: 'Medium',
    low: 'Low',
  } as const;

  if (locale === 'cs') {
    return cs[normalized as keyof typeof cs] ?? cs.medium;
  }
  return en[normalized as keyof typeof en] ?? en.medium;
}

function fallbackAnalysis(rawText: string, locale: 'cs' | 'en'): CameraAnalysis {
  return {
    title: locale === 'cs' ? 'AI výstup' : 'AI output',
    summary: rawText,
    tags: [],
    findings: [],
    recommendations: [],
    detectedText: [],
    confidenceLabel: locale === 'cs' ? 'Střední' : 'Medium',
    rawText,
  };
}

export async function analyzeImageWithOpenAI({
  apiKey,
  model,
  mode,
  locale,
  imageDataUrl,
}: AnalyzeImageArgs): Promise<CameraAnalysis> {
  const response = await fetch(endpoint, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${apiKey}`,
    },
    body: JSON.stringify({
      model,
      max_output_tokens: 900,
      input: [
        {
          role: 'user',
          content: [
            {
              type: 'input_text',
              text: buildPrompt(mode, locale),
            },
            {
              type: 'input_image',
              image_url: imageDataUrl,
            },
          ],
        },
      ],
    }),
  });

  if (!response.ok) {
    const body = await response.text();
    throw new Error(`OpenAI ${response.status}: ${body}`);
  }

  const payload = await response.json();
  const rawText = extractOutputText(payload);
  const parsed = parseJsonFromText(rawText);

  if (!parsed) {
    return fallbackAnalysis(rawText, locale);
  }

  return {
    title:
      typeof parsed.title === 'string' && parsed.title.trim()
        ? parsed.title.trim()
        : locale === 'cs'
          ? 'AI analýza'
          : 'AI analysis',
    summary:
      typeof parsed.summary === 'string' && parsed.summary.trim()
        ? parsed.summary.trim()
        : rawText,
    tags: normalizeStringArray(parsed.tags),
    findings: normalizeStringArray(parsed.findings),
    recommendations: normalizeStringArray(parsed.recommendations),
    detectedText: normalizeStringArray(parsed.detected_text),
    confidenceLabel: confidenceLabel(parsed.confidence, locale),
    rawText,
  };
}
