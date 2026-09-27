import { Vector3 } from 'three'
import { PhysicsWorld } from './physics/PhysicsWorld'
import { SceneView } from './rendering/SceneView'
import { HandTracker } from './vision/HandTracker'
import './style.css'

type Mode = 'idle' | 'camera' | 'mouse'

const app = document.querySelector<HTMLDivElement>('#app')!
app.innerHTML = `
  <main class="shell">
    <header class="topbar"><div class="brand"><span class="brand-mark">◈</span> REALITY <span>SANDBOX</span><small>V0 / HAND PHYSICS</small></div><div class="top-note">A WORLD YOU CAN TOUCH</div></header>
    <section class="world-wrap" aria-label="Physics playground">
      <div id="world" class="world"></div>
      <div class="world-shine" aria-hidden="true"></div>
      <div class="world-tag"><span class="pulse"></span><span id="mode-label">WORLD STANDBY</span></div>
      <div class="world-hint" id="world-hint">Move your hand across the camera to scatter the spheres.</div>
      <aside class="camera-card" id="camera-card" hidden><div class="camera-head"><span>CAM / LIVE</span><span id="hand-label">SEARCHING</span></div><div class="video-wrap" id="video-wrap"></div><div class="camera-foot">Mirror preview · video stays on this device</div></aside>
      <div class="bottom-controls" id="bottom-controls" hidden><button id="reset" type="button">RESET SPHERES</button><button id="switch-mode" type="button">USE MOUSE</button></div>
      <section class="intro" id="intro" aria-labelledby="intro-title"><div class="intro-inner"><p class="eyebrow">INTERACTIVE PHYSICS PLAYGROUND</p><h1 id="intro-title">REALITY<br><em>SANDBOX</em></h1><p class="intro-line">Move your hand.<br>Touch the world.</p><p class="intro-sub">Your webcam becomes a way into this world. Sweep your hand to send the spheres flying.</p><div class="intro-actions"><button id="start" class="primary" type="button">START WITH CAMERA <span aria-hidden="true">↗</span></button><button id="mouse" type="button">TRY WITH MOUSE</button></div><p class="privacy">Camera processing stays on this device. No account required.</p><p id="notice" class="notice" role="status" aria-live="polite"></p></div></section>
    </section>
    <footer class="statusbar"><span class="status-text" id="status">INITIALIZING WORLD</span><button id="debug-toggle" type="button" aria-expanded="false">DEBUG <span aria-hidden="true">⌁</span></button><div id="debug" class="debug" hidden><span>RENDER <b id="render-fps">—</b> FPS</span><span>TRACK <b id="track-fps">—</b> FPS</span><span>PHYSICS <b id="physics-time">—</b> MS</span><span>HANDS <b id="hands">0</b></span><span>OBJECTS <b id="objects">20</b></span></div></footer>
  </main>`

const element = <T extends HTMLElement>(id: string): T => document.getElementById(id) as T
const intro = element<HTMLElement>('intro')
const notice = element<HTMLElement>('notice')
const status = element<HTMLElement>('status')
const modeLabel = element<HTMLElement>('mode-label')
const handLabel = element<HTMLElement>('hand-label')
const controls = element<HTMLElement>('bottom-controls')
const cameraCard = element<HTMLElement>('camera-card')
const hint = element<HTMLElement>('world-hint')
const switchMode = element<HTMLButtonElement>('switch-mode')
const worldElement = element<HTMLElement>('world')

let scene: SceneView
let physics: PhysicsWorld
let tracker: HandTracker | undefined
let mode: Mode = 'idle'
let handTarget: Vector3 | null = null
let smoothedTarget: Vector3 | null = null
let handSeenAt = 0
let lastFrame = performance.now()
let accumulator = 0
let renderFrames = 0
let trackFrames = 0
let physicsTotal = 0
let physicsFrames = 0
let statsAt = performance.now()
let startGeneration = 0

function setStatus(message: string): void { status.textContent = message }

function activate(next: Mode): void {
  if (next === 'mouse') startGeneration++
  mode = next
  intro.hidden = true
  controls.hidden = false
  cameraCard.hidden = next !== 'camera'
  modeLabel.textContent = next === 'camera' ? 'CAMERA CONNECTED' : 'MOUSE MODE'
  hint.textContent = next === 'camera' ? 'Show one hand, then sweep it through the spheres.' : 'Move your pointer across the spheres.'
  switchMode.textContent = next === 'camera' ? 'USE MOUSE' : 'USE CAMERA'
  if (next === 'mouse') {
    tracker?.stop()
    tracker = undefined
    smoothedTarget = null
    handTarget = null
    physics.setHandTarget(null)
    setStatus('MOUSE MODE · MOVE POINTER TO TOUCH')
  } else {
    setStatus('CAMERA READY · SHOW YOUR HAND')
  }
  physics.resetBalls()
}

async function startCamera(): Promise<void> {
  if (!physics || mode === 'camera') return
  const generation = ++startGeneration
  element<HTMLButtonElement>('start').disabled = true
  notice.textContent = 'Waiting for camera…'
  tracker?.stop()
  const pendingTracker = new HandTracker()
  tracker = pendingTracker
  try {
    await pendingTracker.start(message => { if (generation === startGeneration) { notice.textContent = message; setStatus(message.toUpperCase()) } })
    if (generation !== startGeneration) { pendingTracker.stop(); return }
    const preview = element<HTMLElement>('video-wrap')
    preview.replaceChildren(pendingTracker.video)
    activate('camera')
  } catch (error) {
    pendingTracker.stop()
    if (generation !== startGeneration) return
    tracker = undefined
    const message = error instanceof DOMException && error.name === 'NotAllowedError'
      ? 'Camera permission was denied. You can still play with your mouse.'
      : `Camera could not start. ${error instanceof Error ? error.message : 'Try Mouse Mode.'}`
    notice.textContent = message
    setStatus('CAMERA UNAVAILABLE · MOUSE MODE READY')
  } finally {
    element<HTMLButtonElement>('start').disabled = false
  }
}

function startMouse(): void { activate('mouse') }

element<HTMLButtonElement>('start').addEventListener('click', () => void startCamera())
element<HTMLButtonElement>('mouse').addEventListener('click', startMouse)
element<HTMLButtonElement>('reset').addEventListener('click', () => physics.resetBalls())
switchMode.addEventListener('click', () => {
  if (mode === 'camera') startMouse()
  else {
    intro.hidden = false
    notice.textContent = ''
    void startCamera()
  }
})
element<HTMLButtonElement>('debug-toggle').addEventListener('click', event => {
  const debug = element<HTMLElement>('debug')
  debug.hidden = !debug.hidden
  ;(event.currentTarget as HTMLButtonElement).setAttribute('aria-expanded', String(!debug.hidden))
})
worldElement.addEventListener('pointermove', event => {
  if (mode !== 'mouse') return
  const bounds = worldElement.getBoundingClientRect()
  handTarget = scene.screenToWorld((event.clientX - bounds.left) / bounds.width, (event.clientY - bounds.top) / bounds.height)
})
worldElement.addEventListener('pointerleave', () => {
  if (mode === 'mouse') { handTarget = null; smoothedTarget = null; physics.setHandTarget(null) }
})

function frame(now: number): void {
  requestAnimationFrame(frame)
  const dt = Math.min((now - lastFrame) / 1000, 0.05)
  lastFrame = now
  if (mode === 'camera' && tracker) {
    try {
      const state = tracker.update(now)
      if (state) {
        trackFrames++
        element<HTMLElement>('hands').textContent = state.detected ? '1' : '0'
        if (state.detected) {
          // The preview is mirrored, so image x is inverted into screen x.
          handTarget = scene.screenToWorld(1 - state.x, state.y)
          handSeenAt = now
          handLabel.textContent = 'HAND FOUND'
          setStatus(`${state.handedness.toUpperCase() || 'HAND'} TRACKED · SWEEP TO PUSH`)
        } else if (now - handSeenAt > 180) {
          handTarget = null
          smoothedTarget = null
          handLabel.textContent = 'SEARCHING'
          setStatus('SHOW ONE HAND TO THE CAMERA')
        }
      }
    } catch (error) {
      tracker.stop()
      tracker = undefined
      mode = 'mouse'
      cameraCard.hidden = true
      switchMode.textContent = 'USE CAMERA'
      setStatus('TRACKING STOPPED · MOVE POINTER TO PLAY')
      handTarget = null
      smoothedTarget = null
      physics.setHandTarget(null)
      console.error('Hand tracking stopped:', error)
    }
  }
  if (mode === 'camera' && handTarget && now - handSeenAt > 400) {
    handTarget = null
    smoothedTarget = null
    handLabel.textContent = 'SEARCHING'
    setStatus('SHOW ONE HAND TO THE CAMERA')
  }

  if (handTarget) {
    if (!smoothedTarget) smoothedTarget = handTarget.clone()
    else smoothedTarget.lerp(handTarget, 1 - Math.exp(-dt * 18))
    physics.setHandTarget(smoothedTarget)
  } else if (mode !== 'idle') {
    physics.setHandTarget(null)
  }

  accumulator += dt
  let steps = 0
  while (accumulator >= physics.timestep && steps < 3) {
    physicsTotal += physics.step()
    physicsFrames++
    accumulator -= physics.timestep
    steps++
  }
  if (steps === 3) accumulator = 0
  scene.update(physics.getBalls(), physics.getHandPosition(), now)
  renderFrames++

  if (now - statsAt >= 1000) {
    const seconds = (now - statsAt) / 1000
    element<HTMLElement>('render-fps').textContent = String(Math.round(renderFrames / seconds))
    element<HTMLElement>('track-fps').textContent = mode === 'camera' ? String(Math.round(trackFrames / seconds)) : '—'
    element<HTMLElement>('physics-time').textContent = physicsFrames ? (physicsTotal / physicsFrames).toFixed(1) : '—'
    element<HTMLElement>('objects').textContent = String(physics.ballCount)
    renderFrames = 0; trackFrames = 0; physicsTotal = 0; physicsFrames = 0; statsAt = now
  }
}

async function boot(): Promise<void> {
  try {
    scene = new SceneView(worldElement)
    setStatus('INITIALIZING PHYSICS')
    physics = new PhysicsWorld()
    await physics.init()
    setStatus('WORLD READY · PRESS START')
    requestAnimationFrame(frame)
  } catch (error) {
    notice.textContent = `This browser cannot start the 3D world. ${error instanceof Error ? error.message : ''}`
    setStatus('WORLD UNAVAILABLE')
    element<HTMLButtonElement>('start').disabled = true
    element<HTMLButtonElement>('mouse').disabled = true
  }
}

void boot()
