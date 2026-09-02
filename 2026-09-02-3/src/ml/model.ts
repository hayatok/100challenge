import * as tf from '@tensorflow/tfjs'
import { createRandom, glorot } from './random'
import type {
  ComputationTrace,
  ForwardSnapshot,
  ModelId,
  ParameterSnapshot,
} from './types'

const INPUT_SIZE = 784
const HIDDEN_SIZE = 16
const OUTPUT_SIZE = 10
const LEARNING_RATE = 0.05

type Variables = {
  w1: tf.Variable
  b1: tf.Variable
  w2: tf.Variable
  b2: tf.Variable
}

function clone(values: Float32Array) {
  return Float32Array.from(values)
}

function argmax(values: Float32Array) {
  let best = 0
  for (let index = 1; index < values.length; index += 1) {
    if (values[index] > values[best]) best = index
  }
  return best
}

function subtract(before: ParameterSnapshot, after: ParameterSnapshot): ParameterSnapshot {
  const delta = (left: Float32Array, right: Float32Array) =>
    Float32Array.from(left, (value, index) => right[index] - value)
  return {
    w1: delta(before.w1, after.w1),
    b1: delta(before.b1, after.b1),
    w2: delta(before.w2, after.w2),
    b2: delta(before.b2, after.b2),
  }
}

async function tensorValues(tensor: tf.Tensor) {
  return clone(await tensor.data() as Float32Array)
}

export class VisualModel {
  readonly id: ModelId
  revision = 0
  private variables: Variables
  private lastGuidedBefore: ParameterSnapshot | null = null

  constructor(id: ModelId, parameters: ParameterSnapshot) {
    this.id = id
    this.variables = {
      w1: tf.variable(tf.tensor2d(parameters.w1, [INPUT_SIZE, HIDDEN_SIZE]), true, `${id}-w1`),
      b1: tf.variable(tf.tensor1d(parameters.b1), true, `${id}-b1`),
      w2: tf.variable(tf.tensor2d(parameters.w2, [HIDDEN_SIZE, OUTPUT_SIZE]), true, `${id}-w2`),
      b2: tf.variable(tf.tensor1d(parameters.b2), true, `${id}-b2`),
    }
  }

  static learning(seed = 20260902) {
    const random = createRandom(seed)
    return new VisualModel('learning', {
      w1: glorot(INPUT_SIZE * HIDDEN_SIZE, INPUT_SIZE, HIDDEN_SIZE, random),
      b1: new Float32Array(HIDDEN_SIZE),
      w2: glorot(HIDDEN_SIZE * OUTPUT_SIZE, HIDDEN_SIZE, OUTPUT_SIZE, random),
      b2: new Float32Array(OUTPUT_SIZE),
    })
  }

  static pretrained(buffer: Float32Array) {
    const w1End = INPUT_SIZE * HIDDEN_SIZE
    const b1End = w1End + HIDDEN_SIZE
    const w2End = b1End + HIDDEN_SIZE * OUTPUT_SIZE
    const b2End = w2End + OUTPUT_SIZE
    if (buffer.length !== b2End) throw new Error('学習済みモデルのパラメータ数が一致しません')
    return new VisualModel('pretrained', {
      w1: buffer.slice(0, w1End),
      b1: buffer.slice(w1End, b1End),
      w2: buffer.slice(b1End, w2End),
      b2: buffer.slice(w2End, b2End),
    })
  }

  async snapshotParameters(): Promise<ParameterSnapshot> {
    const [w1, b1, w2, b2] = await Promise.all([
      tensorValues(this.variables.w1),
      tensorValues(this.variables.b1),
      tensorValues(this.variables.w2),
      tensorValues(this.variables.b2),
    ])
    return { w1, b1, w2, b2 }
  }

  private async forward(input: Float32Array): Promise<ForwardSnapshot> {
    const tensors = tf.tidy(() => {
      const x = tf.tensor2d(input, [1, INPUT_SIZE])
      const z1 = tf.matMul(x, this.variables.w1).add(this.variables.b1)
      const a1 = tf.relu(z1)
      const logits = tf.matMul(a1, this.variables.w2).add(this.variables.b2)
      const probabilities = tf.softmax(logits)
      return { z1, a1, logits, probabilities }
    })
    try {
      const [z1, a1, logits, probabilities] = await Promise.all([
        tensorValues(tensors.z1),
        tensorValues(tensors.a1),
        tensorValues(tensors.logits),
        tensorValues(tensors.probabilities),
      ])
      return { z1, a1, logits, probabilities }
    } finally {
      tf.dispose(tensors)
    }
  }

  async infer(input: Float32Array, sampleId: string, label: number | null): Promise<ComputationTrace> {
    const startedAt = performance.now()
    const [parametersBefore, forwardBefore] = await Promise.all([
      this.snapshotParameters(),
      this.forward(input),
    ])
    return {
      traceId: `${this.id}-inference-${this.revision}-${Date.now()}`,
      kind: 'inference',
      modelId: this.id,
      modelRevisionBefore: this.revision,
      modelRevisionAfter: this.revision,
      sampleId,
      label,
      predictedClassBefore: argmax(forwardBefore.probabilities),
      predictedClassAfter: null,
      computeDurationMs: performance.now() - startedAt,
      input: clone(input),
      parametersBefore,
      forwardBefore,
      lossBefore: label === null ? null : -Math.log(Math.max(forwardBefore.probabilities[label], 1e-7)),
      gradients: null,
      updates: null,
      parametersAfter: null,
      forwardAfter: null,
    }
  }

  async guidedTrain(input: Float32Array, sampleId: string, label: number): Promise<ComputationTrace> {
    if (this.id !== 'learning') throw new Error('学習済みモデルは更新できません')
    const startedAt = performance.now()
    const revisionBefore = this.revision
    const parametersBefore = await this.snapshotParameters()
    const forwardBefore = await this.forward(input)
    const x = tf.tensor2d(input, [1, INPUT_SIZE])
    const target = tf.oneHot(tf.tensor1d([label], 'int32'), OUTPUT_SIZE)
    const result = tf.variableGrads(() => {
      const hidden = tf.relu(tf.matMul(x, this.variables.w1).add(this.variables.b1))
      const logits = tf.matMul(hidden, this.variables.w2).add(this.variables.b2)
      return tf.losses.softmaxCrossEntropy(target, logits).mean() as tf.Scalar
    }, Object.values(this.variables))

    const gradientSnapshot: ParameterSnapshot = {
      w1: await tensorValues(result.grads[this.variables.w1.name]),
      b1: await tensorValues(result.grads[this.variables.b1.name]),
      w2: await tensorValues(result.grads[this.variables.w2.name]),
      b2: await tensorValues(result.grads[this.variables.b2.name]),
    }
    const lossBefore = (await result.value.data())[0]
    tf.tidy(() => {
      this.variables.w1.assign(this.variables.w1.sub(result.grads[this.variables.w1.name].mul(LEARNING_RATE)))
      this.variables.b1.assign(this.variables.b1.sub(result.grads[this.variables.b1.name].mul(LEARNING_RATE)))
      this.variables.w2.assign(this.variables.w2.sub(result.grads[this.variables.w2.name].mul(LEARNING_RATE)))
      this.variables.b2.assign(this.variables.b2.sub(result.grads[this.variables.b2.name].mul(LEARNING_RATE)))
    })
    tf.dispose([x, target, result.value, ...Object.values(result.grads)])

    this.lastGuidedBefore = parametersBefore
    this.revision += 1
    const [parametersAfter, forwardAfter] = await Promise.all([
      this.snapshotParameters(),
      this.forward(input),
    ])
    return {
      traceId: `${this.id}-training-${revisionBefore}-${Date.now()}`,
      kind: 'guided-training',
      modelId: this.id,
      modelRevisionBefore: revisionBefore,
      modelRevisionAfter: this.revision,
      sampleId,
      label,
      predictedClassBefore: argmax(forwardBefore.probabilities),
      predictedClassAfter: argmax(forwardAfter.probabilities),
      computeDurationMs: performance.now() - startedAt,
      input: clone(input),
      parametersBefore,
      forwardBefore,
      lossBefore,
      gradients: gradientSnapshot,
      updates: subtract(parametersBefore, parametersAfter),
      parametersAfter,
      forwardAfter,
    }
  }

  canUndoGuided() {
    return this.lastGuidedBefore !== null
  }

  async undoGuided() {
    if (!this.lastGuidedBefore) return false
    const snapshot = this.lastGuidedBefore
    tf.tidy(() => {
      this.variables.w1.assign(tf.tensor2d(snapshot.w1, [INPUT_SIZE, HIDDEN_SIZE]))
      this.variables.b1.assign(tf.tensor1d(snapshot.b1))
      this.variables.w2.assign(tf.tensor2d(snapshot.w2, [HIDDEN_SIZE, OUTPUT_SIZE]))
      this.variables.b2.assign(tf.tensor1d(snapshot.b2))
    })
    this.lastGuidedBefore = null
    this.revision += 1
    return true
  }

  private async trainBatch(inputs: Float32Array, labels: Uint8Array) {
    const size = labels.length
    const x = tf.tensor2d(inputs, [size, INPUT_SIZE])
    const target = tf.oneHot(tf.tensor1d(labels, 'int32'), OUTPUT_SIZE)
    const result = tf.variableGrads(() => {
      const hidden = tf.relu(tf.matMul(x, this.variables.w1).add(this.variables.b1))
      const logits = tf.matMul(hidden, this.variables.w2).add(this.variables.b2)
      return tf.losses.softmaxCrossEntropy(target, logits).mean() as tf.Scalar
    }, Object.values(this.variables))
    const loss = (await result.value.data())[0]
    tf.tidy(() => {
      for (const variable of Object.values(this.variables)) {
        variable.assign(variable.sub(result.grads[variable.name].mul(LEARNING_RATE)))
      }
    })
    tf.dispose([x, target, result.value, ...Object.values(result.grads)])
    this.revision += 1
    return loss
  }

  async bulkTrain(
    samples: Array<{ pixels: Float32Array; label: number | null }>,
    onBatch: (processed: number, loss: number) => void,
    shouldStop: () => boolean,
  ) {
    this.lastGuidedBefore = null
    let processed = 0
    let lastLoss = 0
    for (let start = 0; start < samples.length; start += 32) {
      const batch = samples.slice(start, start + 32)
      const inputs = new Float32Array(batch.length * INPUT_SIZE)
      const labels = new Uint8Array(batch.length)
      batch.forEach((sample, index) => {
        inputs.set(sample.pixels, index * INPUT_SIZE)
        labels[index] = sample.label ?? 0
      })
      lastLoss = await this.trainBatch(inputs, labels)
      processed += batch.length
      onBatch(processed, lastLoss)
      await tf.nextFrame()
      if (shouldStop()) break
    }
    return { processed, lastLoss }
  }

  async evaluate(samples: Array<{ pixels: Float32Array; label: number | null }>) {
    let correct = 0
    for (let start = 0; start < samples.length; start += 100) {
      const batch = samples.slice(start, start + 100)
      const inputs = new Float32Array(batch.length * INPUT_SIZE)
      batch.forEach((sample, index) => inputs.set(sample.pixels, index * INPUT_SIZE))
      const probabilities = tf.tidy(() => {
        const x = tf.tensor2d(inputs, [batch.length, INPUT_SIZE])
        const hidden = tf.relu(tf.matMul(x, this.variables.w1).add(this.variables.b1))
        return tf.softmax(tf.matMul(hidden, this.variables.w2).add(this.variables.b2))
      })
      const predictions = await probabilities.argMax(1).data()
      probabilities.dispose()
      predictions.forEach((prediction, index) => {
        if (prediction === batch[index].label) correct += 1
      })
      await tf.nextFrame()
    }
    return correct / samples.length
  }

  dispose() {
    tf.dispose(Object.values(this.variables))
  }
}

export const MODEL_CONSTANTS = { INPUT_SIZE, HIDDEN_SIZE, OUTPUT_SIZE, LEARNING_RATE }
