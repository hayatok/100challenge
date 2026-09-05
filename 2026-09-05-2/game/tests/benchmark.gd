extends SceneTree
const Sim=preload("res://core/simulation.gd")
func _initialize():
	var s=Sim.new(600);s.start();s.enemies.clear();s.hurt_clock=99999
	for i in 600:s.spawn_enemy(Vector2(s.rng.randf_range(-15,15),s.rng.randf_range(-10,10)))
	var polygon=PackedVector2Array([Vector2(-3,-3),Vector2(3,-3),Vector2(3,3),Vector2(-3,3)])
	for i in 3:s.regions.append({"poly":polygon,"center":Vector2.ZERO,"life":9999.0,"shot":i*.2})
	var samples=[]
	for i in 3600:
		if s.state=="upgrade":s.choose(0)
		while s.enemies.size()<600:s.spawn_enemy(Vector2(s.rng.randf_range(-20,20),s.rng.randf_range(-12,12)))
		var begin=Time.get_ticks_usec();s.step(1.0/60,Vector2.from_angle(i*.04));samples.append(Time.get_ticks_usec()-begin)
	samples.sort()
	print(JSON.stringify({"mode":"headless simulation only; 600 enemies refilled, invulnerable fixture, 3 territories","steps":samples.size(),"p95_ms":samples[int(samples.size()*.95)]/1000.0,"max_ms":samples[-1]/1000.0}))
	quit()
