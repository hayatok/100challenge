import { createHash } from 'node:crypto'
import { copyFile, mkdir, readFile, readdir, writeFile } from 'node:fs/promises'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..')
const output = path.join(root, 'public', 'vision')
const wasmSource = path.join(root, 'node_modules', '@mediapipe', 'tasks-vision', 'wasm')
const modelUrl = 'https://storage.googleapis.com/mediapipe-models/hand_landmarker/hand_landmarker/float16/1/hand_landmarker.task'
const modelPath = path.join(output, 'hand_landmarker.task')
const expectedHash = 'fbc2a30080c3c557093b5ddfc334698132eb341044ccee322ccf8bcf3607cde1'

await mkdir(path.join(output, 'wasm'), { recursive: true })
for (const file of await readdir(wasmSource)) {
  if (file.startsWith('vision_wasm_')) await copyFile(path.join(wasmSource, file), path.join(output, 'wasm', file))
}

let model
try { model = await readFile(modelPath) } catch { /* first build */ }
if (!model || model.byteLength !== 7_819_105) {
  const response = await fetch(modelUrl)
  if (!response.ok) throw new Error(`Model download failed: ${response.status}`)
  model = Buffer.from(await response.arrayBuffer())
  if (model.byteLength !== 7_819_105) throw new Error(`Unexpected model size: ${model.byteLength}`)
  await writeFile(modelPath, model)
}
const digest = createHash('sha256').update(model).digest('hex')
if (digest !== expectedHash) throw new Error(`Unexpected model hash: ${digest}`)
console.log(`Hand model: ${model.byteLength} bytes; sha256 ${digest}`)
