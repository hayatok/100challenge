extends Control
var circuit: RaceCircuit
var cars: Array[TinyRaceCar] = []
func _draw() -> void:
 if circuit == null or circuit.points.is_empty():
  return
 var low := Vector2(INF, INF)
 var high := Vector2(-INF, -INF)
 for p in circuit.points:
  low = low.min(Vector2(p.x, p.z))
  high = high.max(Vector2(p.x, p.z))
 var span := high - low
 var factor: float = minf((size.x - 22.0) / span.x, (size.y - 22.0) / span.y)
 var origin: Vector2 = (size - span * factor) * 0.5
 var line := PackedVector2Array()
 for p in circuit.points:
  line.append(origin + (Vector2(p.x, p.z) - low) * factor)
 line.append(line[0])
 draw_polyline(line, Color("172f34"), 8.0, true)
 draw_polyline(line, Color("f7efd8"), 3.0, true)
 for car in cars:
  if not car.visible:
   continue
  var point: Vector2 = origin + (Vector2(car.position.x, car.position.z) - low) * factor
  draw_circle(point, 6.5 if car.player else 4.5, Color("172f34"))
  draw_circle(point, 4.5 if car.player else 2.5, Color("ffd05b") if car.player else Color("f7efd8"))
