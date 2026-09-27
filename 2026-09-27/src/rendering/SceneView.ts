import * as THREE from 'three'
import type { ObjectKind, ObjectSnapshot } from '../physics/PhysicsWorld'
import type { Flick } from '../vision/FlickDetector'
import type { ScreenPoint, ScreenTarget } from '../vision/ScreenContact'

const handBones = [0,1,1,2,2,3,3,4,0,5,5,6,6,7,7,8,5,9,9,10,10,11,11,12,
  9,13,13,14,14,15,15,16,13,17,17,18,18,19,19,20,0,17,5,17,0,9]

export class SceneView {
  readonly canvas: HTMLCanvasElement
  private renderer: THREE.WebGLRenderer
  private scene = new THREE.Scene()
  private camera = new THREE.PerspectiveCamera(48, 1, 0.1, 100)
  private raycaster = new THREE.Raycaster()
  private plane = new THREE.Plane(new THREE.Vector3(0, 0, 1), 0)
  private hand: THREE.Group
  private palmProxy: THREE.Group
  private poseRoot = new THREE.Group()
  private poseLines: THREE.LineSegments
  private poseDots: THREE.Mesh[] = []
  private poseBones: THREE.Mesh[] = []
  private palmSurface: THREE.Mesh
  private finger = new THREE.Group()
  private flickRing = new THREE.Mesh(
    new THREE.RingGeometry(0.24, 0.32, 40),
    new THREE.MeshBasicMaterial({ color: '#a6fff1', transparent: true, opacity: 0, side: THREE.DoubleSide, depthWrite: false }),
  )
  private flickAt = -Infinity
  private targetRing = new THREE.Mesh(
    new THREE.TorusGeometry(1, 0.035, 8, 48),
    new THREE.MeshBasicMaterial({ color: '#e7fff9', transparent: true, opacity: 0.86, depthTest: false }),
  )
  private catchCue = new THREE.Group()
  private objects = new Map<number, THREE.Mesh>()
  private sphereGeometry = new THREE.SphereGeometry(1, 24, 16)
  private boxGeometry = new THREE.BoxGeometry(1, 1, 1)
  private ballMaterials = ['#ff8b69', '#ffc774', '#86c8ff', '#e8a0ff', '#8ff0d5'].map(color =>
    new THREE.MeshStandardMaterial({ color, emissive: color, emissiveIntensity: 0.25, metalness: 0.2, roughness: 0.26 }))
  private materials: Record<ObjectKind, THREE.MeshStandardMaterial> = {
    ball: new THREE.MeshStandardMaterial({ color: '#86c8ff', emissive: '#56adff', emissiveIntensity: 0.25, metalness: 0.2, roughness: 0.26 }),
    box: new THREE.MeshStandardMaterial({ color: '#ffbd83', emissive: '#e9864d', emissiveIntensity: 0.2, metalness: 0.18, roughness: 0.4 }),
    domino: new THREE.MeshStandardMaterial({ color: '#c7abff', emissive: '#915cff', emissiveIntensity: 0.27, metalness: 0.24, roughness: 0.3 }),
    catch: new THREE.MeshStandardMaterial({ color: '#ffdc79', emissive: '#ff9d36', emissiveIntensity: 0.75, metalness: 0.18, roughness: 0.24 }),
  }
  private resizeObserver: ResizeObserver

  constructor(host: HTMLElement) {
    this.renderer = new THREE.WebGLRenderer({ antialias: true, alpha: false, powerPreference: 'high-performance' })
    this.renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2))
    this.renderer.outputColorSpace = THREE.SRGBColorSpace
    this.renderer.toneMapping = THREE.ACESFilmicToneMapping
    this.renderer.toneMappingExposure = 1.55
    this.canvas = this.renderer.domElement
    this.canvas.setAttribute('aria-label', 'Interactive 3D physics world')
    host.appendChild(this.canvas)

    this.scene.background = new THREE.Color('#080e18')
    this.scene.fog = new THREE.Fog('#080e18', 13, 24)
    this.camera.position.set(0, 3.5, 10.5)
    this.camera.lookAt(0, 1.35, 0)
    this.camera.updateMatrixWorld()
    this.scene.add(new THREE.HemisphereLight('#91bce5', '#132844', 2.1))
    const key = new THREE.DirectionalLight('#d5f5ff', 3.4)
    key.position.set(-2, 7, 7)
    this.scene.add(key)
    const rim = new THREE.PointLight('#26d9e7', 80, 15)
    rim.position.set(3, 3, -3)
    this.scene.add(rim)

    const floor = new THREE.Mesh(
      new THREE.PlaneGeometry(12, 6),
      new THREE.MeshStandardMaterial({ color: '#101e2e', roughness: 0.6, metalness: 0.16 }),
    )
    floor.rotation.x = -Math.PI / 2
    floor.position.y = -0.04
    this.scene.add(floor)
    const grid = new THREE.GridHelper(12, 24, '#25516a', '#183344')
    grid.position.y = -0.025
    this.scene.add(grid)
    const back = new THREE.Mesh(
      new THREE.PlaneGeometry(15, 9),
      new THREE.MeshBasicMaterial({ color: '#0c1726' }),
    )
    back.position.z = -3.1
    this.scene.add(back)

    this.hand = this.createHand()
    this.scene.add(this.hand)
    this.hand.visible = false
    this.palmProxy = this.hand.children[0] as THREE.Group
    const lineGeometry = new THREE.BufferGeometry()
    lineGeometry.setAttribute('position', new THREE.BufferAttribute(new Float32Array(handBones.length * 3), 3))
    this.poseLines = new THREE.LineSegments(lineGeometry,
      new THREE.LineBasicMaterial({ color: '#b9fff4', transparent: true, opacity: 0.86, depthTest: false }))
    this.poseRoot.add(this.poseLines)
    const palmGeometry = new THREE.BufferGeometry()
    palmGeometry.setAttribute('position', new THREE.BufferAttribute(new Float32Array(9 * 3), 3))
    this.palmSurface = new THREE.Mesh(palmGeometry,
      new THREE.MeshBasicMaterial({ color: '#40dccb', transparent: true, opacity: 0.36,
        side: THREE.DoubleSide, depthWrite: false, depthTest: false }))
    this.poseRoot.add(this.palmSurface)
    const boneGeometry = new THREE.CylinderGeometry(0.055, 0.07, 1, 8)
    const boneMaterial = new THREE.MeshPhysicalMaterial({ color: '#74eedf', emissive: '#24bfae',
      emissiveIntensity: 0.45, transparent: true, opacity: 0.62, depthWrite: false })
    for (let i = 0; i < handBones.length; i += 2) {
      const bone = new THREE.Mesh(boneGeometry, boneMaterial)
      this.poseBones.push(bone)
      this.poseRoot.add(bone)
    }
    const jointGeometry = new THREE.SphereGeometry(0.045, 8, 6)
    const jointMaterial = new THREE.MeshBasicMaterial({ color: '#d8fff6', transparent: true, opacity: 0.9, depthTest: false })
    for (let i = 0; i < 21; i++) {
      const dot = new THREE.Mesh(jointGeometry, jointMaterial)
      this.poseDots.push(dot)
      this.poseRoot.add(dot)
    }
    this.hand.add(this.poseRoot)
    this.poseRoot.visible = false
    this.finger.add(new THREE.Mesh(
      new THREE.SphereGeometry(0.16, 16, 12),
      new THREE.MeshBasicMaterial({ color: '#fff3c0', transparent: true, opacity: 0.9 }),
    ))
    this.finger.add(new THREE.Mesh(
      new THREE.TorusGeometry(0.23, 0.018, 8, 32),
      new THREE.MeshBasicMaterial({ color: '#ffe19a' }),
    ))
    this.finger.visible = false
    this.scene.add(this.finger)
    this.flickRing.visible = false
    this.scene.add(this.flickRing)
    this.targetRing.visible = false
    this.scene.add(this.targetRing)
    const cueLine = new THREE.Line(
      new THREE.BufferGeometry().setFromPoints([new THREE.Vector3(0, 0.38, 0), new THREE.Vector3(0, 4.2, 0)]),
      new THREE.LineBasicMaterial({ color: '#ffd880', transparent: true, opacity: 0.48 }),
    )
    this.catchCue.add(cueLine)
    const cueRing = new THREE.Mesh(new THREE.TorusGeometry(0.36, 0.025, 6, 40),
      new THREE.MeshBasicMaterial({ color: '#ffe69c', transparent: true, opacity: 0.82, depthTest: false }))
    cueRing.position.y = 1.35
    this.catchCue.add(cueRing)
    this.catchCue.visible = false
    this.scene.add(this.catchCue)
    this.resizeObserver = new ResizeObserver(() => this.resize(host))
    this.resizeObserver.observe(host)
    this.resize(host)
  }

  private createHand(): THREE.Group {
    const group = new THREE.Group()
    const proxy = new THREE.Group()
    const core = new THREE.Mesh(
      new THREE.SphereGeometry(0.47, 28, 18),
      new THREE.MeshPhysicalMaterial({ color: '#66f2e0', emissive: '#20ddc6', emissiveIntensity: 0.7, transparent: true, opacity: 0.62, roughness: 0.15, metalness: 0.18, depthWrite: false }),
    )
    proxy.add(core)
    const ring = new THREE.Mesh(
      new THREE.TorusGeometry(0.55, 0.022, 8, 64),
      new THREE.MeshBasicMaterial({ color: '#a6fff1' }),
    )
    proxy.add(ring)
    const inner = new THREE.Mesh(
      new THREE.SphereGeometry(0.08, 12, 8),
      new THREE.MeshBasicMaterial({ color: '#e8fffa' }),
    )
    proxy.add(inner)
    group.add(proxy)
    return group
  }

  private resize(host: HTMLElement): void {
    const width = Math.max(1, host.clientWidth)
    const height = Math.max(1, host.clientHeight)
    this.camera.aspect = width / height
    this.camera.updateProjectionMatrix()
    this.renderer.setSize(width, height, false)
  }

  screenToWorld(x: number, y: number, depth = 0): THREE.Vector3 {
    this.raycaster.setFromCamera(new THREE.Vector2(x * 2 - 1, 1 - y * 2), this.camera)
    this.plane.constant = -depth
    const result = new THREE.Vector3()
    this.raycaster.ray.intersectPlane(this.plane, result)
    return result.set(THREE.MathUtils.clamp(result.x, -5.2, 5.2), THREE.MathUtils.clamp(result.y, 0.27, 4.3), depth)
  }

  private updatePose(points: THREE.Vector3[] | null): void {
    this.palmProxy.visible = !points
    this.poseRoot.visible = Boolean(points)
    if (!points || points.length < 21) return
    const line = this.poseLines.geometry.getAttribute('position') as THREE.BufferAttribute
    const up = new THREE.Vector3(0, 1, 0)
    for (let i = 0; i < handBones.length; i++) {
      const point = points[handBones[i]]
      line.setXYZ(i, point.x, point.y, point.z)
    }
    for (let i = 0; i < this.poseBones.length; i++) {
      const a = points[handBones[i * 2]]
      const b = points[handBones[i * 2 + 1]]
      const bone = this.poseBones[i]
      const delta = b.clone().sub(a)
      bone.position.copy(a).add(b).multiplyScalar(0.5)
      bone.scale.set(1, Math.max(0.001, delta.length()), 1)
      bone.quaternion.setFromUnitVectors(up, delta.normalize())
    }
    line.needsUpdate = true
    this.poseLines.geometry.computeBoundingSphere()
    for (let i = 0; i < 21; i++) this.poseDots[i].position.copy(points[i])
    const vertices = [0,5,9,0,9,13,0,13,17]
    const surface = this.palmSurface.geometry.getAttribute('position') as THREE.BufferAttribute
    for (let i = 0; i < vertices.length; i++) {
      const point = points[vertices[i]]
      surface.setXYZ(i, point.x, point.y, point.z)
    }
    surface.needsUpdate = true
    this.palmSurface.geometry.computeBoundingSphere()
  }

  worldToScreen(point: THREE.Vector3): ScreenPoint {
    const projected = point.clone().project(this.camera)
    return {
      x: (projected.x + 1) * this.canvas.clientWidth / 2,
      y: (1 - projected.y) * this.canvas.clientHeight / 2,
    }
  }

  screenTargets(objects: ObjectSnapshot[]): ScreenTarget[] {
    const width = this.canvas.clientWidth
    const height = this.canvas.clientHeight
    return objects.map(object => {
      const center = new THREE.Vector3(object.x, object.y, object.z).project(this.camera)
      const radius = Math.max(object.size.x, object.size.y) / 2
      const edgeX = new THREE.Vector3(object.x + radius, object.y, object.z).project(this.camera)
      const edgeY = new THREE.Vector3(object.x, object.y + radius, object.z).project(this.camera)
      return {
        id: object.id,
        x: (center.x + 1) * width / 2,
        y: (1 - center.y) * height / 2,
        radius: Math.max(8, Math.abs(edgeX.x - center.x) * width / 2, Math.abs(edgeY.y - center.y) * height / 2),
      }
    })
  }

  showFlick(flick: Flick, now: number): void {
    this.flickRing.position.set(flick.origin.x, flick.origin.y, flick.origin.z + 0.12)
    ;(this.flickRing.material as THREE.MeshBasicMaterial).color.set(flick.source === 'finger' ? '#ffe19a' : '#a6fff1')
    this.flickAt = now
    this.flickRing.visible = true
  }

  showCatch(position: THREE.Vector3, now: number): void {
    this.flickRing.position.copy(position).add(new THREE.Vector3(0, 0, 0.16))
    ;(this.flickRing.material as THREE.MeshBasicMaterial).color.set('#ffe398')
    this.flickAt = now
    this.flickRing.visible = true
  }

  setCatchCue(x: number | null): void {
    this.catchCue.visible = x !== null
    if (x !== null) this.catchCue.position.x = x
  }

  update(objects: ObjectSnapshot[], handPosition: THREE.Vector3 | null, fingertipPosition: THREE.Vector3 | null, aimedId: number | null, now: number,
    handPoints: THREE.Vector3[] | null = null): void {
    const active = new Set<number>()
    for (const object of objects) {
      active.add(object.id)
      let mesh = this.objects.get(object.id)
      if (!mesh) {
        const material = object.kind === 'ball' ? this.ballMaterials[(object.id - 1) % this.ballMaterials.length] : this.materials[object.kind]
        mesh = new THREE.Mesh(object.kind === 'ball' || object.kind === 'catch' ? this.sphereGeometry : this.boxGeometry, material)
        this.scene.add(mesh)
        this.objects.set(object.id, mesh)
      }
      mesh.position.set(object.x, object.y, object.z)
      mesh.quaternion.set(object.rotation.x, object.rotation.y, object.rotation.z, object.rotation.w)
      if (object.kind === 'ball' || object.kind === 'catch') mesh.scale.setScalar(object.size.x / 2)
      else mesh.scale.set(object.size.x, object.size.y, object.size.z)
    }
    for (const [id, mesh] of this.objects) {
      if (active.has(id)) continue
      this.scene.remove(mesh)
      this.objects.delete(id)
    }
    const aimed = objects.find(object => object.id === aimedId)
    this.targetRing.visible = Boolean(aimed && handPosition)
    if (aimed && handPosition) {
      const center = new THREE.Vector3(aimed.x, aimed.y, aimed.z)
      const towardsCamera = this.camera.position.clone().sub(center).normalize()
      this.targetRing.position.copy(center.addScaledVector(towardsCamera, Math.max(aimed.size.x, aimed.size.y, aimed.size.z) * 0.6 + 0.08))
      this.targetRing.quaternion.copy(this.camera.quaternion)
      this.targetRing.scale.setScalar(Math.max(aimed.size.x, aimed.size.y, aimed.size.z) * 0.65)
    }
    this.hand.visible = handPosition !== null
    if (handPosition) {
      this.hand.position.copy(handPosition)
      this.updatePose(handPoints)
    }
    this.finger.visible = fingertipPosition !== null
    if (fingertipPosition) this.finger.position.copy(fingertipPosition)
    const age = (now - this.flickAt) / 380
    this.flickRing.visible = age >= 0 && age < 1
    if (this.flickRing.visible) {
      this.flickRing.scale.setScalar(1 + age * 2.4)
      ;(this.flickRing.material as THREE.MeshBasicMaterial).opacity = (1 - age) * 0.9
    }
    this.renderer.render(this.scene, this.camera)
  }
}
