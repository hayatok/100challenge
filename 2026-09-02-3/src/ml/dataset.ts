import type { MnistSample } from './types'
import type { CnnModelDefinition } from './cnn'

export type DataManifest = {
  version: number
  source: {
    url: string
    sha256: string
    license: string
    attribution: string
  }
  selection: { seed: number; method: string }
  splits: Record<'guided' | 'train' | 'test', {
    count: number
    images: string
    labels: string
    imagesSha256: string
    labelsSha256: string
  }>
  model: {
    architecture: number[]
    optimizer: string
    learningRate: number
    epochs: number
    trainingCount: number
    testCount: number
    testAccuracy: number
    weights: string
    weightsSha256: string
    parameterOrder: string[]
    parameterShapes: number[][]
    epochLoss: number[]
  }
}

const DATA_ROOT = './data/'

async function fetchBuffer(path: string) {
  const response = await fetch(`${DATA_ROOT}${path}`)
  if (!response.ok) throw new Error(`データ ${path} を読み込めませんでした`)
  return response.arrayBuffer()
}

export async function loadManifest() {
  const response = await fetch(`${DATA_ROOT}manifest.json`)
  if (!response.ok) throw new Error('MNISTの来歴情報を読み込めませんでした')
  return response.json() as Promise<DataManifest>
}

export async function loadWeights(manifest: DataManifest) {
  return new Float32Array(await fetchBuffer(manifest.model.weights))
}

export async function loadCnnModel() {
  const response = await fetch(`${DATA_ROOT}cnn-model.json`)
  if (!response.ok) throw new Error('CNNモデルの来歴情報を読み込めませんでした')
  const definition = await response.json() as CnnModelDefinition
  const weights = new Float32Array(await fetchBuffer(definition.weights))
  return { definition, weights }
}

export async function loadSplit(manifest: DataManifest, split: 'guided' | 'train' | 'test') {
  const definition = manifest.splits[split]
  const [imageBuffer, labelBuffer] = await Promise.all([
    fetchBuffer(definition.images),
    fetchBuffer(definition.labels),
  ])
  const images = new Uint8Array(imageBuffer)
  const labels = new Uint8Array(labelBuffer)
  if (images.length !== definition.count * 784 || labels.length !== definition.count) {
    throw new Error(`${split}データの件数または形がmanifestと一致しません`)
  }
  return Array.from({ length: definition.count }, (_, index): MnistSample => ({
    id: `${split}-${index}`,
    split,
    label: labels[index],
    pixels: Float32Array.from(images.subarray(index * 784, (index + 1) * 784), (value) => value / 255),
  }))
}
