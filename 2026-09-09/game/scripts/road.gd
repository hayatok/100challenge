@tool
extends Node3D
## Authored module centerline, transformed with the visible road in the editor.
@export var turn: float = 0.0
@export var radius: float = 18.0
@export var length: float = 24.0
@export var speed_hint: float = 18.0
func points() -> PackedVector3Array:
 var result := PackedVector3Array()
 var count := 12
 for i in range(count + 1):
  var t := float(i) / count
  var local := Vector3(0, 0.24, length * t)
  if turn != 0.0:
   var a := t * PI / 2.0
   local = Vector3(signf(turn) * radius * (1.0 - cos(a)), 0.24, radius * sin(a))
  result.append(global_transform * local)
 return result
