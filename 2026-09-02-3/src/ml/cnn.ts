import * as tf from '@tensorflow/tfjs'

export type CnnParameters = {
  conv1Kernel: Float32Array
  conv1Bias: Float32Array
  conv2Kernel: Float32Array
  conv2Bias: Float32Array
  denseKernel: Float32Array
  denseBias: Float32Array
}

export type CnnTrace = {
  sampleId: string
  label: number | null
  computeDurationMs: number
  input: Float32Array
  conv1: Float32Array
  pool1: Float32Array
  conv2: Float32Array
  pool2: Float32Array
  flat: Float32Array
  logits: Float32Array
  probabilities: Float32Array
  predictedClass: number
  parameters: CnnParameters
}

export type CnnModelDefinition = {
  architecture: string[]
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
  validationAccuracy: number[]
}

const SIZES = [72, 8, 1152, 16, 7840, 10] as const

function unpack(values: Float32Array): CnnParameters {
  if (values.length !== SIZES.reduce((sum, size) => sum + size, 0)) {
    throw new Error('CNN学習済みモデルのパラメータ数が一致しません')
  }
  let offset = 0
  const take = (size: number) => {
    const result = values.slice(offset, offset + size)
    offset += size
    return result
  }
  return {
    conv1Kernel: take(SIZES[0]),
    conv1Bias: take(SIZES[1]),
    conv2Kernel: take(SIZES[2]),
    conv2Bias: take(SIZES[3]),
    denseKernel: take(SIZES[4]),
    denseBias: take(SIZES[5]),
  }
}

function argmax(values: Float32Array) {
  let best = 0
  for (let index = 1; index < values.length; index += 1) {
    if (values[index] > values[best]) best = index
  }
  return best
}

async function values(tensor: tf.Tensor) {
  return Float32Array.from(await tensor.data())
}

export class CnnVisualModel {
  readonly parameters: CnnParameters
  private readonly tensors: {
    conv1Kernel: tf.Tensor4D
    conv1Bias: tf.Tensor1D
    conv2Kernel: tf.Tensor4D
    conv2Bias: tf.Tensor1D
    denseKernel: tf.Tensor2D
    denseBias: tf.Tensor1D
  }

  constructor(packed: Float32Array) {
    this.parameters = unpack(packed)
    this.tensors = {
      conv1Kernel: tf.tensor4d(this.parameters.conv1Kernel, [3, 3, 1, 8]),
      conv1Bias: tf.tensor1d(this.parameters.conv1Bias),
      conv2Kernel: tf.tensor4d(this.parameters.conv2Kernel, [3, 3, 8, 16]),
      conv2Bias: tf.tensor1d(this.parameters.conv2Bias),
      denseKernel: tf.tensor2d(this.parameters.denseKernel, [784, 10]),
      denseBias: tf.tensor1d(this.parameters.denseBias),
    }
  }

  async infer(input: Float32Array, sampleId: string, label: number | null): Promise<CnnTrace> {
    const startedAt = performance.now()
    const result = tf.tidy(() => {
      const x = tf.tensor4d(input, [1, 28, 28, 1])
      const conv1 = tf.relu(tf.conv2d(x, this.tensors.conv1Kernel, 1, 'same').add(this.tensors.conv1Bias)) as tf.Tensor4D
      const pool1 = tf.maxPool(conv1, [2, 2], [2, 2], 'valid')
      const conv2 = tf.relu(tf.conv2d(pool1, this.tensors.conv2Kernel, 1, 'same').add(this.tensors.conv2Bias)) as tf.Tensor4D
      const pool2 = tf.maxPool(conv2, [2, 2], [2, 2], 'valid')
      const flat = pool2.reshape([1, 784])
      const logits = tf.matMul(flat, this.tensors.denseKernel).add(this.tensors.denseBias)
      const probabilities = tf.softmax(logits)
      return { conv1, pool1, conv2, pool2, flat, logits, probabilities }
    })
    try {
      const [conv1, pool1, conv2, pool2, flat, logits, probabilities] = await Promise.all([
        values(result.conv1), values(result.pool1), values(result.conv2), values(result.pool2),
        values(result.flat), values(result.logits), values(result.probabilities),
      ])
      return {
        sampleId,
        label,
        computeDurationMs: performance.now() - startedAt,
        input: Float32Array.from(input),
        conv1,
        pool1,
        conv2,
        pool2,
        flat,
        logits,
        probabilities,
        predictedClass: argmax(probabilities),
        parameters: this.parameters,
      }
    } finally {
      tf.dispose(result)
    }
  }

  dispose() {
    tf.dispose(Object.values(this.tensors))
  }
}

export function featureChannel(values: Float32Array, size: number, channels: number, channel: number) {
  return Float32Array.from({ length: size * size }, (_, index) => values[index * channels + channel])
}

export function maxPosition(values: Float32Array) {
  const index = argmax(values)
  const size = Math.round(Math.sqrt(values.length))
  return { x: index % size, y: Math.floor(index / size), value: values[index] }
}

export function conv1Kernel(parameters: CnnParameters, channel: number) {
  return Float32Array.from({ length: 9 }, (_, index) => parameters.conv1Kernel[index * 8 + channel])
}

export function conv2Kernel(parameters: CnnParameters, inputChannel: number, outputChannel: number) {
  return Float32Array.from({ length: 9 }, (_, index) => parameters.conv2Kernel[(index * 8 + inputChannel) * 16 + outputChannel])
}

export function channelContribution(trace: CnnTrace, channel: number, output: number) {
  let total = 0
  for (let position = 0; position < 49; position += 1) {
    const flatIndex = position * 16 + channel
    total += trace.pool2[flatIndex] * trace.parameters.denseKernel[flatIndex * 10 + output]
  }
  return total
}

export type LocalTerm = { value: number; weight: number; product: number; x: number; y: number }

export function conv1CellBreakdown(trace: CnnTrace, channel: number, x: number, y: number) {
  const terms: LocalTerm[] = []
  for (let ky = 0; ky < 3; ky += 1) {
    for (let kx = 0; kx < 3; kx += 1) {
      const inputX = x + kx - 1
      const inputY = y + ky - 1
      const value = inputX < 0 || inputX >= 28 || inputY < 0 || inputY >= 28 ? 0 : trace.input[inputY * 28 + inputX]
      const weight = trace.parameters.conv1Kernel[(ky * 3 + kx) * 8 + channel]
      terms.push({ value, weight, product: value * weight, x: inputX, y: inputY })
    }
  }
  const bias = trace.parameters.conv1Bias[channel]
  const sum = terms.reduce((total, term) => total + term.product, bias)
  return { terms, bias, sum, activated: Math.max(0, sum) }
}

export function conv2CellBreakdown(trace: CnnTrace, inputChannel: number, outputChannel: number, x: number, y: number) {
  const terms: LocalTerm[] = []
  for (let ky = 0; ky < 3; ky += 1) {
    for (let kx = 0; kx < 3; kx += 1) {
      const inputX = x + kx - 1
      const inputY = y + ky - 1
      const value = inputX < 0 || inputX >= 14 || inputY < 0 || inputY >= 14
        ? 0
        : trace.pool1[(inputY * 14 + inputX) * 8 + inputChannel]
      const weight = trace.parameters.conv2Kernel[((ky * 3 + kx) * 8 + inputChannel) * 16 + outputChannel]
      terms.push({ value, weight, product: value * weight, x: inputX, y: inputY })
    }
  }
  let sum = trace.parameters.conv2Bias[outputChannel]
  for (let source = 0; source < 8; source += 1) {
    for (let ky = 0; ky < 3; ky += 1) {
      for (let kx = 0; kx < 3; kx += 1) {
        const inputX = x + kx - 1
        const inputY = y + ky - 1
        if (inputX < 0 || inputX >= 14 || inputY < 0 || inputY >= 14) continue
        const value = trace.pool1[(inputY * 14 + inputX) * 8 + source]
        const weight = trace.parameters.conv2Kernel[((ky * 3 + kx) * 8 + source) * 16 + outputChannel]
        sum += value * weight
      }
    }
  }
  return {
    terms,
    sourceSubtotal: terms.reduce((total, term) => total + term.product, 0),
    bias: trace.parameters.conv2Bias[outputChannel],
    sum,
    activated: Math.max(0, sum),
  }
}

export function poolCellBreakdown(trace: CnnTrace, stage: 'pool1' | 'pool2', channel: number, x: number, y: number) {
  const source = stage === 'pool1' ? trace.conv1 : trace.conv2
  const sourceSize = stage === 'pool1' ? 28 : 14
  const channels = stage === 'pool1' ? 8 : 16
  const values = Float32Array.from({ length: 4 }, (_, index) => {
    const sourceX = x * 2 + index % 2
    const sourceY = y * 2 + Math.floor(index / 2)
    return source[(sourceY * sourceSize + sourceX) * channels + channel]
  })
  const winner = values.reduce((best, value, index) => value > values[best] ? index : best, 0)
  return { values, winner, maximum: values[winner] }
}

export function evidenceMap(trace: CnnTrace, output: number) {
  const evidence = new Float32Array(49)
  for (let position = 0; position < 49; position += 1) {
    let total = 0
    for (let channel = 0; channel < 16; channel += 1) {
      const flatIndex = position * 16 + channel
      total += trace.pool2[flatIndex] * trace.parameters.denseKernel[flatIndex * 10 + output]
    }
    evidence[position] = total
  }
  return evidence
}

export function occlude(input: Float32Array, box: { x: number; y: number; size: number }) {
  const result = Float32Array.from(input)
  for (let y = Math.max(0, box.y); y < Math.min(28, box.y + box.size); y += 1) {
    for (let x = Math.max(0, box.x); x < Math.min(28, box.x + box.size); x += 1) result[y * 28 + x] = 0
  }
  return result
}

export const CNN_CONSTANTS = { CONV1_CHANNELS: 8, CONV2_CHANNELS: 16 }
