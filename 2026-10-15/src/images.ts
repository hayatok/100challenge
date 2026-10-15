import type { Rect, SourceImage } from './types';

const MAX_BYTES = 12 * 1024 * 1024;
const MAX_PIXELS = 16_000_000;

export async function decodeFile(file: File): Promise<SourceImage> {
  if (file.size === 0) throw new Error('空のファイルです。表が写った画像を選んでください。');
  if (file.size > MAX_BYTES) throw new Error('画像は12MBまでです。小さくしてからもう一度選んでください。');
  const bytes = new Uint8Array(await file.slice(0, 16).arrayBuffer());
  const png = bytes[0] === 0x89 && bytes[1] === 0x50 && bytes[2] === 0x4e && bytes[3] === 0x47;
  const jpeg = bytes[0] === 0xff && bytes[1] === 0xd8 && bytes[2] === 0xff;
  const webp = String.fromCharCode(...bytes.slice(0, 4)) === 'RIFF' && String.fromCharCode(...bytes.slice(8, 12)) === 'WEBP';
  const bmp = bytes[0] === 0x42 && bytes[1] === 0x4d;
  if (!png && !jpeg && !webp && !bmp) throw new Error('PNG・JPEG・WebP・BMPの画像を選んでください。PDFやSVGは画像にしてから読み込めます。');
  const url = URL.createObjectURL(file);
  try {
    const image = await openImage(url);
    if (image.naturalWidth * image.naturalHeight > MAX_PIXELS) throw new Error('画像が大きすぎます。1600万画素以下に縮小してください。');
    if (image.naturalWidth < 32 || image.naturalHeight < 32) throw new Error('画像が小さすぎます。表の文字が読める大きさの画像を選んでください。');
    return { name: file.name || '貼り付けた画像.png', url, width: image.naturalWidth, height: image.naturalHeight };
  } catch (error) {
    URL.revokeObjectURL(url);
    if (error instanceof Error && error.message.includes('画像が')) throw error;
    throw new Error('画像を開けませんでした。別の画像を選ぶか、PNGとして保存し直してください。');
  }
}

function openImage(url: string): Promise<HTMLImageElement> {
  const image = new Image();
  image.src = url;
  return image.decode().then(() => image);
}

export function clampCrop(rect: Rect, source: SourceImage): Rect {
  if (![rect.x, rect.y, rect.width, rect.height].every(Number.isFinite)) {
    throw new Error('範囲は数値で指定してください。');
  }
  const x = Math.max(0, Math.min(source.width - 1, Math.round(rect.x)));
  const y = Math.max(0, Math.min(source.height - 1, Math.round(rect.y)));
  const width = Math.max(1, Math.min(source.width - x, Math.round(rect.width)));
  const height = Math.max(1, Math.min(source.height - y, Math.round(rect.height)));
  return { x, y, width, height };
}

export async function prepareRegion(source: SourceImage, crop: Rect | null) {
  const region = clampCrop(crop ?? { x: 0, y: 0, width: source.width, height: source.height }, source);
  if (region.width < 32 || region.height < 32) throw new Error('認識する範囲が小さすぎます。表全体が入るように選んでください。');
  const scale = Math.min(1, 2400 / Math.max(region.width, region.height));
  const canvas = document.createElement('canvas');
  canvas.width = Math.max(1, Math.round(region.width * scale));
  canvas.height = Math.max(1, Math.round(region.height * scale));
  const context = canvas.getContext('2d', { willReadFrequently: true });
  if (!context) throw new Error('画像処理を開始できませんでした。ページを開き直してください。');
  const image = await openImage(source.url);
  context.fillStyle = '#ffffff';
  context.fillRect(0, 0, canvas.width, canvas.height);
  context.drawImage(image, region.x, region.y, region.width, region.height, 0, 0, canvas.width, canvas.height);
  const pixels = context.getImageData(0, 0, canvas.width, canvas.height);
  const blob = await new Promise<Blob>((resolve, reject) => canvas.toBlob(value => value ? resolve(value) : reject(new Error('画像の準備に失敗しました。')), 'image/png'));
  return { blob, pixels: pixels.data, width: canvas.width, height: canvas.height, region, scaleX: region.width / canvas.width, scaleY: region.height / canvas.height };
}

export async function createSampleFile(): Promise<File> {
  await document.fonts.ready;
  const canvas = document.createElement('canvas');
  canvas.width = 1120;
  canvas.height = 510;
  const context = canvas.getContext('2d');
  if (!context) throw new Error('サンプル画像を作成できませんでした。');
  context.fillStyle = '#ffffff';
  context.fillRect(0, 0, canvas.width, canvas.height);
  const x = [30, 440, 610, 820, 1090];
  const y = [30, 120, 210, 300, 390, 480];
  context.fillStyle = '#f0f1f3';
  context.fillRect(x[0], y[0], x[4] - x[0], y[1] - y[0]);
  context.strokeStyle = '#333333';
  context.lineWidth = 2;
  for (const value of x) { context.beginPath(); context.moveTo(value, y[0]); context.lineTo(value, y[5]); context.stroke(); }
  for (const value of y) { context.beginPath(); context.moveTo(x[0], value); context.lineTo(x[4], value); context.stroke(); }
  const values = [
    ['品名', '数量', '単価', '金額'],
    ['ノート', '3', '120', '360'],
    ['ボールペン', '2', '150', '300'],
    ['クリアファイル', '', '80', ''],
    ['合計', '', '', '660'],
  ];
  context.fillStyle = '#111111';
  context.font = '30px "Hiragino Sans", "Noto Sans JP", sans-serif';
  context.textBaseline = 'middle';
  values.forEach((row, r) => row.forEach((value, c) => context.fillText(value, x[c] + 22, (y[r] + y[r + 1]) / 2)));
  const blob = await new Promise<Blob>((resolve, reject) => canvas.toBlob(value => value ? resolve(value) : reject(new Error('サンプル画像を作成できませんでした。')), 'image/png'));
  return new File([blob], '文具の注文表.png', { type: 'image/png' });
}
