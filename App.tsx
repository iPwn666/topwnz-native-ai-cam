import { StatusBar } from 'expo-status-bar';
import { File } from 'expo-file-system';
import { getLocales } from 'expo-localization';
import * as SecureStore from 'expo-secure-store';
import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import {
  ActivityIndicator,
  Alert,
  Image,
  Modal,
  Pressable,
  SafeAreaView,
  ScrollView,
  StyleSheet,
  Switch,
  Text,
  TextInput,
  View,
} from 'react-native';
import {
  Camera,
  type CameraPosition,
  useCameraDevice,
  useCameraPermission,
} from 'react-native-vision-camera';

import {
  analyzeImageWithOpenAI,
  type AnalysisMode,
  type CameraAnalysis,
} from './src/services/openaiVision';
import { t } from './src/i18n';

type AppSettings = {
  apiKey: string;
  model: string;
  autoAnalyze: boolean;
};

const SETTINGS_KEY = 'ai-kamera-cz-settings';
const FALLBACK_MODEL = 'gpt-5.4';

function normalizePhotoUri(path: string): string {
  if (path.startsWith('file://')) {
    return path;
  }
  return `file://${path}`;
}

export default function App() {
  const locale = useMemo<'cs' | 'en'>(() => {
    const preferred = getLocales()[0]?.languageCode;
    return preferred === 'cs' ? 'cs' : 'en';
  }, []);

  const [settings, setSettings] = useState<AppSettings>({
    apiKey: '',
    model: FALLBACK_MODEL,
    autoAnalyze: false,
  });
  const [settingsDraft, setSettingsDraft] = useState<AppSettings>({
    apiKey: '',
    model: FALLBACK_MODEL,
    autoAnalyze: false,
  });
  const [settingsVisible, setSettingsVisible] = useState(false);
  const [mode, setMode] = useState<AnalysisMode>('scene');
  const [position, setPosition] = useState<CameraPosition>('back');
  const [flashEnabled, setFlashEnabled] = useState(false);
  const [photoUri, setPhotoUri] = useState<string | null>(null);
  const [analysis, setAnalysis] = useState<CameraAnalysis | null>(null);
  const [busyCapture, setBusyCapture] = useState(false);
  const [busyAnalysis, setBusyAnalysis] = useState(false);
  const [lastError, setLastError] = useState<string | null>(null);

  const camera = useRef<Camera>(null);
  const device = useCameraDevice(position);
  const { hasPermission, requestPermission } = useCameraPermission();

  const modeOptions: AnalysisMode[] = ['scene', 'text', 'shopping', 'creative'];

  useEffect(() => {
    void (async () => {
      const stored = await SecureStore.getItemAsync(SETTINGS_KEY);
      if (!stored) return;
      try {
        const parsed = JSON.parse(stored) as Partial<AppSettings>;
        const next: AppSettings = {
          apiKey: parsed.apiKey ?? '',
          model: parsed.model ?? FALLBACK_MODEL,
          autoAnalyze: parsed.autoAnalyze ?? false,
        };
        setSettings(next);
        setSettingsDraft(next);
      } catch {
        // Ignore invalid persisted state and keep defaults.
      }
    })();
  }, []);

  const persistSettings = useCallback(async (next: AppSettings) => {
    setSettings(next);
    await SecureStore.setItemAsync(SETTINGS_KEY, JSON.stringify(next));
  }, []);

  const requestCameraAccess = useCallback(async () => {
    const granted = await requestPermission();
    if (!granted) {
      Alert.alert(t(locale, 'permissionTitle'), t(locale, 'permissionBody'));
    }
  }, [locale, requestPermission]);

  const runAnalysis = useCallback(
    async (targetUri: string) => {
      if (!settings.apiKey.trim()) {
        setSettingsVisible(true);
        setLastError(t(locale, 'missingApiKey'));
        return;
      }

      setBusyAnalysis(true);
      setLastError(null);
      try {
        const base64 = await new File(targetUri).base64();
        const result = await analyzeImageWithOpenAI({
          apiKey: settings.apiKey.trim(),
          model: settings.model.trim() || FALLBACK_MODEL,
          mode,
          locale,
          imageDataUrl: `data:image/jpeg;base64,${base64}`,
        });
        setAnalysis(result);
      } catch (error) {
        const message = error instanceof Error ? error.message : t(locale, 'unknownError');
        setLastError(message);
      } finally {
        setBusyAnalysis(false);
      }
    },
    [locale, mode, settings.apiKey, settings.model]
  );

  const capturePhoto = useCallback(async () => {
    if (!camera.current || busyCapture) return;

    setBusyCapture(true);
    setLastError(null);
    setAnalysis(null);

    try {
      const photo = await camera.current.takePhoto({
        flash: flashEnabled ? 'on' : 'off',
        enableAutoDistortionCorrection: true,
        enableShutterSound: false,
      });
      const nextUri = normalizePhotoUri(photo.path);
      setPhotoUri(nextUri);

      if (settings.autoAnalyze) {
        await runAnalysis(nextUri);
      }
    } catch (error) {
      const message = error instanceof Error ? error.message : t(locale, 'cameraFailed');
      setLastError(message);
    } finally {
      setBusyCapture(false);
    }
  }, [busyCapture, flashEnabled, locale, runAnalysis, settings.autoAnalyze]);

  const closePreview = useCallback(() => {
    setPhotoUri(null);
    setAnalysis(null);
    setLastError(null);
  }, []);

  const saveSettings = useCallback(async () => {
    const next = {
      apiKey: settingsDraft.apiKey.trim(),
      model: settingsDraft.model.trim() || FALLBACK_MODEL,
      autoAnalyze: settingsDraft.autoAnalyze,
    };
    await persistSettings(next);
    setSettingsDraft(next);
    setSettingsVisible(false);
  }, [persistSettings, settingsDraft]);

  const summaryChip = analysis ? `${analysis.title} • ${analysis.confidenceLabel}` : t(locale, 'ready');

  if (!hasPermission) {
    return (
      <SafeAreaView style={styles.permissionScreen}>
        <StatusBar style="light" />
        <View style={styles.permissionCard}>
          <Text style={styles.permissionEyebrow}>{t(locale, 'brand')}</Text>
          <Text style={styles.permissionTitle}>{t(locale, 'permissionTitle')}</Text>
          <Text style={styles.permissionText}>{t(locale, 'permissionBody')}</Text>
          <Pressable style={styles.primaryButton} onPress={requestCameraAccess}>
            <Text style={styles.primaryButtonText}>{t(locale, 'grantAccess')}</Text>
          </Pressable>
        </View>
      </SafeAreaView>
    );
  }

  if (!device) {
    return (
      <SafeAreaView style={styles.permissionScreen}>
        <StatusBar style="light" />
        <View style={styles.permissionCard}>
          <Text style={styles.permissionEyebrow}>{t(locale, 'brand')}</Text>
          <Text style={styles.permissionTitle}>{t(locale, 'deviceMissingTitle')}</Text>
          <Text style={styles.permissionText}>{t(locale, 'deviceMissingBody')}</Text>
        </View>
      </SafeAreaView>
    );
  }

  return (
    <SafeAreaView style={styles.screen}>
      <StatusBar style="light" />
      <View style={styles.header}>
        <View>
          <Text style={styles.headerEyebrow}>{t(locale, 'brand')}</Text>
          <Text style={styles.headerTitle}>{t(locale, 'appTitle')}</Text>
        </View>
        <Pressable style={styles.ghostButton} onPress={() => setSettingsVisible(true)}>
          <Text style={styles.ghostButtonText}>{t(locale, 'settings')}</Text>
        </Pressable>
      </View>

      <View style={styles.previewShell}>
        <Camera
          ref={camera}
          style={styles.camera}
          device={device}
          isActive={!photoUri}
          photo
        />

        {photoUri ? (
          <Image source={{ uri: photoUri }} resizeMode="cover" style={styles.camera} />
        ) : null}

        <View style={styles.overlayTop}>
          <View style={styles.modeRow}>
            {modeOptions.map((item) => (
              <Pressable
                key={item}
                style={[styles.modeChip, mode === item ? styles.modeChipActive : null]}
                onPress={() => setMode(item)}
              >
                <Text style={[styles.modeChipText, mode === item ? styles.modeChipTextActive : null]}>
                  {t(locale, `mode.${item}`)}
                </Text>
              </Pressable>
            ))}
          </View>
        </View>

        <View style={styles.overlayBottom}>
          <View style={styles.statusCard}>
            <Text style={styles.statusChip}>{summaryChip}</Text>
            <Text style={styles.statusTitle}>
              {photoUri ? t(locale, 'previewReady') : t(locale, 'livePreview')}
            </Text>
            <Text style={styles.statusBody}>
              {photoUri ? t(locale, 'previewHint') : t(locale, 'liveHint')}
            </Text>
          </View>

          <View style={styles.controlsRow}>
            <Pressable style={styles.secondaryButton} onPress={() => setFlashEnabled((value) => !value)}>
              <Text style={styles.secondaryButtonText}>
                {flashEnabled ? t(locale, 'flashOn') : t(locale, 'flashOff')}
              </Text>
            </Pressable>

            <Pressable style={styles.captureButton} onPress={photoUri ? closePreview : capturePhoto}>
              <View style={styles.captureInner} />
            </Pressable>

            <Pressable
              style={styles.secondaryButton}
              onPress={() => setPosition((value) => (value === 'back' ? 'front' : 'back'))}
            >
              <Text style={styles.secondaryButtonText}>{t(locale, 'flip')}</Text>
            </Pressable>
          </View>

          <View style={styles.actionRow}>
            <Pressable
              style={[styles.primaryButton, (!photoUri || busyAnalysis) && styles.disabledButton]}
              disabled={!photoUri || busyAnalysis}
              onPress={() => photoUri && runAnalysis(photoUri)}
            >
              {busyAnalysis ? (
                <ActivityIndicator color="#08111d" />
              ) : (
                <Text style={styles.primaryButtonText}>{t(locale, 'analyze')}</Text>
              )}
            </Pressable>
          </View>
        </View>
      </View>

      <ScrollView style={styles.resultSheet} contentContainerStyle={styles.resultContent}>
        {busyCapture ? (
          <Text style={styles.resultLabel}>{t(locale, 'capturing')}</Text>
        ) : null}

        {lastError ? (
          <View style={styles.errorCard}>
            <Text style={styles.errorTitle}>{t(locale, 'error')}</Text>
            <Text style={styles.errorText}>{lastError}</Text>
          </View>
        ) : null}

        {analysis ? (
          <>
            <View style={styles.analysisHero}>
              <Text style={styles.analysisHeroTitle}>{analysis.title}</Text>
              <Text style={styles.analysisHeroSummary}>{analysis.summary}</Text>
            </View>

            <View style={styles.infoGrid}>
              <MetricCard label={t(locale, 'confidence')} value={analysis.confidenceLabel} />
              <MetricCard label={t(locale, 'modeLabel')} value={t(locale, `mode.${mode}`)} />
            </View>

            <TagList title={t(locale, 'tags')} items={analysis.tags} />
            <BulletList title={t(locale, 'findings')} items={analysis.findings} />
            <BulletList title={t(locale, 'recommendations')} items={analysis.recommendations} />
            <BulletList title={t(locale, 'detectedText')} items={analysis.detectedText} />
          </>
        ) : (
          <View style={styles.emptyState}>
            <Text style={styles.emptyStateTitle}>{t(locale, 'emptyTitle')}</Text>
            <Text style={styles.emptyStateBody}>{t(locale, 'emptyBody')}</Text>
          </View>
        )}
      </ScrollView>

      <Modal visible={settingsVisible} animationType="slide" transparent onRequestClose={() => setSettingsVisible(false)}>
        <View style={styles.modalBackdrop}>
          <View style={styles.modalCard}>
            <Text style={styles.modalTitle}>{t(locale, 'settingsTitle')}</Text>
            <Text style={styles.modalText}>{t(locale, 'settingsBody')}</Text>

            <View style={styles.formBlock}>
              <Text style={styles.formLabel}>{t(locale, 'apiKey')}</Text>
              <TextInput
                value={settingsDraft.apiKey}
                onChangeText={(value) => setSettingsDraft((current) => ({ ...current, apiKey: value }))}
                style={styles.formInput}
                autoCapitalize="none"
                autoCorrect={false}
                placeholder="sk-proj-..."
                placeholderTextColor="#6f7d91"
                secureTextEntry
              />
            </View>

            <View style={styles.formBlock}>
              <Text style={styles.formLabel}>{t(locale, 'model')}</Text>
              <TextInput
                value={settingsDraft.model}
                onChangeText={(value) => setSettingsDraft((current) => ({ ...current, model: value }))}
                style={styles.formInput}
                autoCapitalize="none"
                autoCorrect={false}
                placeholder={FALLBACK_MODEL}
                placeholderTextColor="#6f7d91"
              />
            </View>

            <View style={styles.switchRow}>
              <View style={styles.switchText}>
                <Text style={styles.formLabel}>{t(locale, 'autoAnalyze')}</Text>
                <Text style={styles.modalHint}>{t(locale, 'autoAnalyzeHint')}</Text>
              </View>
              <Switch
                value={settingsDraft.autoAnalyze}
                onValueChange={(value) => setSettingsDraft((current) => ({ ...current, autoAnalyze: value }))}
                trackColor={{ false: '#223047', true: '#00d3a7' }}
              />
            </View>

            <View style={styles.modalActions}>
              <Pressable style={styles.secondaryModalButton} onPress={() => setSettingsVisible(false)}>
                <Text style={styles.secondaryModalButtonText}>{t(locale, 'cancel')}</Text>
              </Pressable>
              <Pressable style={styles.primaryButton} onPress={saveSettings}>
                <Text style={styles.primaryButtonText}>{t(locale, 'save')}</Text>
              </Pressable>
            </View>
          </View>
        </View>
      </Modal>
    </SafeAreaView>
  );
}

function MetricCard({ label, value }: { label: string; value: string }) {
  return (
    <View style={styles.metricCard}>
      <Text style={styles.metricLabel}>{label}</Text>
      <Text style={styles.metricValue}>{value}</Text>
    </View>
  );
}

function TagList({ title, items }: { title: string; items: string[] }) {
  if (items.length === 0) return null;
  return (
    <View style={styles.section}>
      <Text style={styles.sectionTitle}>{title}</Text>
      <View style={styles.tagsWrap}>
        {items.map((item) => (
          <View key={`${title}-${item}`} style={styles.tag}>
            <Text style={styles.tagText}>{item}</Text>
          </View>
        ))}
      </View>
    </View>
  );
}

function BulletList({ title, items }: { title: string; items: string[] }) {
  if (items.length === 0) return null;
  return (
    <View style={styles.section}>
      <Text style={styles.sectionTitle}>{title}</Text>
      <View style={styles.bulletList}>
        {items.map((item) => (
          <View key={`${title}-${item}`} style={styles.bulletRow}>
            <View style={styles.bulletDot} />
            <Text style={styles.bulletText}>{item}</Text>
          </View>
        ))}
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  screen: {
    flex: 1,
    backgroundColor: '#07111d',
  },
  permissionScreen: {
    flex: 1,
    backgroundColor: '#07111d',
    justifyContent: 'center',
    padding: 24,
  },
  permissionCard: {
    borderRadius: 28,
    backgroundColor: '#0d1a2b',
    padding: 24,
    borderWidth: 1,
    borderColor: '#17304f',
  },
  permissionEyebrow: {
    color: '#00d3a7',
    fontSize: 14,
    fontWeight: '700',
    textTransform: 'uppercase',
    letterSpacing: 1.2,
    marginBottom: 12,
  },
  permissionTitle: {
    color: '#f4f7fb',
    fontSize: 28,
    fontWeight: '800',
    marginBottom: 12,
  },
  permissionText: {
    color: '#b8c4d6',
    fontSize: 16,
    lineHeight: 23,
    marginBottom: 24,
  },
  header: {
    paddingHorizontal: 18,
    paddingTop: 8,
    paddingBottom: 12,
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  headerEyebrow: {
    color: '#00d3a7',
    fontSize: 12,
    fontWeight: '800',
    textTransform: 'uppercase',
    letterSpacing: 1.4,
    marginBottom: 4,
  },
  headerTitle: {
    color: '#f4f7fb',
    fontSize: 28,
    fontWeight: '800',
  },
  ghostButton: {
    borderRadius: 18,
    paddingHorizontal: 14,
    paddingVertical: 10,
    backgroundColor: '#102338',
  },
  ghostButtonText: {
    color: '#dbe7f4',
    fontWeight: '700',
  },
  previewShell: {
    marginHorizontal: 14,
    borderRadius: 28,
    overflow: 'hidden',
    backgroundColor: '#000',
    minHeight: 420,
  },
  camera: {
    width: '100%',
    height: 420,
  },
  overlayTop: {
    position: 'absolute',
    left: 0,
    right: 0,
    top: 0,
    padding: 14,
  },
  overlayBottom: {
    position: 'absolute',
    left: 0,
    right: 0,
    bottom: 0,
    padding: 16,
    gap: 14,
    backgroundColor: 'rgba(7, 17, 29, 0.56)',
  },
  modeRow: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 8,
  },
  modeChip: {
    borderRadius: 999,
    paddingHorizontal: 12,
    paddingVertical: 8,
    backgroundColor: 'rgba(7, 17, 29, 0.72)',
    borderWidth: 1,
    borderColor: 'rgba(219, 231, 244, 0.18)',
  },
  modeChipActive: {
    backgroundColor: '#00d3a7',
    borderColor: '#00d3a7',
  },
  modeChipText: {
    color: '#f4f7fb',
    fontWeight: '700',
    fontSize: 12,
  },
  modeChipTextActive: {
    color: '#07111d',
  },
  statusCard: {
    borderRadius: 22,
    padding: 16,
    backgroundColor: 'rgba(7, 17, 29, 0.78)',
    borderWidth: 1,
    borderColor: 'rgba(219, 231, 244, 0.12)',
  },
  statusChip: {
    color: '#00d3a7',
    fontWeight: '700',
    marginBottom: 8,
  },
  statusTitle: {
    color: '#f4f7fb',
    fontSize: 18,
    fontWeight: '800',
    marginBottom: 6,
  },
  statusBody: {
    color: '#d6dfeb',
    lineHeight: 20,
  },
  controlsRow: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
  },
  captureButton: {
    width: 86,
    height: 86,
    borderRadius: 43,
    borderWidth: 3,
    borderColor: '#f4f7fb',
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: 'rgba(244, 247, 251, 0.18)',
  },
  captureInner: {
    width: 68,
    height: 68,
    borderRadius: 34,
    backgroundColor: '#f4f7fb',
  },
  secondaryButton: {
    minWidth: 84,
    paddingHorizontal: 14,
    paddingVertical: 12,
    borderRadius: 18,
    backgroundColor: 'rgba(13, 26, 43, 0.84)',
    alignItems: 'center',
  },
  secondaryButtonText: {
    color: '#f4f7fb',
    fontWeight: '700',
  },
  actionRow: {
    flexDirection: 'row',
  },
  primaryButton: {
    borderRadius: 18,
    backgroundColor: '#00d3a7',
    alignItems: 'center',
    justifyContent: 'center',
    paddingHorizontal: 18,
    paddingVertical: 14,
    minHeight: 52,
    flex: 1,
  },
  disabledButton: {
    opacity: 0.5,
  },
  primaryButtonText: {
    color: '#08111d',
    fontWeight: '800',
    fontSize: 16,
  },
  resultSheet: {
    flex: 1,
    marginTop: 12,
    borderTopLeftRadius: 30,
    borderTopRightRadius: 30,
    backgroundColor: '#f3f8ff',
  },
  resultContent: {
    padding: 18,
    paddingBottom: 40,
    gap: 16,
  },
  resultLabel: {
    color: '#30506d',
    fontWeight: '700',
  },
  errorCard: {
    backgroundColor: '#ffe6e6',
    borderRadius: 20,
    padding: 16,
    borderWidth: 1,
    borderColor: '#ffb7b7',
  },
  errorTitle: {
    color: '#7f0e22',
    fontWeight: '800',
    marginBottom: 6,
  },
  errorText: {
    color: '#7f0e22',
    lineHeight: 20,
  },
  analysisHero: {
    borderRadius: 24,
    backgroundColor: '#08111d',
    padding: 20,
  },
  analysisHeroTitle: {
    color: '#f4f7fb',
    fontSize: 24,
    fontWeight: '800',
    marginBottom: 10,
  },
  analysisHeroSummary: {
    color: '#d3ddea',
    lineHeight: 22,
  },
  infoGrid: {
    flexDirection: 'row',
    gap: 12,
  },
  metricCard: {
    flex: 1,
    borderRadius: 20,
    backgroundColor: '#dff6f1',
    padding: 16,
  },
  metricLabel: {
    color: '#30506d',
    fontSize: 12,
    fontWeight: '700',
    textTransform: 'uppercase',
    letterSpacing: 1.1,
    marginBottom: 8,
  },
  metricValue: {
    color: '#07111d',
    fontSize: 18,
    fontWeight: '800',
  },
  section: {
    borderRadius: 22,
    backgroundColor: '#fff',
    padding: 18,
  },
  sectionTitle: {
    color: '#08111d',
    fontWeight: '800',
    fontSize: 18,
    marginBottom: 12,
  },
  tagsWrap: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 8,
  },
  tag: {
    borderRadius: 999,
    backgroundColor: '#edf5ff',
    paddingHorizontal: 12,
    paddingVertical: 8,
  },
  tagText: {
    color: '#234462',
    fontWeight: '700',
  },
  bulletList: {
    gap: 12,
  },
  bulletRow: {
    flexDirection: 'row',
    gap: 10,
  },
  bulletDot: {
    width: 8,
    height: 8,
    borderRadius: 4,
    backgroundColor: '#00d3a7',
    marginTop: 7,
  },
  bulletText: {
    flex: 1,
    color: '#294560',
    lineHeight: 21,
  },
  emptyState: {
    borderRadius: 24,
    borderWidth: 1,
    borderColor: '#d7e4f2',
    borderStyle: 'dashed',
    padding: 22,
  },
  emptyStateTitle: {
    color: '#08111d',
    fontWeight: '800',
    fontSize: 20,
    marginBottom: 10,
  },
  emptyStateBody: {
    color: '#4a627d',
    lineHeight: 22,
  },
  modalBackdrop: {
    flex: 1,
    justifyContent: 'flex-end',
    backgroundColor: 'rgba(7, 17, 29, 0.42)',
  },
  modalCard: {
    borderTopLeftRadius: 30,
    borderTopRightRadius: 30,
    backgroundColor: '#08111d',
    padding: 20,
    gap: 16,
  },
  modalTitle: {
    color: '#f4f7fb',
    fontSize: 24,
    fontWeight: '800',
  },
  modalText: {
    color: '#c7d4e3',
    lineHeight: 21,
  },
  modalHint: {
    color: '#8fa2b8',
    fontSize: 13,
    lineHeight: 18,
  },
  formBlock: {
    gap: 8,
  },
  formLabel: {
    color: '#f4f7fb',
    fontSize: 15,
    fontWeight: '700',
  },
  formInput: {
    borderRadius: 16,
    borderWidth: 1,
    borderColor: '#21334b',
    backgroundColor: '#102338',
    color: '#f4f7fb',
    paddingHorizontal: 14,
    paddingVertical: 14,
  },
  switchRow: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    gap: 16,
  },
  switchText: {
    flex: 1,
    gap: 6,
  },
  modalActions: {
    flexDirection: 'row',
    gap: 12,
    marginTop: 8,
    paddingBottom: 18,
  },
  secondaryModalButton: {
    flex: 1,
    borderRadius: 18,
    borderWidth: 1,
    borderColor: '#2b4059',
    alignItems: 'center',
    justifyContent: 'center',
    paddingHorizontal: 18,
    paddingVertical: 14,
  },
  secondaryModalButtonText: {
    color: '#d7e4f2',
    fontWeight: '700',
    fontSize: 16,
  },
});
