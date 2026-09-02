export type ModelId = 'pretrained' | 'learning'

export type ParameterSnapshot = {
  w1: Float32Array
  b1: Float32Array
  w2: Float32Array
  b2: Float32Array
}

export type ForwardSnapshot = {
  z1: Float32Array
  a1: Float32Array
  logits: Float32Array
  probabilities: Float32Array
}

export type ComputationTrace = {
  traceId: string
  kind: 'inference' | 'guided-training'
  modelId: ModelId
  modelRevisionBefore: number
  modelRevisionAfter: number
  sampleId: string
  label: number | null
  predictedClassBefore: number
  predictedClassAfter: number | null
  computeDurationMs: number
  input: Float32Array
  parametersBefore: ParameterSnapshot
  forwardBefore: ForwardSnapshot
  lossBefore: number | null
  gradients: ParameterSnapshot | null
  updates: ParameterSnapshot | null
  parametersAfter: ParameterSnapshot | null
  forwardAfter: ForwardSnapshot | null
}

export type MnistSample = {
  id: string
  split: 'guided' | 'train' | 'test' | 'drawn'
  label: number | null
  pixels: Float32Array
}

export type TrainingMetric = {
  processed: number
  epoch: number
  batchLoss: number
  testAccuracy: number | null
}
