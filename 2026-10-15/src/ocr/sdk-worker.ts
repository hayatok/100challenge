import { PaddleOCR, type OcrResult } from '@paddleocr/paddleocr-js';
import cvModule from '@techstark/opencv-js';
import type { EnginePreference, OcrToken, ProgressInfo } from '../types';

const progress = (label: string) => self.postMessage({ type: 'progress', progress: { label, value: null } satisfies ProgressInfo });

function toTokens(result: OcrResult, width: number, height: number): OcrToken[] {
  if (!result || !Array.isArray(result.items) || result.image.width !== width || result.image.height !== height) throw new Error('OCRの画像サイズが一致しません。');
  return result.items.flatMap((item) => {
    if (typeof item.text !== 'string' || !Number.isFinite(item.score) || !Array.isArray(item.poly) || item.poly.length < 4) throw new Error('OCRの文字情報が不正です。');
    const points = item.poly;
    if (points.some((point) => !Array.isArray(point) || point.length !== 2 || !point.every(Number.isFinite))) throw new Error('OCRの座標情報が不正です。');
    const left = Math.max(0, Math.min(width, Math.min(...points.map(([x]) => x))));
    const right = Math.max(0, Math.min(width, Math.max(...points.map(([x]) => x))));
    const top = Math.max(0, Math.min(height, Math.min(...points.map(([, y]) => y))));
    const bottom = Math.max(0, Math.min(height, Math.max(...points.map(([, y]) => y))));
    if (right <= left || bottom <= top) throw new Error('OCRの文字領域が画像の外にあります。');
    if (!item.text.trim()) return [];
    return [{ text: item.text, confidence: Math.max(0, Math.min(1, item.score)), box: { x: left, y: top, width: right - left, height: bottom - top } }];
  });
}

self.onmessage = async ({ data }: MessageEvent<{ image: Blob; preference: EnginePreference; baseUrl: string }>) => {
  const started = performance.now();
  let ocr: Awaited<ReturnType<typeof PaddleOCR.create>> | null = null;
  let mat: ReturnType<typeof cvModule.matFromImageData> | null = null;
  let bitmap: ImageBitmap | null = null;
  try {
    if (!(data.image instanceof Blob) || !data.image.size || !['auto', 'webgpu', 'wasm'].includes(data.preference)) throw new Error('認識する画像を選び直してください。');
    progress('日本語の認識モデルを準備しています…');
    // This OpenCV build is a thenable, not a native Promise. Awaiting it directly can hang.
    const cv = cvModule instanceof Promise ? await cvModule : cvModule;
    if (!cv.Mat) await new Promise<void>((resolve) => { cv.onRuntimeInitialized = resolve; });
    ocr = await PaddleOCR.create({
      worker: false,
      lang: 'japan',
      ocrVersion: 'PP-OCRv6',
      textDetectionModelName: 'PP-OCRv6_small_det',
      textRecognitionModelName: 'PP-OCRv6_small_rec',
      textDetectionModelAsset: { url: new URL('ocr-models/PP-OCRv6_small_det.tar', data.baseUrl).href },
      textRecognitionModelAsset: { url: new URL('ocr-models/PP-OCRv6_small_rec.tar', data.baseUrl).href },
      ortOptions: { backend: data.preference, numThreads: 1, proxy: false, wasmPaths: new URL('ocr-runtime/', data.baseUrl).href },
      textRecScoreThresh: 0,
    });
    progress('画像の文字を読み取っています…');
    bitmap = await createImageBitmap(data.image);
    const { width, height } = bitmap;
    const canvas = new OffscreenCanvas(width, height);
    const context = canvas.getContext('2d', { willReadFrequently: true });
    if (!context) throw new Error('このブラウザでは画像を処理できません。');
    context.fillStyle = '#fff';
    context.fillRect(0, 0, width, height);
    context.drawImage(bitmap, 0, 0);
    mat = cv.matFromImageData(context.getImageData(0, 0, width, height));
    bitmap.close();
    bitmap = null;
    // Passing cv.Mat avoids SDK's DOM-based Blob conversion inside a module worker.
    const [result] = await ocr.predict(mat, { textDetLimitSideLen: 1280, textDetLimitType: 'max' });
    const tokens = toTokens(result, width, height);
    const { detProvider, recProvider } = result.runtime;
    if (typeof detProvider !== 'string' || !detProvider || typeof recProvider !== 'string' || !recProvider) throw new Error('OCRの実行環境を確認できませんでした。');
    progress('読み取った文字を表に戻しています…');
    self.postMessage({ type: 'result', output: { tokens, runtime: { detector: detProvider, recognizer: recProvider, elapsedMs: performance.now() - started } } });
  } catch (error) {
    const detail = error instanceof Error ? error.message : String(error);
    const message = /download|fetch|HTTP|network|404/i.test(detail)
      ? '認識モデルを読み込めませんでした。通信状態を確認して再試行してください。'
      : data.preference === 'webgpu'
        ? 'WebGPUで認識できませんでした。WASMを選んで再試行してください。'
        : `文字を認識できませんでした。画像を選び直して再試行してください。${/OCR|画像|ブラウザ/.test(detail) ? `（${detail}）` : ''}`;
    self.postMessage({ type: 'error', message, diagnostic: detail });
  } finally {
    bitmap?.close();
    mat?.delete();
    await ocr?.dispose();
  }
};
