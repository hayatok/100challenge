class_name RaceCircuit
extends RefCounted
var points := PackedVector3Array()
var speeds := PackedFloat32Array()
var distances := PackedFloat32Array()
var length: float = 0.0
var error: String = ""

func build(course: Node3D) -> bool:
 points.clear()
 speeds.clear()
 distances.clear()
 length = 0.0
 error = ""
 var roads: Array[Node] = []
 for child in course.get_children():
  if child.has_method("points"):
   roads.append(child)
 if roads.size() < 4:
  error = "道路部品が足りません。"
  return false
 # Follow the actual GUI-authored endpoints, independent of tree sorting.
 var first: Node = roads.pop_front()
 var current: Node = first
 while true:
  var segment: PackedVector3Array = current.points()
  for i in range(segment.size() - 1):
   points.append(segment[i])
   speeds.append(float(current.speed_hint))
  if roads.is_empty():
   if segment[-1].distance_to(points[0]) > 0.15:
    error = "コースの終端がスタートにつながっていません。"
   break
  var next_index: int = -1
  for i in range(roads.size()):
   var candidate: PackedVector3Array = roads[i].points()
   if segment[-1].distance_to(candidate[0]) < 0.15:
    next_index = i
    break
  if next_index < 0:
   error = "道路の接続が切れています: " + current.name
   return false
  current = roads.pop_at(next_index)
 for i in range(points.size()):
  distances.append(length)
  length += points[i].distance_to(points[(i + 1) % points.size()])
 return error.is_empty()

func sample(s: float) -> Dictionary:
 s = fposmod(s, length)
 var index: int = 0
 for i in range(distances.size()):
  if distances[i] <= s:
   index = i
  else:
   break
 var a: Vector3 = points[index]
 var b: Vector3 = points[(index + 1) % points.size()]
 var t: float = clampf((s - distances[index]) / a.distance_to(b), 0.0, 1.0)
 return {"position": a.lerp(b, t), "direction": (b - a).normalized(), "speed": speeds[index]}

func project(p: Vector3) -> Dictionary:
 var best: float = INF
 var along: float = 0.0
 var nearest := Vector3.ZERO
 var direction := Vector3.FORWARD
 for i in range(points.size()):
  var a: Vector3 = points[i]
  var b: Vector3 = points[(i + 1) % points.size()]
  var ab: Vector3 = b - a
  var t: float = clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
  var q: Vector3 = a + t * ab
  var d: float = Vector2(p.x - q.x, p.z - q.z).length_squared()
  if d < best:
   best = d
   along = distances[i] + t * ab.length()
   nearest = q
   direction = ab.normalized()
 return {"s": along, "distance": sqrt(best), "position": nearest, "direction": direction}

func delta_progress(previous: float, current: float) -> float:
 return fposmod(current - previous + length * 0.5, length) - length * 0.5
