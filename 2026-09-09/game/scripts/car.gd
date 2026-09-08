class_name TinyRaceCar
extends CharacterBody3D
@export var driver_name: String = "YOU"
@export var player: bool = false
@export_range(0.7, 1.2) var pace: float = 0.9
@export var lane: float = 0.0
@export var top_speed: float = 20.0
@export var acceleration: float = 9.0
@export var brake_power: float = 24.0
@export var steering_rate: float = 1.8
@onready var model: MeshInstance3D = $Model
var circuit: RaceCircuit
var speed: float = 0.0
var steer_input: float = 0.0
var throttle: float = 0.0
var braking: bool = false
var active: bool = false
var route_s: float = 0.0
var progress: float = 0.0
var road_distance: float = 0.0
var recovery_count: int = 0
var total_laps: int = 0
var lap_started: bool = false
var finish_time: float = -1.0
var lap_start_time: float = 0.0
var best_lap: float = INF
var last_lap: float = 0.0
var invalid_jump: bool = false

func reset_at(s: float, lateral: float) -> void:
 var sample: Dictionary = circuit.sample(s)
 var forward: Vector3 = sample.direction
 global_position = sample.position + forward.cross(Vector3.UP) * lateral
 global_position.y = 0.31
 rotation = Vector3(0, atan2(forward.x, forward.z), 0)
 speed = 0.0
 velocity = Vector3.ZERO
 route_s = fposmod(s, circuit.length)
 progress = s - 12.0
 total_laps = 0
 lap_started = false
 finish_time = -1.0
 lap_start_time = 0.0
 best_lap = INF
 last_lap = 0.0
 recovery_count = 0
 invalid_jump = false
 model.rotation.z = 0.0

func recover() -> void:
 var sample: Dictionary = circuit.sample(route_s)
 global_position = sample.position + Vector3(0, 0.07, 0)
 var forward: Vector3 = sample.direction
 rotation.y = atan2(forward.x, forward.z)
 speed = 0.0
 velocity = Vector3.ZERO
 recovery_count += 1
 invalid_jump = false

func step(delta: float, elapsed: float) -> void:
 if not active or finish_time >= 0.0:
  return
 var projection: Dictionary = circuit.project(global_position)
 road_distance = projection.distance
 if not player:
  var lookahead: float = clampf(3.0 + speed * 0.4, 3.0, 10.0)
  var target: Dictionary = circuit.sample(float(projection.s) + lookahead)
  var target_position: Vector3 = target.position + Vector3(target.direction).cross(Vector3.UP) * lane
  var wanted: Vector3 = target_position - global_position
  var angle: float = wrapf(atan2(wanted.x, wanted.z) - rotation.y, -PI, PI)
  steer_input = clampf(angle * 2.8, -1.0, 1.0)
  var upcoming: Dictionary = circuit.sample(float(projection.s) + 16.0)
  var target_speed: float = minf(float(target.speed), float(upcoming.speed)) * pace
  throttle = 1.0 if speed < target_speed else 0.0
  braking = speed > target_speed + 0.5
 var limit: float = top_speed if road_distance < 5.1 else 5.0
 if braking:
  speed = move_toward(speed, 0.0, brake_power * delta)
 elif throttle > 0.0:
  speed = move_toward(speed, limit, acceleration * throttle * delta)
 else:
  speed = move_toward(speed, 0.0, 2.4 * delta)
 if road_distance > 5.1:
  speed = move_toward(speed, minf(speed, limit), 13.0 * delta)
 # Steering saturates at speed; braking buys a tighter turning radius.
 var turn_rate: float = steering_rate / (1.0 + speed * speed / 220.0)
 rotation.y += steer_input * turn_rate * minf(speed / 3.0, 1.0) * delta
 var forward := Vector3(sin(rotation.y), 0, cos(rotation.y))
 velocity = velocity.lerp(forward * speed, minf(1.0, delta * 9.0))
 velocity.y = 0.0
 move_and_slide()
 global_position.y = 0.31
 if get_slide_collision_count() > 0:
  speed *= 0.98
 model.rotation.z = lerpf(model.rotation.z, steer_input * speed * 0.004, delta * 8.0)
 var after: Dictionary = circuit.project(global_position)
 var advance: float = circuit.delta_progress(route_s, float(after.s))
 # No credit for jumping between nearby stretches or driving across the infield.
 var maximum_advance: float = top_speed * delta * 1.8 + 0.15
 if absf(advance) < maximum_advance and float(after.distance) < 5.4:
  progress += advance
  route_s = after.s
  invalid_jump = false
 elif float(after.distance) < 5.4 and absf(advance) >= maximum_advance:
  invalid_jump = true
 road_distance = after.distance
 if not lap_started and progress >= 0.0:
  lap_started = true
  lap_start_time = elapsed
 if lap_started and progress >= circuit.length * (total_laps + 1):
  total_laps += 1
  last_lap = elapsed - lap_start_time
  best_lap = minf(best_lap, last_lap)
  lap_start_time = elapsed
  if total_laps == 3:
   finish_time = elapsed
   collision_layer = 0
   collision_mask = 0
 if not player and (road_distance > 8.0 or invalid_jump):
  recover()
