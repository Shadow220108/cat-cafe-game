extends CharacterBody2D

enum State { IDLE, DRAGGED, LAYING, EATING, WANDER, NAP_STRIKE }
var current_state = State.IDLE

var max_hunger = 100.0
var current_hunger = 100.0
var hunger_decay = 2.0
var hunger_refill = 10.0
var nap_recovery = 1.0 # Slow recovery when on strike

var move_speed = 60.0

var is_mouse_inside = false
var drag_offset = Vector2.ZERO
var current_bowl = null

@onready var anim = $AnimatedSprite2D
@onready var hunger_bar = $HungerBar
@onready var interact_area = $InputArea
@onready var nav_agent = $NavigationAgent2D
@onready var wander_timer = $WanderTimer

func _ready():
	hunger_bar.max_value = max_hunger
	hunger_bar.value = current_hunger
	
	interact_area.mouse_entered.connect(func(): is_mouse_inside = true)
	interact_area.mouse_exited.connect(func(): is_mouse_inside = false)
	
	wander_timer.timeout.connect(_on_wander_timer_timeout)
	wander_timer.start()

func _physics_process(delta):
	handle_needs(delta)
	handle_movement()

func handle_needs(delta):
	# 1. NAP STRIKE LOGIC (Recover Slowly)
	if current_state == State.NAP_STRIKE:
		current_hunger += nap_recovery * delta
		
		# Wake up if we recovered enough energy (30%)
		if current_hunger >= 30.0:
			current_state = State.IDLE
			print("Cat woke up!")
			
	# 2. RESTING/EATING LOGIC (Recover Fast)
	elif current_state == State.LAYING:
		current_hunger += hunger_refill * delta
		
	elif current_state == State.EATING:
		current_hunger += hunger_refill * delta * 2
		
		if current_hunger >= max_hunger:
			current_hunger = max_hunger
			current_state = State.IDLE
			if current_bowl != null:
				current_bowl.consume()
				current_bowl = null
				
	# 3. NORMAL DECAY
	else:
		current_hunger -= hunger_decay * delta
		
		# TRIGGER THE NAP STRIKE
		if current_hunger <= 0:
			current_hunger = 0
			current_state = State.NAP_STRIKE
			print("Cat is too tired! Nap Strike!")

	current_hunger = clamp(current_hunger, 0, max_hunger)
	hunger_bar.value = current_hunger

func handle_movement():
	match current_state:
		State.DRAGGED:
			var target_pos = get_global_mouse_position() - drag_offset
			var distance = global_position.distance_to(target_pos)
			
			if distance > 5.0:
				velocity = global_position.direction_to(target_pos) * distance * 20.0
				move_and_slide()
			else:
				velocity = Vector2.ZERO
			
			if anim.animation != "idle":
				anim.play("idle")
			
		State.IDLE:
			velocity = Vector2.ZERO
			if anim.animation != "idle":
				anim.play("idle")
			
		State.LAYING:
			velocity = Vector2.ZERO
			if anim.animation != "laying":
				anim.play("laying")
			
		State.EATING:
			velocity = Vector2.ZERO
			if anim.animation != "idle":
				anim.play("idle")
				
		State.WANDER:
			if nav_agent.is_navigation_finished():
				current_state = State.IDLE
				wander_timer.start()
			else:
				var next_path_pos = nav_agent.get_next_path_position()
				velocity = global_position.direction_to(next_path_pos) * move_speed
				move_and_slide()
				
				if anim.animation != "idle":
					anim.play("idle")
					
		State.NAP_STRIKE:
			velocity = Vector2.ZERO
			# Uses 'laying' animation (or change to 'sleep' if you have one)
			if anim.animation != "laying":
				anim.play("laying")

func _on_wander_timer_timeout():
	# Only wander if IDLE (Don't wander if sleeping/eating)
	if current_state == State.IDLE:
		pick_random_location()

func pick_random_location():
	var map = get_world_2d().get_navigation_map()
	var random_point = NavigationServer2D.map_get_random_point(map, 1, false)
	nav_agent.target_position = random_point
	current_state = State.WANDER
	
	if not nav_agent.is_target_reachable():
		current_state = State.IDLE
		wander_timer.start(0.5)

func _input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if is_mouse_inside:
				# PREVENT DRAGGING IF ON STRIKE
				if current_state == State.NAP_STRIKE:
					print("Cat refuses to move!")
					return
				
				current_state = State.DRAGGED
				drag_offset = get_global_mouse_position() - global_position
		else:
			if current_state == State.DRAGGED:
				check_drop_zone()

func check_drop_zone():
	var found_zone = false
	var areas = interact_area.get_overlapping_areas()
	
	for area in areas:
		if area.is_in_group("food"):
			if area.has_method("has_food") and area.has_food():
				current_state = State.EATING
				current_bowl = area
				found_zone = true
			break
			
		elif area.is_in_group("bed"):
			current_state = State.LAYING
			found_zone = true
			break
			
	if not found_zone:
		current_state = State.IDLE
		wander_timer.start()
