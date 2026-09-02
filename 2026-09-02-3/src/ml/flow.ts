export type FlowModelFamily = 'mlp' | 'cnn'

export function flowActiveIndex(model: FlowModelFamily, phaseIndex: number) {
  if (model === 'cnn') return [0, 1, 2, 3, 6, 7][Math.min(phaseIndex, 5)]
  if (phaseIndex <= 5) return [0, 2, 3, 4, 5, 6][phaseIndex]
  if (phaseIndex <= 7) return 6
  if (phaseIndex === 8) return 4
  if (phaseIndex <= 10) return 2
  return 6
}
