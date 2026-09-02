import * as tf from '@tensorflow/tfjs'
import { createRandom, glorot } from './random'

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

export type CnnTrainingTrace = {
  before: CnnTrace
  after: CnnTrace
  lossBefore: number
  gradientMeanAbs: number
  updateMeanAbs: number
  revisionBefore: number
  revisionAfter: number
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
  revision = 0
  private readonly trainable: boolean
  private readonly tensors: {
    conv1Kernel: tf.Variable
    conv1Bias: tf.Variable
    conv2Kernel: tf.Variable
    conv2Bias: tf.Variable
    denseKernel: tf.Variable
    denseBias: tf.Variable
  }
  private lastBefore: CnnParameters | null = null

  constructor(packed: Float32Array, trainable = false, id = 'cnn-fixed') {
    const parameters = unpack(packed)
    this.trainable = trainable
    this.tensors = {
      conv1Kernel: tf.variable(tf.tensor4d(parameters.conv1Kernel, [3, 3, 1, 8]), trainable, `${id}-conv1-kernel`),
      conv1Bias: tf.variable(tf.tensor1d(parameters.conv1Bias), trainable, `${id}-conv1-bias`),
      conv2Kernel: tf.variable(tf.tensor4d(parameters.conv2Kernel, [3, 3, 8, 16]), trainable, `${id}-conv2-kernel`),
      conv2Bias: tf.variable(tf.tensor1d(parameters.conv2Bias), trainable, `${id}-conv2-bias`),
      denseKernel: tf.variable(tf.tensor2d(parameters.denseKernel, [784, 10]), trainable, `${id}-dense-kernel`),
      denseBias: tf.variable(tf.tensor1d(parameters.denseBias), trainable, `${id}-dense-bias`),
    }
  }

  static learning(seed = 20260902) {
    const random = createRandom(seed)
    const packed = new Float32Array(9098)
    let offset = 0
    for (const values of [
      glorot(72, 9, 72, random), new Float32Array(8),
      glorot(1152, 72, 144, random), new Float32Array(16),
      glorot(7840, 784, 10, random), new Float32Array(10),
    ]) { packed.set(values, offset); offset += values.length }
    return new CnnVisualModel(packed, true, 'cnn-learning')
  }

  private async snapshotParameters(): Promise<CnnParameters> {
    const [conv1Kernel, conv1Bias, conv2Kernel, conv2Bias, denseKernel, denseBias] = await Promise.all(Object.values(this.tensors).map(async (tensor) => Float32Array.from(await tensor.data())))
    return { conv1Kernel, conv1Bias, conv2Kernel, conv2Bias, denseKernel, denseBias }
  }

  async infer(input: Float32Array, sampleId: string, label: number | null): Promise<CnnTrace> {
    const startedAt = performance.now()
    const result = tf.tidy(() => {
      const x = tf.tensor4d(input, [1, 28, 28, 1])
      const conv1 = tf.relu(tf.conv2d(x, this.tensors.conv1Kernel as tf.Tensor4D, 1, 'same').add(this.tensors.conv1Bias)) as tf.Tensor4D
      const pool1 = tf.maxPool(conv1, [2, 2], [2, 2], 'valid')
      const conv2 = tf.relu(tf.conv2d(pool1, this.tensors.conv2Kernel as tf.Tensor4D, 1, 'same').add(this.tensors.conv2Bias)) as tf.Tensor4D
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
        parameters: await this.snapshotParameters(),
      }
    } finally {
      tf.dispose(result)
    }
  }

  async guidedTrain(input: Float32Array, sampleId: string, label: number): Promise<CnnTrainingTrace> {
    if (!this.trainable) throw new Error('学習済みCNNは更新できません')
    const before = await this.infer(input, sampleId, label)
    const revisionBefore = this.revision
    const x = tf.tensor4d(input, [1, 28, 28, 1])
    const target = tf.oneHot(tf.tensor1d([label], 'int32'), 10)
    const result = tf.variableGrads(() => {
      const conv1 = tf.relu(tf.conv2d(x, this.tensors.conv1Kernel as tf.Tensor4D, 1, 'same').add(this.tensors.conv1Bias)) as tf.Tensor4D
      const pool1 = tf.maxPool(conv1, [2, 2], [2, 2], 'valid')
      const conv2 = tf.relu(tf.conv2d(pool1, this.tensors.conv2Kernel as tf.Tensor4D, 1, 'same').add(this.tensors.conv2Bias)) as tf.Tensor4D
      const pool2 = tf.maxPool(conv2, [2, 2], [2, 2], 'valid')
      const logits = tf.matMul(pool2.reshape([1, 784]), this.tensors.denseKernel as tf.Tensor2D).add(this.tensors.denseBias)
      return tf.losses.softmaxCrossEntropy(target, logits).mean() as tf.Scalar
    }, Object.values(this.tensors))
    const gradientArrays = await Promise.all(Object.values(this.tensors).map(async (variable) => Float32Array.from(await result.grads[variable.name].data())))
    const gradientMeanAbs = gradientArrays.reduce((sum, values) => sum + values.reduce((part, value) => part + Math.abs(value), 0), 0) / 9098
    const lossBefore = (await result.value.data())[0]
    this.lastBefore = before.parameters
    const learningRate = 0.01
    tf.tidy(() => Object.values(this.tensors).forEach((variable) => variable.assign(variable.sub(result.grads[variable.name].mul(learningRate)))))
    tf.dispose([x, target, result.value, ...Object.values(result.grads)])
    this.revision += 1
    const after = await this.infer(input, sampleId, label)
    return { before, after, lossBefore, gradientMeanAbs, updateMeanAbs: gradientMeanAbs * learningRate, revisionBefore, revisionAfter: this.revision }
  }

  canUndoGuided() { return this.lastBefore !== null }

  async undoGuided() {
    if (!this.lastBefore) return false
    const before = this.lastBefore
    tf.tidy(() => {
      this.tensors.conv1Kernel.assign(tf.tensor4d(before.conv1Kernel, [3, 3, 1, 8]))
      this.tensors.conv1Bias.assign(tf.tensor1d(before.conv1Bias))
      this.tensors.conv2Kernel.assign(tf.tensor4d(before.conv2Kernel, [3, 3, 8, 16]))
      this.tensors.conv2Bias.assign(tf.tensor1d(before.conv2Bias))
      this.tensors.denseKernel.assign(tf.tensor2d(before.denseKernel, [784, 10]))
      this.tensors.denseBias.assign(tf.tensor1d(before.denseBias))
    })
    this.lastBefore = null
    this.revision += 1
    return true
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
