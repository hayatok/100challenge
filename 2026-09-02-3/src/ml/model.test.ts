import * as tf from '@tensorflow/tfjs'
import { afterAll, beforeAll, describe, expect, it } from 'vitest'
import { MODEL_CONSTANTS, VisualModel } from './model'

beforeAll(async () => {
  await tf.setBackend('cpu')
  await tf.ready()
})

afterAll(() => {
  tf.disposeVariables()
})

describe('VisualModel trace integrity', () => {
  it('produces probabilities that sum to one without changing revision', async () => {
    const model = VisualModel.learning(10)
    const input = new Float32Array(784)
    input[13 * 28 + 13] = 1
    const trace = await model.infer(input, 'fixed', 3)

    const total = Array.from(trace.forwardBefore.probabilities).reduce((sum, value) => sum + value, 0)
    expect(total).toBeCloseTo(1, 5)
    expect(trace.modelRevisionBefore).toBe(0)
    expect(trace.modelRevisionAfter).toBe(0)
    expect(model.revision).toBe(0)
    expect(trace.lossBefore).toBeCloseTo(-Math.log(trace.forwardBefore.probabilities[3]), 5)
    model.dispose()
  })

  it('records an exact SGD update and increments revision once', async () => {
    const model = VisualModel.learning(20)
    const input = new Float32Array(784)
    for (let y = 5; y < 23; y += 1) input[y * 28 + 14] = 1
    const trace = await model.guidedTrain(input, 'training-3', 3)
    const index = trace.gradients!.w2.findIndex((value) => Math.abs(value) > 1e-7)

    expect(index).toBeGreaterThanOrEqual(0)
    expect(trace.updates!.w2[index]).toBeCloseTo(
      -MODEL_CONSTANTS.LEARNING_RATE * trace.gradients!.w2[index],
      5,
    )
    expect(trace.parametersAfter!.w2[index]).toBeCloseTo(
      trace.parametersBefore.w2[index] + trace.updates!.w2[index],
      5,
    )
    expect(trace.modelRevisionBefore).toBe(0)
    expect(trace.modelRevisionAfter).toBe(1)
    expect(model.revision).toBe(1)

    const hidden = trace.forwardBefore.a1
    const lossAt = (weight: number) => {
      const logits = Float32Array.from(trace.forwardBefore.logits)
      const hiddenIndex = Math.floor(index / 10)
      const outputIndex = index % 10
      const original = trace.parametersBefore.w2[index]
      logits[outputIndex] += hidden[hiddenIndex] * (weight - original)
      const maximum = Math.max(...logits)
      const exponentials = Array.from(logits, (value) => Math.exp(value - maximum))
      const total = exponentials.reduce((sum, value) => sum + value, 0)
      return -Math.log(exponentials[3] / total)
    }
    const epsilon = 0.001
    const originalWeight = trace.parametersBefore.w2[index]
    const finiteDifference = (lossAt(originalWeight + epsilon) - lossAt(originalWeight - epsilon)) / (2 * epsilon)
    expect(trace.gradients!.w2[index]).toBeCloseTo(finiteDifference, 3)
    model.dispose()
  })

  it('restores the pre-training parameters as a new revision', async () => {
    const model = VisualModel.learning(30)
    const input = new Float32Array(784)
    input.fill(0.25)
    const trace = await model.guidedTrain(input, 'undo', 8)

    expect(model.canUndoGuided()).toBe(true)
    expect(await model.undoGuided()).toBe(true)
    const restored = await model.snapshotParameters()
    expect(Array.from(restored.w1.slice(0, 20))).toEqual(Array.from(trace.parametersBefore.w1.slice(0, 20)))
    expect(model.revision).toBe(2)
    expect(model.canUndoGuided()).toBe(false)
    model.dispose()
  })
})
