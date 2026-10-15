import { createHash } from 'node:crypto';
import { mkdir, readFile, writeFile, rename } from 'node:fs/promises';
import { createRequire } from 'node:module';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const appRoot = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const require = createRequire(join(appRoot, 'package.json'));
const publicRoot = join(appRoot, 'public');
const modelRoot = 'https://paddle-model-ecology.bj.bcebos.com/paddlex/official_inference_model/paddle3.0.0/';
const assets = [
  { path: 'ocr-models/PP-OCRv6_small_det.tar', bytes: 9891840, sha256: 'd218f6fbf0f1c23d2161bd6ac7f5eaa6104fa89955c09290497e31008e2618e4', url: `${modelRoot}PP-OCRv6_small_det_onnx_infer.tar`, seed: 'det.tar' },
  { path: 'ocr-models/PP-OCRv6_small_rec.tar', bytes: 21319680, sha256: 'd267ab077a44a0eedb1ea8f8c542d263f211de8e9d7a029bf9fcfff7e5a88fb1', url: `${modelRoot}PP-OCRv6_small_rec_onnx_infer.tar`, seed: 'rec.tar' },
  { path: 'ocr-runtime/ort-wasm-simd-threaded.jsep.mjs', bytes: 46595, sha256: '9a99acd12acc495184c9ea4d458ac9424f8180aacfbc7b8371ed64f9351e4a81', packageFile: 'onnxruntime-web/ort-wasm-simd-threaded.jsep.mjs' },
  { path: 'ocr-runtime/ort-wasm-simd-threaded.jsep.wasm', bytes: 25014754, sha256: '2e0a3d0e3f6b7c13ecfaba38c13691fd19c9ed470e72f9d7d8416ca59ab6dbcd', packageFile: 'onnxruntime-web/ort-wasm-simd-threaded.jsep.wasm' },
  { path: 'licenses/PaddleOCR-Apache-2.0.txt', sha256: '3840c5c0c61c294264d2dd77b8777be6ddd90121ef4e0e64abcd22edea581d6e', url: 'https://raw.githubusercontent.com/PaddlePaddle/PaddleOCR/e5046169b225bcdfbe25d45b4e809ff0f1a69c2c/LICENSE', seed: 'PADDLE-LICENSE' },
  { path: 'licenses/ONNX-Runtime-MIT.txt', sha256: '2f07c72751aed99790b8a4869cf2311df85a860b22ded05fa22803587a48922c', url: 'https://raw.githubusercontent.com/microsoft/onnxruntime/v1.24.3/LICENSE', seed: 'ORT-LICENSE' },
  { path: 'licenses/JSBN.txt', sha256: 'e0e396530fd1624126e9a7e0df94811e4062e03baeccb07bc33c934b0fd93a85', url: 'https://www-cs-faculty.stanford.edu/~tjw/jsbn/LICENSE', seed: 'JSBN-LICENSE' },
];
const digest = (bytes) => createHash('sha256').update(bytes).digest('hex');
const valid = (bytes, asset) => digest(bytes) === asset.sha256 && (!asset.bytes || bytes.length === asset.bytes);
async function readMaybe(path) { try { return await readFile(path); } catch (error) { if (error.code === 'ENOENT') return null; throw error; } }
async function download(url) {
  let lastError;
  for (let attempt = 1; attempt <= 3; attempt++) {
    try {
      const response = await fetch(url, { signal: AbortSignal.timeout(90_000) });
      if (!response.ok) throw new Error(`HTTP ${response.status}: ${url}`);
      return Buffer.from(await response.arrayBuffer());
    } catch (error) { lastError = error; }
  }
  throw new Error(`OCR asset download failed; run npm run prepare:assets again. ${lastError?.message}`);
}
for (const asset of assets) {
  const destination = join(publicRoot, asset.path);
  const previous = await readMaybe(destination);
  if (previous && valid(previous, asset)) continue;
  let bytes;
  if (asset.packageFile) bytes = await readFile(require.resolve(asset.packageFile));
  else {
    const seed = process.env.OCR_ASSET_SEED_DIR && asset.seed ? await readMaybe(join(process.env.OCR_ASSET_SEED_DIR, asset.seed)) : null;
    bytes = seed && valid(seed, asset) ? seed : await download(asset.url);
  }
  if (!valid(bytes, asset)) throw new Error(`OCR asset checksum mismatch: ${asset.path}. Expected ${asset.sha256}; received ${digest(bytes)}. Check the pinned dependency and source before retrying.`);
  await mkdir(dirname(destination), { recursive: true });
  await writeFile(`${destination}.tmp`, bytes);
  await rename(`${destination}.tmp`, destination);
  console.log(`Prepared ${asset.path} (${bytes.length} bytes)`);
}
const packageRoot = (name) => dirname(require.resolve(`${name}/package.json`));
await mkdir(join(publicRoot, 'licenses'), { recursive: true });
for (const [name, file] of [['react', 'React-MIT.txt'], ['react-dom', 'React-DOM-MIT.txt'], ['scheduler', 'Scheduler-MIT.txt']]) {
  await writeFile(join(publicRoot, 'licenses', file), await readFile(join(packageRoot(name), 'LICENSE')));
}
await writeFile(join(publicRoot, 'licenses/OpenCV-Apache-2.0.txt'), await readFile(join(packageRoot('@techstark/opencv-js'), 'LICENSE')));
await writeFile(join(publicRoot, 'licenses/js-yaml-MIT.txt'), await readFile(join(packageRoot('js-yaml'), 'LICENSE')));
const clipper = await readFile(join(packageRoot('clipper-lib'), 'clipper.js'), 'utf8');
await writeFile(join(publicRoot, 'licenses/clipper-attributions.txt'), clipper.slice(0, clipper.indexOf('(function ()')));
await writeFile(join(publicRoot, 'licenses/Boost-1.0.txt'), `Boost Software License - Version 1.0 - August 17th, 2003\n\nPermission is hereby granted, free of charge, to any person or organization obtaining a copy of the software and accompanying documentation covered by this license (the "Software") to use, reproduce, display, distribute, execute, and transmit the Software, and to prepare derivative works of the Software, and to permit third-parties to whom the Software is furnished to do so, all subject to the following:\n\nThe copyright notices in the Software and this entire statement, including the above license grant, this restriction and the following disclaimer, must be included in all copies of the Software, in whole or in part, and all derivative works of the Software, unless such copies or derivative works are solely in the form of machine-executable object code generated by a source language processor.\n\nTHE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, TITLE AND NON-INFRINGEMENT. IN NO EVENT SHALL THE COPYRIGHT HOLDERS OR ANYONE DISTRIBUTING THE SOFTWARE BE LIABLE FOR ANY DAMAGES OR OTHER LIABILITY, WHETHER IN CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.\n`);
await writeFile(join(publicRoot, 'ocr-models/manifest.json'), `${JSON.stringify({ sdk: '@paddleocr/paddleocr-js@0.4.2', runtime: 'onnxruntime-web@1.24.3', assets: assets.map(({ seed, packageFile, ...asset }) => ({ ...asset, ...(packageFile ? { source: packageFile } : {}) })) }, null, 2)}\n`);
console.log('OCR assets verified. Models and runtime are served locally; input images never need a remote OCR endpoint.');
