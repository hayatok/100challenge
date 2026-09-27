import { Vector3 } from 'three'
import { PhysicsWorld, type ObjectKind } from './physics/PhysicsWorld'
import { SceneView } from './rendering/SceneView'
import { imageXToScreen, type CameraFacing } from './vision/CameraFacing'
import { FlickDetector, type Flick } from './vision/FlickDetector'
import { HandTracker } from './vision/HandTracker'
import { ScreenContact } from './vision/ScreenContact'
import './style.css'

type Mode = 'idle' | 'camera' | 'mouse'

const app = document.querySelector<HTMLDivElement>('#app')!
app.innerHTML = `
  <main class="shell">
    <header class="topbar"><div class="brand"><span class="brand-mark">◈</span> REALITY <span>SANDBOX</span><small>V1 / PHYSICS PLAYGROUND</small></div><div class="top-note">A WORLD YOU CAN TOUCH</div></header>
    <section class="world-wrap" aria-label="Physics playground">
      <div id="world" class="world"></div>
      <div class="world-shine" aria-hidden="true"></div>
      <div class="world-tag"><span class="pulse"></span><span id="mode-label">WORLD STANDBY</span></div>
      <div class="world-hint" id="world-hint"><strong id="guide-title">ボールを狙う</strong><span id="guide-detail">3D画面の水色の手をボールに重ねる。白い輪が出たら横へ払う。</span></div>
      <div class="gesture-feedback" id="gesture-feedback" aria-live="polite"></div>
      <aside class="camera-card" id="camera-card" hidden><div class="camera-head"><span id="camera-facing">FRONT CAM</span><span id="hand-label">SEARCHING</span></div><div class="video-wrap" id="video-wrap"></div><div class="camera-foot" id="preview-note">Mirror preview · on-device processing</div><button id="flip-camera" type="button">USE REAR CAMERA</button></aside>
      <div class="sandbox-controls" id="bottom-controls" hidden>
        <div class="sandbox-heading"><span>BUILD YOUR WORLD</span><strong><span id="object-count">20</span> / 100 OBJECTS</strong><button id="objects-toggle" type="button" aria-expanded="false" aria-label="Show object controls">EDIT</button></div>
        <div class="sandbox-actions" aria-label="Add objects"><button data-add="ball" type="button">+ BALL</button><button data-add="box" type="button">+ BOX</button><button data-add="domino" type="button">+ DOMINO</button></div>
        <div class="sandbox-actions sandbox-secondary"><button id="reset" type="button">RESET 20</button><button id="load-100" type="button">LOAD 100</button><button id="clear" type="button">CLEAR ALL</button><button id="switch-mode" type="button">USE MOUSE</button></div>
      </div>
      <section class="intro" id="intro" aria-labelledby="intro-title"><div class="intro-inner"><p class="eyebrow">INTERACTIVE PHYSICS PLAYGROUND</p><h1 id="intro-title">REALITY<br><em>SANDBOX</em></h1><p class="intro-line">Move your hand.<br>Touch the world.</p><p class="intro-sub">小窓ではなく3D画面の光る手を見る。ボールに重ね、横へ払う。</p><div class="how-to"><div><b>01 / PALM</b><span>水色の手をボールへ。白い輪が出たら横へ払う。</span></div><div><b>02 / FINGER</b><span>人差し指を伸ばし、黄色い点でボールを横切る。</span></div></div><div class="intro-actions"><button id="start-front" class="primary" type="button">FRONT CAMERA <span aria-hidden="true">↗</span></button><button id="start-rear" type="button">REAR CAMERA</button><button id="mouse" type="button">TRY WITH MOUSE</button></div><p class="privacy">Camera processing stays on this device. No account required.</p><p id="notice" class="notice" role="status" aria-live="polite"></p></div></section>
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
const objectsToggle = element<HTMLButtonElement>('objects-toggle')
const cameraCard = element<HTMLElement>('camera-card')
const guideTitle = element<HTMLElement>('guide-title')
const guideDetail = element<HTMLElement>('guide-detail')
const feedback = element<HTMLElement>('gesture-feedback')
const switchMode = element<HTMLButtonElement>('switch-mode')
const flipCamera = element<HTMLButtonElement>('flip-camera')
const worldElement = element<HTMLElement>('world')
const flickDetector = new FlickDetector()
const screenContact = new ScreenContact()

let scene: SceneView
let physics: PhysicsWorld
let tracker: HandTracker | undefined
let mode: Mode = 'idle'
let handTarget: Vector3 | null = null
let smoothedTarget: Vector3 | null = null
let fingertipTarget: Vector3 | null = null
let aimedId: number | null = null
let smoothedFingertip: Vector3 | null = null
let handSeenAt = 0
let feedbackUntil = 0
let lastFrame = performance.now()
let accumulator = 0
let renderFrames = 0
let trackFrames = 0
let physicsTotal = 0
let physicsFrames = 0
let statsAt = performance.now()
let startGeneration = 0

function setStatus(message: string): void { status.textContent = message }

function clearHand(): void {
  handTarget = null
  smoothedTarget = null
  fingertipTarget = null
  smoothedFingertip = null
  flickDetector.reset()
  screenContact.reset()
  aimedId = null
  guideTitle.textContent = mode === 'camera' ? '手をカメラに映す' : 'ボールを狙う'
  guideDetail.textContent = mode === 'camera'
    ? '手全体を映し、3D画面に水色の手が現れるのを待つ。'
    : '水色の球をボールに重ね、横へ払う。'
  physics.setHandTarget(null)
  physics.setFingertipTarget(null)
  element<HTMLElement>('hands').textContent = '0'
}

function updateContact(palm: Vector3, finger: Vector3 | null, now: number): void {
  const contact = screenContact.sample(scene.worldToScreen(palm), finger ? scene.worldToScreen(finger) : null,
    scene.screenTargets(physics.getObjects()), now)
  aimedId = contact.aimedId
  if (contact.impact) {
    physics.queueScreenImpact(contact.impact)
    feedback.textContent = contact.impact.source === 'finger' ? 'FINGER HIT!' : 'PALM HIT!'
    feedback.classList.toggle('finger', contact.impact.source === 'finger')
    feedbackUntil = now + 700
  }
  guideTitle.textContent = aimedId === null ? 'ボールを狙う' : '白い輪が出たら横へ'
  guideDetail.textContent = aimedId === null
    ? mode === 'camera' ? '小窓ではなく3D画面の水色の手をボールに重ねる。'
      : '水色の球をボールに重ね、横へ払う。'
    : '手または黄色い指先を横へ動かしてボールを弾く。'
}

function showFlick(flick: Flick, now: number): void {
  physics.queueFlick(flick)
  scene.showFlick(flick, now)
  feedback.textContent = flick.source === 'finger' ? 'INDEX FLICK!' : 'PALM SWIPE!'
  feedback.classList.toggle('finger', flick.source === 'finger')
  feedbackUntil = now + 700
}

function syncCameraFacing(): void {
  if (!tracker) return
  const rear = tracker.facing === 'environment'
  element<HTMLElement>('camera-facing').textContent = rear ? 'REAR CAM' : 'FRONT CAM'
  element<HTMLElement>('preview-note').textContent = rear ? 'Natural view · on-device processing' : 'Mirror preview · on-device processing'
  tracker.video.classList.toggle('mirrored', !rear)
  flipCamera.textContent = rear ? 'USE FRONT CAMERA' : 'USE REAR CAMERA'
}

function syncObjectControls(): void {
  const count = physics.objectCount
  element<HTMLElement>('object-count').textContent = String(count)
  element<HTMLElement>('objects').textContent = String(count)
  for (const button of document.querySelectorAll<HTMLButtonElement>('[data-add]')) {
    button.disabled = count >= physics.maxObjects
  }
  element<HTMLButtonElement>('clear').disabled = count === 0
}

function activate(next: Mode): void {
  if (next === 'mouse') startGeneration++
  mode = next
  intro.hidden = true
  controls.hidden = false
  controls.classList.toggle('compact', window.matchMedia('(max-width: 700px)').matches)
  objectsToggle.setAttribute('aria-expanded', String(!controls.classList.contains('compact')))
  objectsToggle.setAttribute('aria-label', controls.classList.contains('compact') ? 'Show object controls' : 'Hide object controls')
  objectsToggle.textContent = controls.classList.contains('compact') ? 'EDIT' : 'CLOSE'
  cameraCard.hidden = next !== 'camera'
  modeLabel.textContent = next === 'camera' ? 'CAMERA CONNECTED' : 'MOUSE MODE'
  guideTitle.textContent = 'ボールを狙う'
  guideDetail.textContent = next === 'camera'
    ? '小窓ではなく3D画面の水色の手をボールに重ねる。'
    : '水色の球をボールに重ね、横へ払う。'
  switchMode.textContent = next === 'camera' ? 'USE MOUSE' : 'USE CAMERA'
  if (next === 'mouse') {
    tracker?.stop()
    tracker = undefined
    clearHand()
    setStatus('MOUSE MODE · MOVE POINTER TO TOUCH')
  } else {
    clearHand()
    syncCameraFacing()
    setStatus('CAMERA READY · SHOW YOUR HAND')
  }
  syncObjectControls()
}

async function startCamera(facing: CameraFacing): Promise<void> {
  if (!physics || mode === 'camera') return
  const generation = ++startGeneration
  element<HTMLButtonElement>('start-front').disabled = true
  element<HTMLButtonElement>('start-rear').disabled = true
  notice.textContent = 'Waiting for camera…'
  tracker?.stop()
  const pendingTracker = new HandTracker()
  tracker = pendingTracker
  try {
    await pendingTracker.start(message => { if (generation === startGeneration) { notice.textContent = message; setStatus(message.toUpperCase()) } }, facing)
    if (generation !== startGeneration) { pendingTracker.stop(); return }
    const preview = element<HTMLElement>('video-wrap')
    preview.replaceChildren(pendingTracker.video)
    activate('camera')
  } catch (error) {
    pendingTracker.stop()
    if (generation !== startGeneration) return
    tracker = undefined
    const errorName = error instanceof Error ? error.name : ''
    const message = errorName === 'NotAllowedError'
      ? 'Camera permission was denied. You can still play with your mouse.'
      : facing === 'environment' && (errorName === 'OverconstrainedError' || errorName === 'NotFoundError')
        ? 'Rear camera was not found. Try Front Camera or Mouse Mode.'
        : `Camera could not start. ${error instanceof Error && error.message ? error.message : 'Try another camera or Mouse Mode.'}`
    notice.textContent = message
    setStatus('CAMERA UNAVAILABLE · MOUSE MODE READY')
  } finally {
    element<HTMLButtonElement>('start-front').disabled = false
    element<HTMLButtonElement>('start-rear').disabled = false
  }
}

function startMouse(): void { activate('mouse') }

element<HTMLButtonElement>('start-front').addEventListener('click', () => void startCamera('user'))
element<HTMLButtonElement>('start-rear').addEventListener('click', () => void startCamera('environment'))
element<HTMLButtonElement>('mouse').addEventListener('click', startMouse)
objectsToggle.addEventListener('click', () => {
  controls.classList.toggle('compact')
  const expanded = !controls.classList.contains('compact')
  objectsToggle.setAttribute('aria-expanded', String(expanded))
  objectsToggle.setAttribute('aria-label', expanded ? 'Hide object controls' : 'Show object controls')
  objectsToggle.textContent = expanded ? 'CLOSE' : 'EDIT'
})
flipCamera.addEventListener('click', async () => {
  const activeTracker = tracker
  if (!activeTracker || mode !== 'camera') return
  const generation = ++startGeneration
  const target: CameraFacing = activeTracker.facing === 'user' ? 'environment' : 'user'
  flipCamera.disabled = true
  handLabel.textContent = 'SWITCHING'
  clearHand()
  try {
    const switched = await activeTracker.switchFacing(target, message => {
      if (generation === startGeneration) setStatus(message.toUpperCase())
    })
    if (generation !== startGeneration || tracker !== activeTracker || mode !== 'camera') return
    syncCameraFacing()
    handLabel.textContent = 'SEARCHING'
    setStatus(switched ? `${target === 'environment' ? 'REAR' : 'FRONT'} CAMERA READY · SHOW YOUR HAND`
      : `${target === 'environment' ? 'REAR' : 'FRONT'} CAMERA UNAVAILABLE · PREVIOUS CAMERA RESTORED`)
  } catch (error) {
    if (generation !== startGeneration || tracker !== activeTracker || mode !== 'camera') return
    startMouse()
    setStatus(`CAMERA SWITCH FAILED · ${error instanceof Error ? error.message : 'TRY MOUSE MODE'}`)
  } finally {
    flipCamera.disabled = false
  }
})
for (const button of document.querySelectorAll<HTMLButtonElement>('[data-add]')) {
  button.addEventListener('click', () => {
    const kind = button.dataset.add as ObjectKind
    if (physics.addObject(kind)) {
      syncObjectControls()
      setStatus(`${kind.toUpperCase()} ADDED · ${physics.objectCount} ${physics.objectCount === 1 ? 'OBJECT' : 'OBJECTS'}`)
    }
  })
}
element<HTMLButtonElement>('reset').addEventListener('click', () => {
  physics.resetObjects()
  syncObjectControls()
  setStatus('20 BALLS RESTORED')
})
element<HTMLButtonElement>('load-100').addEventListener('click', () => {
  physics.loadHundred()
  syncObjectControls()
  setStatus('100 OBJECTS LOADED · SWEEP TO PUSH')
})
element<HTMLButtonElement>('clear').addEventListener('click', () => {
  physics.clearObjects()
  syncObjectControls()
  setStatus('WORLD CLEARED · ADD AN OBJECT')
})
switchMode.addEventListener('click', () => {
  if (mode === 'camera') startMouse()
  else {
    intro.hidden = false
    notice.textContent = ''
    setStatus('CHOOSE FRONT OR REAR CAMERA')
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
  const point = { x: (event.clientX - bounds.left) / bounds.width, y: (event.clientY - bounds.top) / bounds.height }
  handTarget = scene.screenToWorld(point.x, point.y)
  const now = performance.now()
  const flick = flickDetector.sample(handTarget, null, now)
  if (flick) showFlick(flick, now)
})
worldElement.addEventListener('pointerleave', () => {
  if (mode === 'mouse') clearHand()
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
          const palm = { x: imageXToScreen(state.x, tracker.facing), y: state.y }
          const finger = state.indexTip
            ? { x: imageXToScreen(state.indexTip.x, tracker.facing), y: state.indexTip.y }
            : null
          handTarget = scene.screenToWorld(palm.x, palm.y)
          fingertipTarget = state.indexTip
            ? scene.screenToWorld(finger!.x, finger!.y)
            : null
          const flick = flickDetector.sample(handTarget, fingertipTarget, now)
          if (flick) showFlick(flick, now)
          handSeenAt = now
          handLabel.textContent = 'HAND FOUND'
          setStatus(`${state.handedness.toUpperCase() || 'HAND'} TRACKED · SWEEP OR FLICK`)
        } else if (now - handSeenAt > 180) {
          clearHand()
          handLabel.textContent = 'SEARCHING'
          setStatus('SHOW ONE HAND TO THE CAMERA')
        }
      }
    } catch (error) {
      startMouse()
      setStatus('TRACKING STOPPED · MOVE POINTER TO PLAY')
      console.error('Hand tracking stopped:', error)
    }
  }
  if (mode === 'camera' && handTarget && now - handSeenAt > 400) {
    clearHand()
    handLabel.textContent = 'SEARCHING'
    setStatus('SHOW ONE HAND TO THE CAMERA')
  }

  if (handTarget) {
    if (!smoothedTarget) smoothedTarget = handTarget.clone()
    else smoothedTarget.lerp(handTarget, 1 - Math.exp(-dt * 18))
    physics.setHandTarget(smoothedTarget)
    if (fingertipTarget) {
      if (!smoothedFingertip) smoothedFingertip = fingertipTarget.clone()
      else smoothedFingertip.lerp(fingertipTarget, 1 - Math.exp(-dt * 22))
      physics.setFingertipTarget(smoothedFingertip)
    } else {
      smoothedFingertip = null
      physics.setFingertipTarget(null)
    }
  } else if (mode !== 'idle') {
    physics.setHandTarget(null)
    physics.setFingertipTarget(null)
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
  const visibleHand = physics.getHandPosition()
  const visibleFinger = physics.getFingertipPosition()
  if (visibleHand) updateContact(visibleHand, visibleFinger, now)
  scene.update(physics.getObjects(), visibleHand, visibleFinger, aimedId, now)
  if (feedback.textContent && now > feedbackUntil) feedback.textContent = ''
  renderFrames++

  if (now - statsAt >= 1000) {
    const seconds = (now - statsAt) / 1000
    element<HTMLElement>('render-fps').textContent = String(Math.round(renderFrames / seconds))
    element<HTMLElement>('track-fps').textContent = mode === 'camera' ? String(Math.round(trackFrames / seconds)) : '—'
    element<HTMLElement>('physics-time').textContent = physicsFrames ? (physicsTotal / physicsFrames).toFixed(1) : '—'
    element<HTMLElement>('objects').textContent = String(physics.objectCount)
    renderFrames = 0; trackFrames = 0; physicsTotal = 0; physicsFrames = 0; statsAt = now
  }
}

async function boot(): Promise<void> {
  try {
    scene = new SceneView(worldElement)
    setStatus('INITIALIZING PHYSICS')
    physics = new PhysicsWorld()
    await physics.init()
    syncObjectControls()
    setStatus('WORLD READY · PRESS START')
    requestAnimationFrame(frame)
  } catch (error) {
    notice.textContent = `This browser cannot start the 3D world. ${error instanceof Error ? error.message : ''}`
    setStatus('WORLD UNAVAILABLE')
    element<HTMLButtonElement>('start-front').disabled = true
    element<HTMLButtonElement>('start-rear').disabled = true
    element<HTMLButtonElement>('mouse').disabled = true
  }
}

void boot()
