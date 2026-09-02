import { createHash } from 'node:crypto'
import { readFileSync } from 'node:fs'
import { resolve } from 'node:path'
import { describe, expect, it } from 'vitest'
import type { DataManifest } from './dataset'

const dataRoot = resolve(import.meta.dirname, '../../public/data')
const manifest = JSON.parse(readFileSync(resolve(dataRoot, 'manifest.json'), 'utf8')) as DataManifest

function digest(name: string) {
  return createHash('sha256').update(readFileSync(resolve(dataRoot, name))).digest('hex')
}

describe('bundled MNIST provenance', () => {
  it.each(['guided', 'train', 'test'] as const)('matches the %s split manifest', (split) => {
    const definition = manifest.splits[split]
    const images = readFileSync(resolve(dataRoot, definition.images))
    const labels = readFileSync(resolve(dataRoot, definition.labels))

    expect(images.byteLength).toBe(definition.count * 784)
    expect(labels.byteLength).toBe(definition.count)
    expect(digest(definition.images)).toBe(definition.imagesSha256)
    expect(digest(definition.labels)).toBe(definition.labelsSha256)
    const counts = Array.from({ length: 10 }, (_, digit) => labels.filter((label: number) => label === digit).length)
    expect(new Set(counts).size).toBe(1)
  })

  it('records the approved architecture and model artifact', () => {
    expect(manifest.model.architecture).toEqual([784, 16, 10])
    expect(manifest.splits.train.count).toBe(5000)
    expect(manifest.splits.test.count).toBe(1000)
    expect(digest(manifest.model.weights)).toBe(manifest.model.weightsSha256)
    expect(readFileSync(resolve(dataRoot, manifest.model.weights)).byteLength).toBe(12730 * 4)
    expect(manifest.model.testAccuracy).toBeGreaterThan(0.9)
  })
})
