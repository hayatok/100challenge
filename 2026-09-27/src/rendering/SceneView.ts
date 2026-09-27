import * as THREE from 'three'
import type { ObjectKind, ObjectSnapshot } from '../physics/PhysicsWorld'

export class SceneView {
  readonly canvas: HTMLCanvasElement
  private renderer: THREE.WebGLRenderer
  private scene = new THREE.Scene()
  private camera = new THREE.PerspectiveCamera(48, 1, 0.1, 100)
  private raycaster = new THREE.Raycaster()
  private plane = new THREE.Plane(new THREE.Vector3(0, 0, 1), 0)
  private hand: THREE.Group
  private objects = new Map<number, THREE.Mesh>()
  private sphereGeometry = new THREE.SphereGeometry(1, 24, 16)
  private boxGeometry = new THREE.BoxGeometry(1, 1, 1)
  private ballMaterials = ['#ff8b69', '#ffc774', '#86c8ff', '#e8a0ff', '#8ff0d5'].map(color =>
    new THREE.MeshStandardMaterial({ color, emissive: color, emissiveIntensity: 0.25, metalness: 0.2, roughness: 0.26 }))
  private materials: Record<ObjectKind, THREE.MeshStandardMaterial> = {
    ball: new THREE.MeshStandardMaterial({ color: '#86c8ff', emissive: '#56adff', emissiveIntensity: 0.25, metalness: 0.2, roughness: 0.26 }),
    box: new THREE.MeshStandardMaterial({ color: '#ffbd83', emissive: '#e9864d', emissiveIntensity: 0.2, metalness: 0.18, roughness: 0.4 }),
    domino: new THREE.MeshStandardMaterial({ color: '#c7abff', emissive: '#915cff', emissiveIntensity: 0.27, metalness: 0.24, roughness: 0.3 }),
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
    this.resizeObserver = new ResizeObserver(() => this.resize(host))
    this.resizeObserver.observe(host)
    this.resize(host)
  }

  private createHand(): THREE.Group {
    const group = new THREE.Group()
    const core = new THREE.Mesh(
      new THREE.SphereGeometry(0.47, 28, 18),
      new THREE.MeshPhysicalMaterial({ color: '#66f2e0', emissive: '#20ddc6', emissiveIntensity: 0.7, transparent: true, opacity: 0.62, roughness: 0.15, metalness: 0.18, depthWrite: false }),
    )
    group.add(core)
    const ring = new THREE.Mesh(
      new THREE.TorusGeometry(0.55, 0.022, 8, 64),
      new THREE.MeshBasicMaterial({ color: '#a6fff1' }),
    )
    group.add(ring)
    const inner = new THREE.Mesh(
      new THREE.SphereGeometry(0.08, 12, 8),
      new THREE.MeshBasicMaterial({ color: '#e8fffa' }),
    )
    group.add(inner)
    return group
  }

  private resize(host: HTMLElement): void {
    const width = Math.max(1, host.clientWidth)
    const height = Math.max(1, host.clientHeight)
    this.camera.aspect = width / height
    this.camera.updateProjectionMatrix()
    this.renderer.setSize(width, height, false)
  }

  screenToWorld(x: number, y: number): THREE.Vector3 {
    this.raycaster.setFromCamera(new THREE.Vector2(x * 2 - 1, 1 - y * 2), this.camera)
    const result = new THREE.Vector3()
    this.raycaster.ray.intersectPlane(this.plane, result)
    return result.set(THREE.MathUtils.clamp(result.x, -5.2, 5.2), THREE.MathUtils.clamp(result.y, 0.27, 4.3), 0)
  }

  update(objects: ObjectSnapshot[], handPosition: THREE.Vector3 | null, now: number): void {
    const active = new Set<number>()
    for (const object of objects) {
      active.add(object.id)
      let mesh = this.objects.get(object.id)
      if (!mesh) {
        const material = object.kind === 'ball' ? this.ballMaterials[(object.id - 1) % this.ballMaterials.length] : this.materials[object.kind]
        mesh = new THREE.Mesh(object.kind === 'ball' ? this.sphereGeometry : this.boxGeometry, material)
        this.scene.add(mesh)
        this.objects.set(object.id, mesh)
      }
      mesh.position.set(object.x, object.y, object.z)
      mesh.quaternion.set(object.rotation.x, object.rotation.y, object.rotation.z, object.rotation.w)
      if (object.kind === 'ball') mesh.scale.setScalar(object.size.x / 2)
      else mesh.scale.set(object.size.x, object.size.y, object.size.z)
    }
    for (const [id, mesh] of this.objects) {
      if (active.has(id)) continue
      this.scene.remove(mesh)
      this.objects.delete(id)
    }
    this.hand.visible = handPosition !== null
    if (handPosition) {
      this.hand.position.copy(handPosition)
      this.hand.rotation.z = Math.sin(now * 0.002) * 0.08
    }
    this.renderer.render(this.scene, this.camera)
  }
}
