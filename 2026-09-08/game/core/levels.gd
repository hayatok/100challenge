class_name RescueLevels
extends RefCounted

const Campaign = preload("res://core/campaign.gd")

static func all() -> Array[Dictionary]:
	return Campaign.all()
