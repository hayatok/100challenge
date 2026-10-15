import type { EnginePreference, OcrToken, ProgressInfo, RuntimeInfo } from '../types';

interface OcrOutput { tokens: OcrToken[]; runtime: RuntimeInfo }
type WorkerReply = { type: 'progress'; progress: ProgressInfo } | { type: 'result'; output: OcrOutput } | { type: 'error'; message: string; diagnostic?: string };
let cancelActive: (() => void) | null = null;

/** Every job owns its worker so cancellation also stops inference and model loading. */
export function startOcr(image: Blob, preference: EnginePreference, onProgress: (progress: ProgressInfo) => void): { promise: Promise<OcrOutput>; cancel: () => void } {
  cancelActive?.();
  let worker: Worker | null = null;
  let settled = false;
  let rejectJob: (reason: Error) => void = () => undefined;
  let timer: ReturnType<typeof setTimeout> | undefined;
  const cleanup = () => {
    if (timer) clearTimeout(timer);
    worker?.terminate();
    worker = null;
    if (cancelActive === cancel) cancelActive = null;
  };
  const cancel = () => {
    if (settled) return;
    settled = true;
    cleanup();
    rejectJob(new DOMException('認識をキャンセルしました。', 'AbortError'));
  };
  const promise = new Promise<OcrOutput>((resolve, reject) => {
    rejectJob = reject;
    const fail = (message: string) => {
      if (settled) return;
      settled = true;
      cleanup();
      reject(new Error(message));
    };
    try {
      worker = new Worker(new URL('./sdk-worker.ts', import.meta.url), { type: 'module' });
      worker.onmessage = ({ data }: MessageEvent<WorkerReply>) => {
        if (settled) return;
        if (data.type === 'progress') onProgress(data.progress);
        else if (data.type === 'error') {
          console.error(`OCR execution failed: ${data.diagnostic ?? data.message}`);
          fail(data.message);
        }
        else if (data.type === 'result') {
          settled = true;
          cleanup();
          resolve(data.output);
        }
      };
      worker.onerror = (event) => {
        console.error(`OCR Worker startup failed: ${JSON.stringify({ message: event.message, filename: event.filename, line: event.lineno })}`);
        event.preventDefault();
        fail('認識エンジンを起動できませんでした。ページを再読み込みするか、WASMを選んで再試行してください。');
      };
      worker.onmessageerror = () => fail('認識結果を受け取れませんでした。もう一度お試しください。');
      timer = setTimeout(() => fail('認識に時間がかかっています。画像を小さくするか、WASMを選んで再試行してください。'), 180_000);
      worker.postMessage({ image, preference, baseUrl: new URL(import.meta.env.BASE_URL, location.href).href });
    } catch (error) {
      fail(error instanceof Error ? error.message : '認識エンジンを起動できませんでした。');
    }
  });
  if (!settled) cancelActive = cancel;
  return { promise, cancel };
}

export function disposeOcr(): void { cancelActive?.(); }
