import * as tf from '@tensorflow/tfjs'
import { afterAll, beforeAll, describe, expect, it } from 'vitest'
import { CnnVisualModel, channelContribution, conv1Kernel, featureChannel } from './cnn'

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
})
