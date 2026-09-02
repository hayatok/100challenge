#!/usr/bin/env node

import { readFile, writeFile } from 'node:fs/promises'
import { createHash } from 'node:crypto'
import { fileURLToPath } from 'node:url'
import path from 'node:path'
import * as tf from '@tensorflow/tfjs'

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..')
const dataDir = path.join(root, 'public', 'data')

const images = new Uint8Array(await readFile(path.join(dataDir, 'train-images.bin')))
const labels = new Uint8Array(await readFile(path.join(dataDir, 'train-labels.bin')))
const testImages = new Uint8Array(await readFile(path.join(dataDir, 'test-images.bin')))
const testLabels = new Uint8Array(await readFile(path.join(dataDir, 'test-labels.bin')))

const model = tf.sequential({
  layers: [
    tf.layers.conv2d({
      name: 'conv1', inputShape: [28, 28, 1], filters: 8, kernelSize: 3,
      padding: 'same', activation: 'relu',
      kernelInitializer: tf.initializers.glorotUniform({ seed: 20260902 }),
    }),
    tf.layers.maxPooling2d({ name: 'pool1', poolSize: 2, strides: 2 }),
    tf.layers.conv2d({
      name: 'conv2', filters: 16, kernelSize: 3, padding: 'same', activation: 'relu',
      kernelInitializer: tf.initializers.glorotUniform({ seed: 20260903 }),
    }),
    tf.layers.maxPooling2d({ name: 'pool2', poolSize: 2, strides: 2 }),
    tf.layers.flatten({ name: 'flatten' }),
    tf.layers.dense({
      name: 'classifier', units: 10, activation: 'softmax',
      kernelInitializer: tf.initializers.glorotUniform({ seed: 20260904 }),
    }),
  ],
})

model.compile({
  optimizer: tf.train.adam(0.003),
  loss: 'categoricalCrossentropy',
  metrics: ['accuracy'],
})

const x = tf.tensor4d(images, [labels.length, 28, 28, 1]).div(255)
const y = tf.oneHot(tf.tensor1d(labels, 'int32'), 10)
const testX = tf.tensor4d(testImages, [testLabels.length, 28, 28, 1]).div(255)
const testY = tf.oneHot(tf.tensor1d(testLabels, 'int32'), 10)

const history = await model.fit(x, y, {
  epochs: 12,
  batchSize: 128,
  shuffle: true,
  validationData: [testX, testY],
  callbacks: {
    onEpochEnd: (epoch, logs) => {
      process.stdout.write(`epoch ${String(epoch + 1).padStart(2, '0')}/12 loss=${logs.loss.toFixed(4)} val_acc=${logs.val_acc.toFixed(4)}\n`)
    },
  },
})

const predictions = model.predict(testX).argMax(1)
const predicted = await predictions.data()
let correct = 0
predicted.forEach((value, index) => { if (value === testLabels[index]) correct += 1 })

const weights = model.getWeights()
const values = await Promise.all(weights.map(async (tensor) => Float32Array.from(await tensor.data())))
const total = values.reduce((sum, value) => sum + value.length, 0)
const packed = new Float32Array(total)
let offset = 0
for (const value of values) {
  packed.set(value, offset)
  offset += value.length
}
await writeFile(path.join(dataDir, 'cnn-pretrained-weights.bin'), Buffer.from(packed.buffer))
const weightsSha256 = createHash('sha256').update(Buffer.from(packed.buffer)).digest('hex')

const metadata = {
  architecture: ['conv3x3-8-relu', 'maxpool2x2', 'conv3x3-16-relu', 'maxpool2x2', 'flatten', 'dense-10-softmax'],
  optimizer: 'Adam',
  learningRate: 0.003,
  epochs: 12,
  trainingCount: labels.length,
  testCount: testLabels.length,
  testAccuracy: correct / testLabels.length,
  weights: 'cnn-pretrained-weights.bin',
  weightsSha256,
  parameterOrder: ['conv1Kernel', 'conv1Bias', 'conv2Kernel', 'conv2Bias', 'denseKernel', 'denseBias'],
  parameterShapes: [[3, 3, 1, 8], [8], [3, 3, 8, 16], [16], [784, 10], [10]],
  epochLoss: history.history.loss,
  validationAccuracy: history.history.val_acc,
}
await writeFile(path.join(dataDir, 'cnn-model.json'), `${JSON.stringify(metadata, null, 2)}\n`)

process.stdout.write(`test accuracy=${metadata.testAccuracy.toFixed(4)} parameters=${total}\n`)
tf.dispose([x, y, testX, testY, predictions])
model.dispose()
