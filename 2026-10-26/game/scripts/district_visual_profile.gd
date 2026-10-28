extends Resource
## Inspector-editable material hierarchy for the coastal diorama.
class_name DistrictVisualProfile

@export var floor_color := Color("e1d6b9")
@export var wall_cap := Color("eee6ce")
@export var wall_face := Color("668785")
@export var water_color := Color("449da5")
@export var deep_water_color := Color("2d7e8d")
@export var timber_color := Color("c8a172")
@export var accent_color := Color("c68c5b")
@export_range(0.0, 1.0) var painted_grain := 0.13
@export_range(7.0, 10.0) var phone_columns := 7.8
@export_range(8.0, 15.0) var desktop_columns := 12.0
@export_range(0.45, 0.7) var player_foot_height := 0.60
@export_range(0.7, 1.6) var landmark_scale := 1.25
