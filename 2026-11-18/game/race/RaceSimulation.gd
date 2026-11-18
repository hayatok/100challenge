extends RefCounted

const Yard = preload("res://race/YardLayout.gd")

const START_X := [-1.6, -3.7, -0.1, 1.35, 2.85, 4.25]
const FINISH := 150.0
const DECK_EDGE := 4.7
const SPLIT_START := 52.0
const SPLIT_END := 94.0
const BRIDGE_START := 59.0
const BRIDGE_END := 87.0
const BRIDGE_PIVOT := 73.0
const BRIDGE_LEFT := -4.7
const BRIDGE_RIGHT := -0.2
const MAX_BRIDGE_ANGLE := 0.123
const OUTER_BOW := 3.5
const WATER_HEIGHT := -1.75
const CHECKPOINTS := [0.0, 27.0, 46.0, 108.0]

# Vector2 coordinates are world x and course progress.
const CRATES := [Vector2(-1.8, 14.0), Vector2(2.0, 21.0)]
const CRATE_HEIGHT := 1.25
const CRATE_HALF_WIDTH := 0.75
const BARS := [35.0, 125.0]
const BAR_START := [0.47, 2.50]
const BAR_SPIN := [1.25, -1.56]
const BAR_RADIUS := 4.1
const BAR_HEIGHT := 0.65
const BAR_HALF_THICKNESS := 0.25

const STEP := 1.0 / 60.0
const MAX_SPEED := 3.92
const LATERAL_SPEED := 4.0
const TAKEOFF_SPEED := 7.65
const GRAVITY := 17.8
const BOOST_COUNT := 2
const BOOST_DURATION := 1.2
const BOOST_FACTOR := 1.3
const DIVE_FACTOR := 1.5
const SLIDE_SECONDS := 0.35
const SLIDE_FACTOR := 0.38
const STEP_HEIGHT := 0.17
const TIE_TOLERANCE := 0.00001

# Rival profiles affect decisions. All movement and collision use the same rules.
const RIVAL_LANES := [0.0, -3.2, -1.0, 0.8, 3.55, 4.25]
const BRIDGE_LANES := [0.0, -3.3, -1.2, -2.1, -2.7, -1.1]
const RIVAL_RISK := [0.0, 1.15, 0.75, 0.75, 0.04, 0.36]
const JUMP_LOOKAHEAD := [0.0, 0.48, 0.37, 0.59, 0.42, 0.56]

var runners: Array = []
var course_id := "wharf"
var finish_distance := FINISH
var checkpoints := CHECKPOINTS
var time: float = 0.0
var bridge_angle: float = 0.0
var bar_angles := PackedFloat32Array()
var _bridge_velocity: float = 0.0


func _init() -> void:
	reset()


func reset(selected_course := "wharf") -> void:
	course_id = "yard" if selected_course == "yard" else "wharf"
	finish_distance = Yard.FINISH if course_id == "yard" else FINISH
	checkpoints = Yard.CHECKPOINTS if course_id == "yard" else CHECKPOINTS
	time = 0.0
	bridge_angle = 0.0
	_bridge_velocity = 0.0
	bar_angles = PackedFloat32Array(BAR_START)
	runners.clear()
	for x: float in START_X:
		runners.append({
			"x": x, "p": 0.0, "y": 0.0, "state": "idle", "elapsed": 0.0,
			"phase": 0.0, "steer": 0.0, "finish_time": -1.0, "respawns": 0,
			"vx": 0.0, "vy": 0.0, "speed": 0.0, "grounded": true,
			"boosts_left": BOOST_COUNT, "boost_left": 0.0, "dive_ready": false,
			"transport_x": 0.0, "stagger": 0.0, "bar_cooldown": 0.0,
			"crate_contact": false, "checkpoint": 0, "route": 0, "bridge_misses": 0,
		})


func step(dt: float, player_target_x: float, action_pressed: bool, boost_pressed := false) -> void:
	if dt <= 0.0:
		return
	for runner: Dictionary in runners:
		runner.transport_x = 0.0
	var remaining := dt
	while remaining > 0.000001:
		var tick := minf(remaining, STEP)
		_advance(tick, player_target_x + runners[0].transport_x, action_pressed, boost_pressed)
		remaining -= tick
		action_pressed = false
		boost_pressed = false


func rank_of(index: int) -> int:
	var runner: Dictionary = runners[index]
	var rank := 1
	for rival: Dictionary in runners:
		if rival.finish_time >= 0.0:
			if runner.finish_time < 0.0 or rival.finish_time < runner.finish_time - TIE_TOLERANCE:
				rank += 1
		elif runner.finish_time < 0.0 and rival.p > runner.p + TIE_TOLERANCE:
			rank += 1
	return rank


func _advance(dt: float, player_target_x: float, action: bool, boost: bool) -> void:
	var tick_start := time
	time += dt
	if course_id == "wharf":
		_update_bridge(dt)
		for index in BARS.size():
			bar_angles[index] = fposmod(BAR_START[index] + BAR_SPIN[index] * time, TAU)

	# Decide from the same starting positions before moving any runner.
	var intents := PackedVector3Array([Vector3(player_target_x, float(action), float(boost))])
	for index in range(1, runners.size()):
		if course_id == "yard":
			intents.append(_yard_intent(index))
		else:
			intents.append(_wharf_intent(index))
	for index in runners.size():
		var intent := intents[index]
		_move_runner(runners[index], dt, tick_start, intent.x, intent.y > 0.0, intent.z > 0.0)
	_resolve_shoulders(dt)


func _update_bridge(dt: float) -> void:
	var torque := 0.0
	for runner: Dictionary in runners:
		if runner.grounded and _on_bridge(runner.x, runner.p):
			torque += BRIDGE_PIVOT - float(runner.p)
	var target := clampf(torque * 0.0072, -MAX_BRIDGE_ANGLE, MAX_BRIDGE_ANGLE)
	_bridge_velocity += ((target - bridge_angle) * 29.0 - _bridge_velocity * 9.0) * dt
	bridge_angle = clampf(bridge_angle + _bridge_velocity * dt, -MAX_BRIDGE_ANGLE, MAX_BRIDGE_ANGLE)


func _on_bridge(x: float, p: float) -> bool:
	return course_id == "wharf" and p >= BRIDGE_START and p < BRIDGE_END and _on_inner(x)


func _on_inner(x: float) -> bool:
	return x >= BRIDGE_LEFT and x <= BRIDGE_RIGHT


func _outer_shift(p: float) -> float:
	return OUTER_BOW * sin(PI * (p - SPLIT_START) / (SPLIT_END - SPLIT_START))


func _ground_height(x: float, p: float) -> float:
	if course_id == "yard":
		return Yard.ground_height(x, p)
	if p < SPLIT_START or p >= SPLIT_END:
		return 0.0 if absf(x) <= DECK_EDGE else -INF
	if _on_bridge(x, p):
		return (p - BRIDGE_PIVOT) * tan(bridge_angle)
	if _on_inner(x):
		return 0.0
	var lane := x - _outer_shift(p)
	return 0.0 if lane >= 1.0 and lane <= 5.0 else -INF


func _surface(x: float, p: float) -> float:
	if course_id == "yard":
		var roof := Yard.roof_at(x, p, time)
		return Yard.ROOFS[roof].height if roof >= 0 else Yard.ground_height(x, p)
	if _crate_height(x, p) > 0.0:
		return CRATE_HEIGHT
	return _ground_height(x, p)


func _crate_height(x: float, p: float) -> float:
	for crate: Vector2 in CRATES:
		if absf(x - crate.x) <= CRATE_HALF_WIDTH + 0.22 and absf(p - crate.y) <= CRATE_HALF_WIDTH:
			return CRATE_HEIGHT
	return 0.0


func _move_runner(runner: Dictionary, dt: float, tick_start: float, target_x: float, action: bool, boost: bool) -> void:
	runner.elapsed += dt
	if runner.state == "fall":
		_update_fall(runner, dt)
		return
	if runner.state == "finish":
		runner.speed = move_toward(runner.speed, 0.0, 4.4 * dt)
		runner.p += runner.speed * dt
		runner.phase = fposmod(runner.phase + runner.speed * dt / 1.65, 1.0)
		if not runner.grounded:
			runner.vy -= GRAVITY * dt
			runner.y = maxf(0.0, runner.y + runner.vy * dt)
			if runner.y == 0.0:
				runner.grounded = true
				runner.vy = 0.0
		return

	var x: float = runner.x
	var p: float = runner.p
	var y: float = runner.y
	runner.stagger = maxf(0.0, runner.stagger - dt)
	runner.bar_cooldown = maxf(0.0, runner.bar_cooldown - dt)
	var sliding: bool = runner.state == "slide" and runner.elapsed < SLIDE_SECONDS
	_apply_actions(runner, action, boost, sliding)
	var sprinting: bool = runner.boost_left > 0.000001
	_update_velocity(runner, target_x, dt, sprinting, sliding)
	var new_p := p + _forward_speed(runner, p, x) * dt
	var carry := 0.0
	if course_id == "yard":
		carry = _yard_transport(runner, tick_start, p, new_p)
	var new_x := x + float(runner.vx) * dt + carry

	var new_y := y
	if not runner.grounded:
		runner.vy -= GRAVITY * dt
		new_y += runner.vy * dt

	runner.transport_x += carry
	runner.x = new_x
	runner.p = new_p
	runner.y = new_y
	if course_id == "yard":
		_block_practice_container(runner, x, p, y)
	else:
		_block_crates(runner, x, p)
	new_x = runner.x
	new_p = runner.p
	var floor_height := _surface(new_x, new_p)
	if floor_height == -INF:
		if runner.grounded or new_y <= WATER_HEIGHT:
			_begin_fall(runner)
			return
	elif floor_height > maxf(y, new_y) + STEP_HEIGHT:
		# A lowered bridge end cannot step up through the face of the next pier.
		_begin_fall(runner)
		return
	else:
		_land_or_follow_surface(runner, floor_height)

	if course_id == "wharf":
		_hit_bars(runner, new_x, new_p)

	if runner.grounded:
		var next: int = runner.checkpoint + 1
		if next < checkpoints.size() and new_p >= checkpoints[next]:
			runner.checkpoint = next
		var recovering: bool = (runner.state == "land" and runner.elapsed < 0.14
			or runner.state == "slide" and runner.elapsed < SLIDE_SECONDS)
		if runner.stagger <= 0.0 and not recovering:
			_set_state(runner, "sprint" if sprinting else "run")
	elif runner.stagger <= 0.0 and runner.state != "dive":
		_set_state(runner, "jump")

	if runner.state in ["run", "sprint", "stumble", "land"]:
		runner.phase = fposmod(runner.phase + (new_p - p) / 1.65, 1.0)
	if new_p >= finish_distance and floor_height != -INF:
		var crossing := (finish_distance - p) / (new_p - p) if p < finish_distance else 1.0
		runner.finish_time = tick_start + dt * crossing
		runner.steer = 0.0
		runner.boost_left = 0.0
		runner.dive_ready = false
		_set_state(runner, "finish")


func _apply_actions(runner: Dictionary, action: bool, boost: bool, sliding: bool) -> void:
	if runner.stagger > 0.0 or sliding:
		return
	if boost and runner.grounded and runner.boosts_left > 0 and runner.boost_left <= 0.0:
		runner.boosts_left -= 1
		runner.boost_left = BOOST_DURATION
	if action:
		if runner.grounded:
			runner.grounded = false
			runner.vy = TAKEOFF_SPEED
			runner.dive_ready = true
			_set_state(runner, "jump")
		elif runner.dive_ready:
			runner.dive_ready = false
			runner.vy = minf(runner.vy, 0.0)
			_set_state(runner, "dive")


func _update_velocity(runner: Dictionary, target_x: float, dt: float, sprinting: bool, sliding: bool) -> void:
	var lateral_limit := LATERAL_SPEED if runner.grounded else LATERAL_SPEED * 0.62
	var speed_limit := MAX_SPEED
	if sprinting:
		lateral_limit *= 0.7
		speed_limit *= BOOST_FACTOR
	if runner.state == "dive":
		speed_limit = MAX_SPEED * DIVE_FACTOR
		runner.speed = speed_limit
	elif sliding:
		speed_limit = MAX_SPEED * SLIDE_FACTOR
	if runner.stagger > 0.0:
		lateral_limit *= 0.76
		speed_limit = MAX_SPEED * 0.42
	runner.boost_left = maxf(0.0, runner.boost_left - dt)
	var steer_error := clampf(target_x, -6.0, 13.5) - float(runner.x)
	var desired_vx := clampf(steer_error * 8.0, -lateral_limit, lateral_limit)
	runner.vx = move_toward(runner.vx, desired_vx, 21.0 * dt)
	runner.steer = clampf(runner.vx / LATERAL_SPEED, -1.0, 1.0)
	runner.speed = move_toward(runner.speed, speed_limit, 12.0 * dt)


func _block_practice_container(runner: Dictionary, old_x: float, old_p: float, old_y: float) -> void:
	# Below the training roof a runner meets its front wall, or is pushed
	# aside if the crane brings the load across the wide catch deck.
	var practice: Dictionary = Yard.ROOFS[0]
	if Yard.roof_at(runner.x, runner.p, time) != 0 or maxf(old_y, runner.y) + STEP_HEIGHT >= practice.height:
		runner.crate_contact = false
		return
	if old_p < practice.p - practice.length * 0.5:
		runner.p = old_p
		runner.speed = 0.0
	else:
		var center := Yard.roof_x(0, time)
		var side := -1.0 if old_x < center else 1.0
		var edge: float = center + side * (practice.width * 0.5 + 0.001)
		runner.transport_x += edge - float(runner.x)
		runner.x = edge
	if not runner.crate_contact:
		_stumble(runner, 0.26)
	runner.crate_contact = true


func _block_crates(runner: Dictionary, old_x: float, old_p: float) -> void:
	var height := _crate_height(runner.x, runner.p)
	if height == 0.0 or height <= float(runner.y) + STEP_HEIGHT or _crate_height(old_x, old_p) > 0.0:
		runner.crate_contact = false
		return
	if _crate_height(runner.x, old_p) > 0.0:
		runner.x = old_x
		runner.vx = 0.0
	else:
		runner.p = old_p
		runner.speed = minf(runner.speed, MAX_SPEED * 0.42)
	if not runner.crate_contact:
		_stumble(runner, 0.26)
	runner.crate_contact = true


func _hit_bars(runner: Dictionary, x: float, p: float) -> void:
	if runner.bar_cooldown > 0.0 or runner.y >= BAR_HEIGHT + BAR_HALF_THICKNESS:
		return
	for index in BARS.size():
		if _bar_contact(x, p, index, bar_angles[index]):
			runner.bar_cooldown = 0.9
			runner.speed = minf(runner.speed, MAX_SPEED * 0.52)
			_stumble(runner, 0.49)
			return


func _yard_transport(runner: Dictionary, previous_time: float, p: float, new_p: float) -> float:
	if Yard.on_outer(runner.x, p):
		# Auto-run follows the actual pier tangent. Steering remains relative to it.
		return Yard.outer_x(new_p) - Yard.outer_x(p)
	if not runner.grounded:
		return 0.0
	var roof := Yard.roof_at(runner.x, p, previous_time)
	if roof >= 0 and is_equal_approx(runner.y, Yard.ROOFS[roof].height):
		return Yard.roof_x(roof, time) - Yard.roof_x(roof, previous_time)
	return Yard.belt_speed(runner.x, p) * (time - previous_time)


func _forward_speed(runner: Dictionary, p: float, x: float) -> float:
	var speed: float = runner.speed
	var lateral: float = runner.vx / LATERAL_SPEED
	var steering_scale := sqrt(1.0 - 0.36 * lateral * lateral)
	if course_id == "yard":
		if Yard.on_outer(x, p):
			var slope := Yard.outer_slope(p)
			return speed * steering_scale / sqrt(1.0 + slope * slope)
		return speed * steering_scale
	if p >= SPLIT_START and p < SPLIT_END and not _on_inner(x):
		var grade := OUTER_BOW * PI / (SPLIT_END - SPLIT_START)
		grade *= cos(PI * (p - SPLIT_START) / (SPLIT_END - SPLIT_START))
		return speed * minf(steering_scale, 1.0 / sqrt(1.0 + grade * grade))
	return speed * steering_scale


func _land_or_follow_surface(runner: Dictionary, floor_height: float) -> void:
	if runner.grounded and runner.y - floor_height > STEP_HEIGHT:
		runner.grounded = false
		runner.vy = 0.0
	elif runner.grounded or (runner.vy <= 0.0 and runner.y <= floor_height):
		var just_landed: bool = not runner.grounded
		runner.y = floor_height
		runner.grounded = true
		runner.vy = 0.0
		if just_landed:
			runner.dive_ready = false
			if runner.state == "dive":
				runner.speed = MAX_SPEED * SLIDE_FACTOR
				_set_state(runner, "slide")
			elif runner.stagger <= 0.0:
				_set_state(runner, "land")


func _set_state(runner: Dictionary, state: String) -> void:
	if runner.state != state:
		runner.state = state
		runner.elapsed = 0.0


func _stumble(runner: Dictionary, duration: float) -> void:
	runner.stagger = maxf(runner.stagger, duration)
	runner.dive_ready = false
	_set_state(runner, "stumble")


func _begin_fall(runner: Dictionary) -> void:
	if (course_id == "wharf" and runner.p >= SPLIT_START and runner.p < SPLIT_END
		or course_id == "yard" and runner.p >= Yard.SPLIT_START and runner.p < Yard.SPLIT_END):
		runner.bridge_misses += 1
	runner.boost_left = 0.0
	runner.dive_ready = false
	runner.grounded = false
	runner.vy = minf(runner.vy, 0.0)
	_set_state(runner, "fall")


func _update_fall(runner: Dictionary, dt: float) -> void:
	runner.vx = move_toward(runner.vx, 0.0, 6.0 * dt)
	runner.x += runner.vx * dt
	runner.steer = runner.vx / LATERAL_SPEED
	runner.vy -= GRAVITY * dt
	runner.y = maxf(WATER_HEIGHT - 1.1, runner.y + runner.vy * dt)
	if runner.elapsed < 0.84:
		return
	runner.p = checkpoints[runner.checkpoint]
	runner.x = clampf(runner.x, -4.05, 4.05)
	if course_id == "yard" and runner.p == Yard.CHECKPOINTS[2]:
		# The approach is short. Face the continuous pier on recovery so a
		# missed jump never forces another attempt at the water crossing.
		runner.x = Yard.OUTER_CENTER
	runner.y = 0.0
	runner.vx = 0.0
	runner.vy = 0.0
	runner.speed = 0.0
	runner.steer = 0.0
	runner.phase = 0.0
	runner.grounded = true
	runner.dive_ready = false
	runner.stagger = 0.0
	runner.bar_cooldown = 0.0
	runner.crate_contact = false
	runner.route = 0
	runner.respawns += 1
	_set_state(runner, "run")


func _bar_contact(x: float, p: float, index: int, angle: float) -> bool:
	var offset := Vector2(x, p - float(BARS[index]))
	const RUNNER_RADIUS := 0.25
	var arm_endpoint := BAR_RADIUS - BAR_HALF_THICKNESS
	var reach := BAR_HALF_THICKNESS + RUNNER_RADIUS
	if offset.length_squared() > (arm_endpoint + reach) * (arm_endpoint + reach):
		return false
	var direction := Vector2(cos(angle), sin(angle))
	var projection := clampf(offset.dot(direction), -arm_endpoint, arm_endpoint)
	return offset.distance_squared_to(direction * projection) < reach * reach


func _wharf_intent(index: int) -> Vector3:
	var runner: Dictionary = runners[index]
	var p: float = runner.p
	var x: float = runner.x
	var target: float = RIVAL_LANES[index]
	var jump := false
	var keep_route := p >= 49.0 and p < SPLIT_END
	if not keep_route:
		runner.route = 0
	if p >= 44.0 and p < SPLIT_END:
		if runner.route == 0 or p < 49.0:
			runner.route = _choose_route(index)
		if runner.route == 1:
			target = BRIDGE_LANES[index]
			var entry: float = (BRIDGE_START - BRIDGE_PIVOT) * tan(bridge_angle)
			var exit: float = (BRIDGE_END - BRIDGE_PIVOT) * tan(bridge_angle)
			if p > BRIDGE_START - 2.15 and p < BRIDGE_START - 0.85 and entry > STEP_HEIGHT:
				jump = true
			if p > BRIDGE_END - 2.25 and p < BRIDGE_END - 1.10 and exit < -STEP_HEIGHT:
				jump = true
		else:
			target = 2.5 + float(index - 3) * 0.52
			var lookahead := clampf(p + 1.6, SPLIT_START, SPLIT_END)
			target += _outer_shift(lookahead)

	for crate: Vector2 in CRATES:
		if p > crate.y - 5.5 and p < crate.y + 1.25:
			if absf(target - crate.x) < CRATE_HALF_WIDTH + 0.43:
				var side := -1.0 if target < crate.x else 1.0
				target = crate.x + side * (CRATE_HALF_WIDTH + 0.54)

	for bar_index in BARS.size():
		if absf(p - float(BARS[bar_index])) < 7.0 and runner.grounded:
			var ahead: float = JUMP_LOOKAHEAD[index]
			var future_x := move_toward(x, target, LATERAL_SPEED * 0.55 * ahead)
			var future_p := p + float(runner.speed) * ahead
			jump = jump or _bar_contact(
				future_x, future_p, bar_index, bar_angles[bar_index] + BAR_SPIN[bar_index] * ahead
			)
	if not runner.grounded:
		jump = runner.dive_ready and runner.vy <= 0.35 and p > BRIDGE_END - 1.5 and p < BRIDGE_END
	var boost_at := 41.0 + index * 1.1
	var finish_boost := FINISH - 4.0 - index * 1.6
	var boost := (p >= boost_at and p < boost_at + 0.8 or p >= finish_boost and p < finish_boost + 0.8)
	return Vector3(target, float(jump), float(boost))


func _yard_intent(index: int) -> Vector3:
	var runner: Dictionary = runners[index]
	var p: float = runner.p
	var target: float = RIVAL_LANES[index]
	var action := false
	var boost_at := 40.0 + 1.3 * index
	if index == 2:
		boost_at = Yard.GAP_START - 2.3
	elif index == 4:
		boost_at = Yard.SPLIT_END + 1.0
	# Take the training roof or use the open apron alongside it.
	if p > 49.0 and p < 64.0:
		if index == 2 or index == 3:
			target = Yard.roof_x(0, time + 0.35)
			action = p > 54.7 and p < 56.1 and runner.grounded
			if runner.dive_ready and runner.vy <= 0.35:
				action = true
		else:
			target = 3.75 if index >= 4 else -4.4
	if p >= 78.0 and p < Yard.SPLIT_END:
		if runner.route == 0:
			# Predict where the far roof will be when this runner reaches it.
			var approach_time := (Yard.GAP_START + 2.3 - p) / MAX_SPEED
			if index == 2 and runner.boosts_left > 0:
				approach_time -= 0.25
			var landing_x := Yard.roof_x(1, time + approach_time)
			var takeoff_x := -3.35 + (index - 2) * 0.29
			var reach := 2.58 if index < 4 else 1.1
			runner.route = 1 if runner.bridge_misses == 0 and absf(landing_x - takeoff_x) < reach else 2
		if runner.route == 2:
			target = Yard.outer_x(p) + (index - 3) * 0.38
		else:
			target = _yard_inner_target(runner, index)
			if runner.grounded:
				action = (p > Yard.GAP_START - 0.75 and p < Yard.GAP_START
					or p > Yard.GAP_END - 2.25 and p < Yard.GAP_END - 1.4)
			elif runner.dive_ready and runner.vy <= 0.35 and p >= Yard.GAP_END - 1.0:
				action = true
	if p >= Yard.SPLIT_END:
		runner.route = 0
	var finish_boost := Yard.FINISH - 5.5 - 1.6 * index
	var boost := (p >= boost_at and p < boost_at + 0.8 or p >= finish_boost and p < finish_boost + 0.8)
	return Vector3(target, float(action), float(boost))


func _yard_inner_target(runner: Dictionary, index: int) -> float:
	var p: float = runner.p
	var lane := -3.35 + (index - 2) * 0.29
	if p < 103.0 or p > Yard.GAP_END:
		return lane
	if p >= Yard.GAP_END - 3.0:
		return clampf(Yard.roof_x(1, time), Yard.INNER_LEFT + 0.6, Yard.INNER_RIGHT - 0.6)
	var ahead := maxf(0.0, (Yard.GAP_START + 2.5 - p) / MAX_SPEED)
	return Yard.roof_x(1, time + ahead) + (index - 2) * 0.14


func _choose_route(index: int) -> int:
	var runner: Dictionary = runners[index]
	if runner.bridge_misses > 0:
		return 2
	var risk := maxf(0.0, -bridge_angle) * 6.0
	var follows_inner := false
	for rival_index in runners.size():
		if rival_index == index:
			continue
		var rival: Dictionary = runners[rival_index]
		if _on_bridge(rival.x, rival.p):
			risk += 0.29
		elif rival.p >= 43.0 and rival.p < BRIDGE_START and _on_inner(rival.x):
			risk += 0.12
		if rival.p >= runner.p and rival.p < runner.p + 9.0 and _on_inner(rival.x):
			follows_inner = true
	if index == 3 and follows_inner:
		risk -= 0.22
	return 1 if risk <= RIVAL_RISK[index] else 2


func _resolve_shoulders(dt: float) -> void:
	for index in runners.size():
		var runner: Dictionary = runners[index]
		if not runner.grounded or runner.state == "finish":
			continue
		for next in range(index + 1, runners.size()):
			var rival: Dictionary = runners[next]
			if not rival.grounded or rival.state == "finish":
				continue
			var gap: float = runner.x - rival.x
			if absf(gap) >= 0.48 or absf(runner.p - rival.p) >= 0.62 or absf(runner.y - rival.y) > 0.3:
				continue
			var shift := minf((0.48 - absf(gap)) * 0.36, 0.52 * dt)
			var side := -1.0 if gap <= 0.0 else 1.0
			_yield_space(runner, side * shift)
			_yield_space(rival, -side * shift)


func _yield_space(runner: Dictionary, shift: float) -> void:
	var moved_x: float = runner.x + shift
	if absf(_surface(moved_x, runner.p) - runner.y) < 0.05:
		runner.x = moved_x
