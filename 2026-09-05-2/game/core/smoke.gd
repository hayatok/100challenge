extends SceneTree
const Sim = preload("res://core/simulation.gd")
func _initialize():
	var s = Sim.new()
	s.start()
	for i in 600:
		s.step(1.0/60.0,Vector2.RIGHT)
	print("SMOKE ",s.clock)
	quit()
