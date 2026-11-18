extends RefCounted

const DURATION := 90.0
const STAGE_DURATION := 30.0
const CLOCK_EPSILON := 0.000001
const KILL_POINTS := 100
const EXTRA_KILL_POINTS := 150

const ALIVE_LIMITS := [6, 9, 12]
const WAVE_INTERVALS := [6.5, 5.0, 4.0]
# Enemy kinds match Enemy.setup: walker, runner, and heavy.
const WAVE_PATTERNS := [
	[[0, 0, 1, 0], [1, 0, 0]],
	[[1, 0, 1, 0], [2, 1, 0, 0]],
	[[2, 1, 0, 1, 0], [1, 1, 2, 0, 1]],
]

var time_left := DURATION
var score := 0
var kills := 0
var best_discharge := 0
var wave := 0
var stage := 1
var finished := false

var _until_wave := 0.0
var _stage_wave := 0


# Call only during active play. The caller counts living enemies and spawns the returned kinds.
func advance(delta: float, alive: int) -> Array[int]:
	if finished:
		return []

	var step := maxf(0.0, delta)
	time_left = maxf(0.0, time_left - step)
	var elapsed := DURATION - time_left
	var next_stage := mini(1 + int((elapsed + CLOCK_EPSILON) / STAGE_DURATION), ALIVE_LIMITS.size())
	_until_wave = maxf(0.0, _until_wave - step)
	if next_stage != stage:
		stage = next_stage
		_stage_wave = 0
		_until_wave = 0.0

	if time_left <= CLOCK_EPSILON:
		time_left = 0.0
		finished = true
		return []

	var stage_index := stage - 1
	var available: int = ALIVE_LIMITS[stage_index] - maxi(0, alive)
	if _until_wave > CLOCK_EPSILON or available <= 0:
		return []

	var patterns: Array = WAVE_PATTERNS[stage_index]
	var pattern: Array = patterns[_stage_wave % patterns.size()]
	var kinds: Array[int] = []
	kinds.assign(pattern.slice(0, available))
	_stage_wave += 1
	wave += 1
	_until_wave = WAVE_INTERVALS[stage_index]
	return kinds


func register_kill() -> void:
	if finished:
		return
	kills += 1
	score += KILL_POINTS


func register_discharge(discharge_kills: int) -> void:
	if finished or discharge_kills <= 0:
		return
	best_discharge = maxi(best_discharge, discharge_kills)
	score += (discharge_kills - 1) * EXTRA_KILL_POINTS
