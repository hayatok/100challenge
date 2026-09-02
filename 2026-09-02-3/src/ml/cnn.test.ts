import * as tf from '@tensorflow/tfjs'
import { afterAll, beforeAll, describe, expect, it } from 'vitest'
import {
  CnnVisualModel,
  channelContribution,
  conv1CellBreakdown,
  conv1Kernel,
  conv2CellBreakdown,
  evidenceMap,
  featureChannel,
  occlude,
  poolCellBreakdown,
} from './cnn'

beforeAll(async () => {
  await tf.setBackend('cpu')
  await tf.ready()
})

afterAll(() => {
  tf.disposeVariables()
})

function weights() {
  return Float32Array.from({ length: 9098 }, (_, index) => Math.sin(index * 0.17) * 0.04)
}

describe('CNN trace integrity', () => {
  it('records every real feature tensor with the expected shape', async () => {
    const model = new CnnVisualModel(weights())
    const input = new Float32Array(784)
    for (let y = 5; y < 24; y += 1) input[y * 28 + 14] = 1
    const trace = await model.infer(input, 'line', 1)

    expect(trace.conv1).toHaveLength(28 * 28 * 8)
    expect(trace.pool1).toHaveLength(14 * 14 * 8)
    expect(trace.conv2).toHaveLength(14 * 14 * 16)
    expect(trace.pool2).toHaveLength(7 * 7 * 16)
    expect(trace.flat).toHaveLength(784)
    expect(trace.probabilities.reduce((sum, value) => sum + value, 0)).toBeCloseTo(1, 5)
    model.dispose()
  })

  it('extracts NHWC feature channels without reordering positions', () => {
    const interleaved = Float32Array.from({ length: 2 * 2 * 3 }, (_, index) => index)
    expect(Array.from(featureChannel(interleaved, 2, 3, 1))).toEqual([1, 4, 7, 10])
  })

  it('uses the selected real kernel and dense weights for inspection', async () => {
    const packed = weights()
    const model = new CnnVisualModel(packed)
    const trace = await model.infer(new Float32Array(784).fill(0.5), 'flat', 0)
    const kernel = conv1Kernel(trace.parameters, 3)

    expect(kernel[0]).toBeCloseTo(packed[3], 7)
    expect(kernel[1]).toBeCloseTo(packed[11], 7)

    let expected = 0
    for (let position = 0; position < 49; position += 1) {
      const flatIndex = position * 16 + 2
      expected += trace.pool2[flatIndex] * trace.parameters.denseKernel[flatIndex * 10 + 4]
    }
    expect(channelContribution(trace, 2, 4)).toBeCloseTo(expected, 6)
    model.dispose()
  })

  it('reconstructs local convolution, pooling, and output evidence from the trace', async () => {
    const model = new CnnVisualModel(weights())
    const trace = await model.infer(new Float32Array(784).fill(0.5), 'flat', 0)
    const convolution = conv1CellBreakdown(trace, 2, 10, 11)
    const deepConvolution = conv2CellBreakdown(trace, 4, 6, 5, 7)
    const pooling = poolCellBreakdown(trace, 'pool1', 2, 5, 5)
    const evidence = evidenceMap(trace, 4)

    expect(convolution.activated).toBeCloseTo(trace.conv1[(11 * 28 + 10) * 8 + 2], 5)
    expect(deepConvolution.activated).toBeCloseTo(trace.conv2[(7 * 14 + 5) * 16 + 6], 5)
    expect(pooling.maximum).toBeCloseTo(trace.pool1[(5 * 14 + 5) * 8 + 2], 5)
    expect(evidence.reduce((sum, value) => sum + value, trace.parameters.denseBias[4])).toBeCloseTo(trace.logits[4], 4)
    model.dispose()
  })

  it('occludes only the requested input rectangle', () => {
    const input = new Float32Array(784).fill(1)
    const masked = occlude(input, { x: 10, y: 12, size: 4 })
    expect(Array.from(masked).filter((value) => value === 0)).toHaveLength(16)
    expect(masked[11 * 28 + 10]).toBe(1)
    expect(masked[12 * 28 + 10]).toBe(0)
  })

  it('trains a real CNN step and can restore its previous parameters', async () => {
    const model = CnnVisualModel.learning(42)
    const input = new Float32Array(784)
    for (let y = 7; y < 23; y += 1) input[y * 28 + 14] = 1
    const training = await model.guidedTrain(input, 'train-line', 1)

    expect(training.lossBefore).toBeGreaterThan(0)
    expect(training.gradientMeanAbs).toBeGreaterThan(0)
    expect(training.updateMeanAbs).toBeCloseTo(training.gradientMeanAbs * 0.01, 8)
    expect(Array.from(training.after.parameters.denseKernel).some((value, index) => value !== training.before.parameters.denseKernel[index])).toBe(true)
    expect(model.canUndoGuided()).toBe(true)

    await model.undoGuided()
    const restored = await model.infer(input, 'restored-line', 1)
    expect(restored.logits[1]).toBeCloseTo(training.before.logits[1], 5)
    model.dispose()
  })

  it('benchmarks a dataset and advances bulk learning in real batches', async () => {
    const model = CnnVisualModel.learning(7)
    const samples = Array.from({ length: 20 }, (_, index) => ({
      id: `sample-${index}`,
      split: 'train' as const,
      label: index % 10,
      pixels: new Float32Array(784).fill((index + 1) / 20),
    }))
    const before = await model.evaluate(samples)
    const batches: number[] = []
    await model.bulkTrain(samples, (processed) => { batches.push(processed) })
    const after = await model.evaluate(samples)

    expect(before).toBeGreaterThanOrEqual(0)
    expect(before).toBeLessThanOrEqual(1)
    expect(after).toBeGreaterThanOrEqual(0)
    expect(after).toBeLessThanOrEqual(1)
    expect(batches).toEqual([10, 20])
    expect(model.revision).toBe(2)
    model.dispose()
  })
})
