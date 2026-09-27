import { Vector3 } from 'three'
import { CatchGame } from './game/CatchGame'
import { PhysicsWorld, type ObjectKind } from './physics/PhysicsWorld'
import { SceneView } from './rendering/SceneView'
import { imageXToScreen, type CameraFacing } from './vision/CameraFacing'
import { FlickDetector, type Flick } from './vision/FlickDetector'
import { HandTracker } from './vision/HandTracker'
import { ScreenContact } from './vision/ScreenContact'
import { SpatialHand } from './vision/SpatialHand'
import './style.css'

type Mode = 'idle' | 'camera' | 'mouse'
type Activity = 'sandbox' | 'catch'

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
      <button class="play-catch" id="play-catch" type="button" hidden>PLAY BALL CATCH <span aria-hidden="true">↗</span></button>
      <section class="catch-hud" id="catch-hud" aria-label="Ball Catch game" hidden>
        <div class="catch-heading">BALL CATCH <span>12 BALL ROUND</span></div>
        <div class="catch-stats"><div><strong id="catch-score">0</strong><span>CAUGHT</span></div><div><strong id="catch-miss">0</strong><span>MISSED</span></div><div><strong id="catch-left">12</strong><span>LEFT</span></div></div>
        <p class="catch-pose" id="catch-pose">手の位置を確認中</p>
        <p class="catch-message" id="catch-message" role="status">手のひらを映すと開始します</p>
      </section>
      <div class="catch-actions" id="catch-actions" hidden><button id="catch-retry" type="button">RETRY</button><button id="catch-recenter" type="button">RECENTER DEPTH</button><button id="catch-exit" type="button">SANDBOX</button></div>
      <div class="sandbox-controls" id="bottom-controls" hidden>
        <div class="sandbox-heading"><span>BUILD YOUR WORLD</span><strong><span id="object-count">20</span> / 100 OBJECTS</strong><button id="objects-toggle" type="button" aria-expanded="false" aria-label="Show object controls">EDIT</button></div>
        <div class="sandbox-actions" aria-label="Add objects"><button data-add="ball" type="button">+ BALL</button><button data-add="box" type="button">+ BOX</button><button data-add="domino" type="button">+ DOMINO</button></div>
        <div class="sandbox-actions sandbox-secondary"><button id="reset" type="button">RESET 20</button><button id="load-100" type="button">LOAD 100</button><button id="clear" type="button">CLEAR ALL</button><button id="switch-mode" type="button">USE MOUSE</button></div>
      </div>
      <section class="intro" id="intro" aria-labelledby="intro-title"><div class="intro-inner"><p class="eyebrow">INTERACTIVE PHYSICS PLAYGROUND</p><h1 id="intro-title">REALITY<br><em>SANDBOX</em></h1><p class="intro-line">Move your hand.<br>Touch the world.</p><p class="intro-sub">カメラを選んだら PLAY BALL CATCH。手のひらをカメラへ向け、奥から飛んでくるボールを受け止めよう。</p><div class="how-to"><div><b>01 / BALL CATCH</b><span>画面奥から迫るボールに手のひらを重ねる。指の操作は不要。</span></div><div><b>02 / SANDBOX</b><span>ボールを手で押したり、指先で弾いたりして自由に遊べる。</span></div></div><div class="intro-actions"><button id="start-front" class="primary" type="button">FRONT CAMERA <span aria-hidden="true">↗</span></button><button id="start-rear" type="button">REAR CAMERA</button><button id="mouse" type="button">TRY WITH MOUSE</button></div><p class="privacy">Camera processing stays on this device. No account required.</p><p id="notice" class="notice" role="status" aria-live="polite"></p></div></section>
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
const playCatch = element<HTMLButtonElement>('play-catch')
const catchHud = element<HTMLElement>('catch-hud')
const catchActions = element<HTMLElement>('catch-actions')
const catchMessage = element<HTMLElement>('catch-message')
const catchPose = element<HTMLElement>('catch-pose')
const catchRecenter = element<HTMLButtonElement>('catch-recenter')
const catchScore = element<HTMLElement>('catch-score')
const catchMiss = element<HTMLElement>('catch-miss')
const catchLeft = element<HTMLElement>('catch-left')
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
const spatialHand = new SpatialHand()

let scene: SceneView
let physics: PhysicsWorld
let tracker: HandTracker | undefined
let mode: Mode = 'idle'
let activity: Activity = 'sandbox'
let catchGame: CatchGame
let handTarget: Vector3 | null = null
let poseTarget: Vector3[] | null = null
let smoothedPose: Vector3[] | null = null
let handNormal = new Vector3(0, 0.35, 0.94)
let handDepth = 0
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

function setStatus(message: string): void { writeText(status, message) }
function writeText(target: HTMLElement, value: string): void {
  if (target.textContent !== value) target.textContent = value
}

function clearHand(): void {
  handTarget = null
  smoothedTarget = null
  poseTarget = null
  smoothedPose = null
  handDepth = 0
  fingertipTarget = null
  smoothedFingertip = null
  flickDetector.reset()
  screenContact.reset()
  aimedId = null
  guideTitle.textContent = activity === 'catch' ? mode === 'camera' ? '手のひらを映す' : 'ポインターを動かす'
    : mode === 'camera' ? '手をカメラに映す' : 'ボールを狙う'
  guideDetail.textContent = activity === 'catch' ? mode === 'camera'
    ? '手のひらをカメラへ向け、光る輪の前で迫るボールをキャッチ。'
    : '光る輪の前へ水色の球を動かし、迫るボールをキャッチ。'
    : mode === 'camera'
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
    feedback.classList.remove('caught', 'missed')
    feedback.classList.toggle('finger', contact.impact.source === 'finger')
    feedbackUntil = now + 700
  }
  writeText(guideTitle, aimedId === null ? 'ボールを狙う' : '白い輪が出たら横へ')
  writeText(guideDetail, aimedId === null
    ? mode === 'camera' ? '小窓ではなく3D画面の水色の手をボールに重ねる。'
      : '水色の球をボールに重ね、横へ払う。'
    : '手または黄色い指先を横へ動かしてボールを弾く。')
}

function showFlick(flick: Flick, now: number): void {
  physics.queueFlick(flick)
  scene.showFlick(flick, now)
  feedback.textContent = flick.source === 'finger' ? 'INDEX FLICK!' : 'PALM SWIPE!'
  feedback.classList.remove('caught', 'missed')
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
  controls.hidden = activity === 'catch'
  playCatch.hidden = activity === 'catch'
  controls.classList.toggle('compact', window.matchMedia('(max-width: 700px)').matches)
  objectsToggle.setAttribute('aria-expanded', String(!controls.classList.contains('compact')))
  objectsToggle.setAttribute('aria-label', controls.classList.contains('compact') ? 'Show object controls' : 'Hide object controls')
  objectsToggle.textContent = controls.classList.contains('compact') ? 'EDIT' : 'CLOSE'
  cameraCard.hidden = next !== 'camera'
  catchRecenter.hidden = next !== 'camera'
  modeLabel.textContent = activity === 'catch' ? 'BALL CATCH' : next === 'camera' ? 'CAMERA CONNECTED' : 'MOUSE MODE'
  guideTitle.textContent = activity === 'catch' ? '手のひらでキャッチ' : 'ボールを狙う'
  guideDetail.textContent = activity === 'catch' ? '手のひらをカメラへ向け、奥から迫るボールに重ねる。'
    : next === 'camera'
    ? '小窓ではなく3D画面の水色の手をボールに重ねる。'
    : '水色の球をボールに重ね、横へ払う。'
  switchMode.textContent = next === 'camera' ? 'USE MOUSE' : 'USE CAMERA'
  if (next === 'mouse') {
    tracker?.stop()
    tracker = undefined
    spatialHand.recenter()
    clearHand()
    setStatus('MOUSE MODE · MOVE POINTER TO TOUCH')
  } else {
    spatialHand.recenter()
    clearHand()
    syncCameraFacing()
    setStatus('CAMERA READY · SHOW YOUR HAND')
  }
  syncObjectControls()
}

function syncCatchHud(): void {
  if (activity !== 'catch') return
  writeText(catchScore, String(catchGame.catches))
  writeText(catchMiss, String(catchGame.misses))
  writeText(catchLeft, String(catchGame.remaining))
  writeText(catchPose, !handTarget ? '手の位置を確認中'
    : mode === 'mouse' ? '手のひら: ポインター位置'
      : `奥行き: ${handDepth > 0.55 ? '近い' : handDepth < -0.55 ? '遠い' : '中央'} · 向き: ${handNormal.z > 0.65 ? 'カメラ向き' : handNormal.z > 0.4 ? '斜め' : '横向き'}`)
  let message = catchGame.phase === 'finished' ? `${catchGame.catches} / ${catchGame.total} キャッチ！ RETRY で再挑戦`
    : !handTarget ? mode === 'camera' ? '手のひらを映してください · 一時停止中' : '画面の中でポインターを動かしてください'
      : catchGame.phase === 'ready' ? '手のひらをカメラへ。最初は中央の輪へ'
      : catchGame.phase === 'countdown' ? `${catchGame.countdownSeconds} 秒後にスタート · 最初は中央`
        : '奥から迫るボールを手のひらで受け止める'
  if (catchGame.phase === 'running' && mode === 'camera' && handTarget) {
    if (Math.abs(handDepth) > 0.88) message = '奥行きを中央へ。必要なら RECENTER DEPTH'
    else if (handNormal.z < 0.4) message = '手のひらをカメラへ向けると受け止めやすい'
  }
  writeText(catchMessage, message)
}

function enterCatch(): void {
  if (mode === 'idle') return
  activity = 'catch'
  worldElement.parentElement?.classList.add('catch-active')
  catchGame.reset(Math.abs(scene.screenToWorld(0.79, 0.5).x))
  feedback.textContent = ''
  feedback.classList.remove('caught', 'missed', 'finger')
  controls.hidden = true
  playCatch.hidden = true
  catchHud.hidden = false
  catchActions.hidden = false
  catchRecenter.hidden = mode !== 'camera'
  modeLabel.textContent = 'BALL CATCH'
  physics.setFingertipTarget(null)
  fingertipTarget = null
  smoothedFingertip = null
  aimedId = null
  screenContact.reset()
  guideTitle.textContent = '手のひらでキャッチ'
  guideDetail.textContent = 'カメラへ手のひらを向け、奥から迫るボールに重ねる。指の操作は不要。'
  setStatus(mode === 'camera' ? 'BALL CATCH · SHOW YOUR PALM' : 'BALL CATCH · MOVE POINTER INTO WORLD')
  syncCatchHud()
}

function exitCatch(): void {
  activity = 'sandbox'
  worldElement.parentElement?.classList.remove('catch-active')
  physics.resetObjects()
  scene.setCatchCue(null)
  catchHud.hidden = true
  catchActions.hidden = true
  controls.hidden = false
  playCatch.hidden = false
  modeLabel.textContent = mode === 'camera' ? 'CAMERA CONNECTED' : 'MOUSE MODE'
  guideTitle.textContent = 'ボールを狙う'
  guideDetail.textContent = '水色の手をボールに重ね、横へ払う。'
  syncObjectControls()
  setStatus('SANDBOX READY')
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
playCatch.addEventListener('click', enterCatch)
element<HTMLButtonElement>('catch-retry').addEventListener('click', () => {
  catchGame.reset(Math.abs(scene.screenToWorld(0.79, 0.5).x))
  feedback.textContent = ''
  setStatus(mode === 'camera' ? 'NEW ROUND · SHOW YOUR PALM' : 'NEW ROUND · MOVE POINTER INTO WORLD')
  syncCatchHud()
})
element<HTMLButtonElement>('catch-recenter').addEventListener('click', () => {
  spatialHand.recenter()
  setStatus('HAND DEPTH RECENTERED')
})
element<HTMLButtonElement>('catch-exit').addEventListener('click', exitCatch)
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
    spatialHand.recenter()
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
  if (activity === 'sandbox') {
    const flick = flickDetector.sample(handTarget, null, now)
    if (flick) showFlick(flick, now)
  }
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
        writeText(element<HTMLElement>('hands'), state.detected ? '1' : '0')
        if (state.detected) {
          const palm = { x: imageXToScreen(state.x, tracker.facing), y: state.y }
          const finger = activity === 'sandbox' && state.indexTip
            ? { x: imageXToScreen(state.indexTip.x, tracker.facing), y: state.indexTip.y }
            : null
          const spatial = spatialHand.sample(state, tracker.facing, dt)
          handTarget = scene.screenToWorld(palm.x, palm.y, spatial.depth)
          handDepth = spatial.depth
          poseTarget = spatial.points
          handNormal.lerp(spatial.normal, 1 - Math.exp(-dt * 12)).normalize()
          fingertipTarget = activity === 'sandbox' && state.indexTip
            ? scene.screenToWorld(finger!.x, finger!.y)
            : null
          if (activity === 'sandbox') {
            const flick = flickDetector.sample(handTarget, fingertipTarget, now)
            if (flick) showFlick(flick, now)
          }
          handSeenAt = now
          writeText(handLabel, 'HAND FOUND')
          setStatus(activity === 'catch' ? `${state.handedness.toUpperCase() || 'HAND'} TRACKED · CATCH THE BALL`
            : `${state.handedness.toUpperCase() || 'HAND'} TRACKED · SWEEP OR FLICK`)
        } else if (activity === 'catch' || now - handSeenAt > 180) {
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
  if (mode === 'camera' && handTarget && now - handSeenAt > (activity === 'catch' ? 140 : 400)) {
    clearHand()
    handLabel.textContent = 'SEARCHING'
    setStatus('SHOW ONE HAND TO THE CAMERA')
  }

  if (handTarget) {
    if (!smoothedTarget) smoothedTarget = handTarget.clone()
    else smoothedTarget.lerp(handTarget, 1 - Math.exp(-dt * 18))
    physics.setHandTarget(smoothedTarget)
    if (poseTarget) {
      if (!smoothedPose) smoothedPose = poseTarget.map(point => point.clone())
      else for (let i = 0; i < poseTarget.length; i++) smoothedPose[i].lerp(poseTarget[i], 1 - Math.exp(-dt * 16))
    } else smoothedPose = null
    if (activity === 'sandbox' && fingertipTarget) {
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

  accumulator += activity === 'catch' && !handTarget ? 0 : dt
  let steps = 0
  while (accumulator >= physics.timestep && steps < 3) {
    physicsTotal += physics.step()
    physicsFrames++
    if (activity === 'catch') {
      const event = catchGame.update(physics.timestep, physics.getHandPosition(), handNormal, physics.getObjects())
      if (event === 'caught') {
        feedback.textContent = 'CATCH! +1'
        feedback.classList.remove('finger', 'missed')
        feedback.classList.add('caught')
        const hand = physics.getHandPosition()
        if (hand) scene.showCatch(hand, now)
        feedbackUntil = now + 850
      } else if (event === 'missed') {
        feedback.textContent = 'MISSED'
        feedback.classList.remove('finger', 'caught')
        feedback.classList.add('missed')
        feedbackUntil = now + 850
      } else if (event === 'finished') {
        feedback.textContent = `ROUND COMPLETE · ${catchGame.catches} / ${catchGame.total}`
        feedback.classList.remove('finger', 'missed', 'caught')
        feedbackUntil = now + 2200
        setStatus('ROUND COMPLETE · RETRY OR SANDBOX')
      }
    }
    accumulator -= physics.timestep
    steps++
  }
  if (steps === 3) accumulator = 0
  const visibleHand = physics.getHandPosition()
  const visibleFinger = physics.getFingertipPosition()
  if (activity === 'sandbox' && visibleHand) updateContact(visibleHand, visibleFinger, now)
  if (activity === 'catch') {
    scene.setCatchCue(catchGame.cueX)
    syncCatchHud()
  }
  scene.update(physics.getObjects(), visibleHand, activity === 'sandbox' ? visibleFinger : null,
    activity === 'sandbox' ? aimedId : null, now, smoothedPose)
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
    catchGame = new CatchGame(physics)
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
