extends Area2D

var is_full = true
@onready var anim = $AnimatedSprite2D

func _ready():
	refill()

func refill():
	is_full = true
	anim.play("full")

func has_food():
	return is_full

func consume():
	is_full = false
	anim.play("empty")

func _input_event(viewport, event, shape_idx):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if not is_full:
			refill()
