import { useEffect, useRef, useState } from 'react'
import * as THREE from 'three'
import { featureChannel, type CnnTrace } from '../ml/cnn'
import type { MapPoint } from './CnnExplorer'

type Props = {
  input: Float32Array
  trace: CnnTrace | null
  phaseIndex: number
  selectedPoint: MapPoint | null
  onSelectPhase: (phase: number) => void
}

const LAYERS = [
  ['入力', '28×28×1', 0], ['Conv1', '28×28×8', 1], ['Pool1', '14×14×8', 2], ['Conv2', '14×14×16', 3],
  ['Pool2', '7×7×16', 4], ['Flatten', '784', 4], ['Dense', '10', 4], ['回答', '0–9', 5],
] as const
const X = [-7, -5, -3, -1, 1, 3, 5, 7]

function receptiveField(phase: number, point: MapPoint | null) {
  const size = phase === 1 ? 28 : phase === 2 ? 14 : phase === 3 ? 14 : 7
  const selected = point ?? { x: Math.floor(size / 2), y: Math.floor(size / 2) }
  const raw = phase === 1
    ? { x: selected.x - 1, y: selected.y - 1, size: 3 }
    : phase === 2
      ? { x: selected.x * 2 - 1, y: selected.y * 2 - 1, size: 4 }
      : phase === 3
        ? { x: selected.x * 2 - 3, y: selected.y * 2 - 3, size: 8 }
        : { x: selected.x * 4 - 3, y: selected.y * 4 - 3, size: 10 }
  const x = Math.max(0, raw.x)
  const y = Math.max(0, raw.y)
  return {
    x,
    y,
    width: Math.max(1, Math.min(28, raw.x + raw.size) - x),
    height: Math.max(1, Math.min(28, raw.y + raw.size) - y),
  }
}

function texture(values: Float32Array, size: number) {
  const canvas = document.createElement('canvas')
  canvas.width = size
  canvas.height = size
  const context = canvas.getContext('2d')!
  const image = context.createImageData(size, size)
  const maximum = Math.max(...values, 0.000001)
  values.forEach((value, index) => {
    const level = Math.max(0, Math.min(1, value / maximum))
    image.data[index * 4] = 20 + level * 35
    image.data[index * 4 + 1] = 34 + level * 185
    image.data[index * 4 + 2] = 38 + level * 180
    image.data[index * 4 + 3] = 255
  })
  context.putImageData(image, 0, 0)
  const result = new THREE.CanvasTexture(canvas)
  result.colorSpace = THREE.SRGBColorSpace
  result.magFilter = THREE.NearestFilter
  return result
}

export function CnnScene3D({ input, trace, phaseIndex, selectedPoint, onSelectPhase }: Props) {
  const mount = useRef<HTMLDivElement>(null)
  const [view, setView] = useState<'overview' | 'focus'>('overview')

  useEffect(() => {
    const host = mount.current
    if (!host) return
    const scene = new THREE.Scene()
    scene.background = new THREE.Color('#10191c')
    const camera = new THREE.PerspectiveCamera(42, 1, 0.1, 100)
    const active = phaseIndex <= 3 ? phaseIndex : phaseIndex === 4 ? 6 : 7
    const baseCameraZ = view === 'focus' ? 8 : 15
    const lookAtX = view === 'focus' ? X[active] : 0
    camera.position.set(lookAtX, view === 'focus' ? 2.8 : 5.7, baseCameraZ)
    camera.lookAt(lookAtX, 0, 0)
    const renderer = new THREE.WebGLRenderer({ antialias: true })
    renderer.setPixelRatio(Math.min(devicePixelRatio, 2))
    host.appendChild(renderer.domElement)
    const group = new THREE.Group()
    scene.add(group)
    const clickable: THREE.Object3D[] = []
    const ink = new THREE.LineBasicMaterial({ color: '#d6e3df', transparent: true, opacity: 0.48 })

    const maps: Array<{ values: Float32Array; size: number; channels: number } | null> = [
      { values: input, size: 28, channels: 1 },
      trace ? { values: trace.conv1, size: 28, channels: 8 } : null,
      trace ? { values: trace.pool1, size: 14, channels: 8 } : null,
      trace ? { values: trace.conv2, size: 14, channels: 16 } : null,
      trace ? { values: trace.pool2, size: 7, channels: 16 } : null,
    ]
    maps.forEach((map, layer) => {
      const count = layer === 0 ? 1 : layer === 3 || layer === 4 ? 5 : 4
      for (let channel = count - 1; channel >= 0; channel -= 1) {
        const values = map ? (map.channels === 1 ? map.values : featureChannel(map.values, map.size, map.channels, channel)) : new Float32Array(16)
        const material = new THREE.MeshBasicMaterial({ map: texture(values, map?.size ?? 4), side: THREE.DoubleSide, transparent: true, opacity: channel === 0 ? 1 : 0.72 })
        const scale = [2.4, 2.25, 1.7, 1.65, 1.2][layer]
        const panel = new THREE.Mesh(new THREE.PlaneGeometry(scale, scale), material)
        panel.position.set(X[layer], 0, -channel * 0.17)
        panel.userData.phase = LAYERS[layer][2]
        group.add(panel)
        clickable.push(panel)
        const edges = new THREE.LineSegments(new THREE.EdgesGeometry(panel.geometry), new THREE.LineBasicMaterial({ color: LAYERS[layer][2] === phaseIndex ? '#ffd563' : '#d6e3df' }))
        panel.add(edges)
      }
    })

    const vectorGeometry = new THREE.BoxGeometry(0.11, 0.11, 0.11)
    for (let index = 0; index < 14; index += 1) {
      const dot = new THREE.Mesh(vectorGeometry, new THREE.MeshBasicMaterial({ color: '#62c6c3' }))
      dot.position.set(X[5], -1.4 + index * 0.21, 0)
      dot.userData.phase = 4; group.add(dot); clickable.push(dot)
    }
    for (let digit = 0; digit < 10; digit += 1) {
      const probability = trace?.probabilities[digit] ?? 0
      const node = new THREE.Mesh(new THREE.SphereGeometry(0.1 + probability * 0.22, 14, 14), new THREE.MeshBasicMaterial({ color: digit === trace?.predictedClass ? '#ffd563' : '#f2f0e6' }))
      node.position.set(X[6], -1.35 + digit * 0.3, 0); node.userData.phase = 4; group.add(node); clickable.push(node)
      const answer = node.clone(); answer.position.x = X[7]; answer.scale.setScalar(digit === trace?.predictedClass ? 1.8 : 0.8); answer.userData.phase = 5; group.add(answer); clickable.push(answer)
    }
    for (let layer = 0; layer < X.length - 1; layer += 1) {
      for (const y of [-0.75, 0, 0.75]) {
        group.add(new THREE.Line(new THREE.BufferGeometry().setFromPoints([new THREE.Vector3(X[layer] + 0.65, y, 0), new THREE.Vector3(X[layer + 1] - 0.65, y * 0.55, 0)]), ink))
      }
    }
    if (trace && phaseIndex >= 1 && phaseIndex <= 4) {
      const field = receptiveField(phaseIndex, selectedPoint)
      const inputScale = 2.4
      const left = X[0] - inputScale / 2 + field.x / 28 * inputScale
      const right = left + field.width / 28 * inputScale
      const top = inputScale / 2 - field.y / 28 * inputScale
      const bottom = top - field.height / 28 * inputScale
      const centerY = (top + bottom) / 2
      const outline = new THREE.LineLoop(
        new THREE.BufferGeometry().setFromPoints([[left, top, .08], [right, top, .08], [right, bottom, .08], [left, bottom, .08]].map(([x, y, z]) => new THREE.Vector3(x, y, z))),
        new THREE.LineBasicMaterial({ color: '#ffd563' }),
      )
      group.add(outline)
      const targetLayer = Math.min(phaseIndex, 4)
      group.add(new THREE.Line(
        new THREE.BufferGeometry().setFromPoints([new THREE.Vector3(right, centerY, .08), new THREE.Vector3(X[targetLayer] - .65, centerY * .35, .08)]),
        new THREE.LineBasicMaterial({ color: '#ffd563' }),
      ))
    }

    const packet = new THREE.Mesh(new THREE.SphereGeometry(.09, 10, 10), new THREE.MeshBasicMaterial({ color: phaseIndex >= 8 ? '#db5477' : '#ffd563' }))
    group.add(packet)
    let frame = 0
    const reduceMotion = matchMedia('(prefers-reduced-motion: reduce)').matches
    const render = (time = 0) => {
      const progress = reduceMotion ? .5 : (time / 900) % 1
      packet.position.set(THREE.MathUtils.lerp(X[Math.max(0, active - 1)], X[active], progress), 0, .4)
      renderer.render(scene, camera)
      frame = requestAnimationFrame(render)
    }
    const resize = () => {
      const width = host.clientWidth
      const height = host.clientHeight
      renderer.setSize(width, height, false)
      camera.aspect = width / height
      camera.position.z = baseCameraZ * Math.max(1, 2 / camera.aspect)
      camera.lookAt(lookAtX, 0, 0)
      camera.updateProjectionMatrix()
    }
    const observer = new ResizeObserver(resize); observer.observe(host); resize(); render()
    const click = (event: PointerEvent) => {
      const rect = renderer.domElement.getBoundingClientRect()
      const pointer = new THREE.Vector2((event.clientX - rect.left) / rect.width * 2 - 1, -(event.clientY - rect.top) / rect.height * 2 + 1)
      const raycaster = new THREE.Raycaster(); raycaster.setFromCamera(pointer, camera)
      const hit = raycaster.intersectObjects(clickable)[0]
      if (hit) onSelectPhase(hit.object.userData.phase)
    }
    renderer.domElement.addEventListener('pointerdown', click)
    return () => {
      cancelAnimationFrame(frame); observer.disconnect(); renderer.domElement.removeEventListener('pointerdown', click)
      scene.traverse((object) => {
        if ('geometry' in object && object.geometry instanceof THREE.BufferGeometry) object.geometry.dispose()
        if ('material' in object) {
          const objectMaterial = object.material as THREE.Material | THREE.Material[]
          const materials = Array.isArray(objectMaterial) ? objectMaterial : [objectMaterial]
          materials.forEach((material) => {
            if (material instanceof THREE.MeshBasicMaterial) material.map?.dispose()
            material.dispose()
          })
        }
      })
      renderer.dispose(); renderer.domElement.remove()
    }
  }, [input, trace, phaseIndex, selectedPoint, view, onSelectPhase])

  return <section className="cnn-scene" aria-label="CNN全体の3Dネットワーク">
    <header><div><p className="section-number">3D CNN / REAL TRACE</p><h2>画像が、数字の答えになるまで</h2><p>面の束が特徴マップ、線がデータの経路です。黄色い枠から選択セルへ、実際の受容野を接続します。</p></div><div className="scene-controls"><button type="button" aria-pressed={view === 'overview'} onClick={() => setView('overview')}>全体を見る</button><button type="button" aria-pressed={view === 'focus'} onClick={() => setView('focus')}>現在へ寄る</button></div></header>
    <div className="cnn-scene__canvas" ref={mount} />
    <div className="cnn-scene__labels">{LAYERS.map(([name, shape, phase]) => <button type="button" key={name} aria-current={phase === phaseIndex ? 'step' : undefined} onClick={() => onSelectPhase(phase)} disabled={!trace}><strong>{name}</strong><small>{shape}</small></button>)}</div>
    <p className="cnn-scene__legend"><span><i />黄色: 現在の演算と受容野</span><span>青緑の面: 実traceの活性</span><span>クリック: レイヤーを観察</span></p>
  </section>
}
