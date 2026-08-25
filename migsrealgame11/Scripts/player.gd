extends CharacterBody2D

# --- Signals for HUD Communication ---
signal health_changed(new_health, max_health)
signal mushrooms_changed(count)
signal stew_buff_changed(current_bars, max_bars)
signal super_mode_activated(duration)
signal super_mode_timer_changed(time_left, max_time) 
signal super_mode_deactivated() 

# --- HUD Reference ---
@export var health_bar: TextureProgressBar
var original_bar_pos: Vector2

# --- Health System ---
@export var max_health: int = 50
var health: int = max_health

# --- Jump System ---
var max_jumps: int = 2 
var current_jumps: int = max_jumps 

# --- Stew Buff & Super Mode System ---
var stew_bars: int = 0
var max_stew_bars: int = 10 
var time_per_bar: float = 30.0 
var current_stew_timer: float = 0.0

@export var super_arrow_scene: PackedScene
var is_super_mode: bool = false
var super_mode_timer: float = 0.0
const SUPER_MODE_DURATION: float = 15.0

# --- Double Tap Variables ---
var last_interact_time: float = 0.0
const DOUBLE_TAP_TIME: float = 0.4 # Time in seconds allowed between taps

# --- Respawn System ---
var respawn_position: Vector2
var is_respawning: bool = false 

# --- Sprite Positioning ---
@export var right_facing_position: float = 13.0
@export var left_facing_position: float = -13.0 

const SPEED = 300.0
const JUMP_VELOCITY = -500.0
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

# Shooting
const SHOOT_POWER = 1200
const TRAJECTORY_POINTS = 30
const TRAJECTORY_TIME_STEP = 0.07
const TRAJECTORY_WIDTH = 2.5
const ARROW_GRAVITY_SCALE = 1.0
const SHOOT_COOLDOWN = 0.15

# Aim
const MAX_AIM_UP = -35
const MAX_AIM_DOWN = 35
const AIM_DEAD_ZONE = 30.0

@export var arrow_scene: PackedScene

# Nodes
@onready var sprite = $AnimatedSprite2D
@onready var camera = $Camera2D

const MIN_ZOOM = 0.15
const MAX_ZOOM = 1.40
const ZOOM_STEP = 0.1

# Jump helpers
const COYOTE_TIME = 0.1
var coyote_timer = 0.0
const JUMP_BUFFER_TIME = 0.1
var jump_buffer_timer = 0.0
var double_jump_available = false
var landing_velocity = 0.0

# Animation & Shooting State
var is_jumping = false
var is_aiming = false
var is_firing = false
var beginfire_finished = false
var can_shoot = true
var last_aim_direction: Vector2 = Vector2.RIGHT
var trajectory_line: Line2D

# Inventory
var inventory = {
	"mushroom": 0
}

func _ready():
	add_to_group("player")
	respawn_position = global_position
	
	trajectory_line = Line2D.new()
	trajectory_line.width = TRAJECTORY_WIDTH
	trajectory_line.default_color = Color.RED
	trajectory_line.top_level = true 
	add_child(trajectory_line)
	trajectory_line.hide()

	if sprite:
		sprite.animation_finished.connect(_on_animation_finished)

	health_changed.emit(health, max_health)
	stew_buff_changed.emit(stew_bars, max_stew_bars)
	update_ui()
	
	if health_bar:
		original_bar_pos = health_bar.position

func _input(event):
	if event.is_action_pressed("zoom_in"):
		apply_zoom(-ZOOM_STEP)
	if event.is_action_pressed("zoom_out"):
		apply_zoom(ZOOM_STEP)
		
	# --- Double-Tap Super Mode Activation ---
	if event.is_action_pressed("interact"):
		if stew_bars >= max_stew_bars and not is_super_mode:
			# Get current time in seconds
			var current_time = Time.get_ticks_msec() / 1000.0 
			
			if current_time - last_interact_time <= DOUBLE_TAP_TIME:
				activate_super_mode()
				
			last_interact_time = current_time

func apply_zoom(amount: float):
	var new_zoom_value = clamp(camera.zoom.x + amount, MIN_ZOOM, MAX_ZOOM)
	camera.zoom = Vector2(new_zoom_value, new_zoom_value)

func _physics_process(delta):
	var was_airborne = not is_on_floor()

	if not is_on_floor():
		velocity.y += gravity * delta
		coyote_timer -= delta
		is_jumping = true

		if velocity.y > 0:
			landing_velocity = velocity.y
	else:
		coyote_timer = COYOTE_TIME
		is_jumping = false
		double_jump_available = true

	if Input.is_action_just_pressed("jump"):
		jump_buffer_timer = JUMP_BUFFER_TIME

	if jump_buffer_timer > 0:
		jump_buffer_timer -= delta

	if jump_buffer_timer > 0 and (is_on_floor() or coyote_timer > 0):
		velocity.y = JUMP_VELOCITY
		jump_buffer_timer = 0
		coyote_timer = 0
		is_jumping = true
		current_jumps -= 1

		if not is_aiming and not is_firing:
			play_animation("jump")

	elif Input.is_action_just_pressed("jump") and not is_on_floor() and double_jump_available and coyote_timer <= 0:
		velocity.y = JUMP_VELOCITY
		double_jump_available = false
		is_jumping = true
		current_jumps -= 1

		if not is_aiming and not is_firing:
			play_animation("jump")

	var direction = Input.get_axis("left", "right")

	if direction != 0:
		velocity.x = direction * SPEED
		if not is_aiming:
			flip_sprite(direction)
		if not is_aiming and not is_jumping and not is_firing:
			play_animation("walk")
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED * delta * 8)
		if not is_aiming and not is_jumping and not is_firing:
			play_animation("idle")

	handle_shooting(delta)
	move_and_slide()

	if was_airborne and is_on_floor():
		current_jumps = max_jumps
		if landing_velocity > 500:
			play_jump_particles()
		landing_velocity = 0

	# --- Stew Buff & Super Mode Logic ---
	if is_super_mode:
		super_mode_timer -= delta
		super_mode_timer_changed.emit(super_mode_timer, SUPER_MODE_DURATION) # Update HUD timer
		
		if super_mode_timer <= 0:
			is_super_mode = false
			super_mode_deactivated.emit() # Tell HUD to revert back to normal
			stew_buff_changed.emit(stew_bars, max_stew_bars) # Reset visual empty bar
	else:
		# Normal stew drain logic
		if stew_bars > 0:
			current_stew_timer -= delta
			if current_stew_timer <= 0:
				stew_bars -= 1
				stew_buff_changed.emit(stew_bars, max_stew_bars)
				if stew_bars > 0:
					current_stew_timer = time_per_bar 
				else:
					current_stew_timer = 0.0 

func activate_super_mode():
	is_super_mode = true
	super_mode_timer = SUPER_MODE_DURATION
	stew_bars = 0 
	super_mode_activated.emit(SUPER_MODE_DURATION)

func handle_shooting(_delta):
	if Input.is_action_just_pressed("shoot") and can_shoot:
		is_aiming = true
		is_firing = true
		beginfire_finished = false
		update_trajectory()
		trajectory_line.show()
		play_animation("beginfire")

	elif Input.is_action_pressed("shoot") and is_aiming:
		if sprite.animation == "beginfire" and beginfire_finished:
			play_animation("holdfire")
		look_at_mouse()
		update_trajectory()
		velocity.x *= 0.5

	if Input.is_action_just_released("shoot") and is_aiming:
		is_aiming = false
		trajectory_line.hide()
		sprite.rotation = 0
		play_animation("endfire")
		shoot_arrow()

func play_jump_particles():
	if sprite and sprite.has_node("GPUParticles2D"):
		var particles = sprite.get_node("GPUParticles2D")
		particles.global_position = global_position + Vector2(0, 0)
		var mat = particles.process_material
		if mat:
			mat.direction = Vector3(0, -1, 0)
			mat.spread = 35
			mat.initial_velocity_min = 40
			mat.initial_velocity_max = 100
			mat.gravity = Vector3(0, 250, 0)
		particles.modulate = Color(0.42, 0.30, 0.18)
		particles.restart()
		particles.emitting = true

func get_aim_direction() -> Vector2:
	var bow_pos = get_bow_position()
	var mouse_pos = get_global_mouse_position()
	var to_mouse = mouse_pos - bow_pos
	if to_mouse.length() < AIM_DEAD_ZONE:
		return last_aim_direction
	var facing_left = sprite.flip_h
	var angle = atan2(to_mouse.y, abs(to_mouse.x))
	angle = clamp(angle, deg_to_rad(MAX_AIM_UP), deg_to_rad(MAX_AIM_DOWN))
	var dir = Vector2(cos(angle), sin(angle))
	if facing_left:
		dir.x = -dir.x
	last_aim_direction = dir
	return dir

func look_at_mouse():
	var mouse_pos = get_global_mouse_position()
	sprite.flip_h = mouse_pos.x < global_position.x
	if sprite.flip_h:
		sprite.position.x = left_facing_position
	else:
		sprite.position.x = right_facing_position

	var aim_dir = get_aim_direction()
	var tilt_angle = atan2(aim_dir.y, abs(aim_dir.x))
	if sprite.flip_h:
		sprite.rotation = -tilt_angle
	else:
		sprite.rotation = tilt_angle

func update_trajectory():
	var aim_dir = get_aim_direction()
	var velocity_vector = aim_dir * SHOOT_POWER
	var effective_gravity = gravity * ARROW_GRAVITY_SCALE
	var points = []
	var start_pos = get_bow_position() 
	for i in range(TRAJECTORY_POINTS):
		var time = i * TRAJECTORY_TIME_STEP
		var x = velocity_vector.x * time
		var y = velocity_vector.y * time + (0.5 * effective_gravity * time * time)
		points.append(start_pos + Vector2(x, y))
	trajectory_line.points = points

func shoot_arrow():
	if not can_shoot:
		return
	can_shoot = false
	
	# --- Super Arrow Check ---
	var arrow: Node2D
	if is_super_mode and super_arrow_scene:
		arrow = super_arrow_scene.instantiate()
	elif arrow_scene:
		arrow = arrow_scene.instantiate()
	else:
		can_shoot = true
		return
		
	get_parent().add_child(arrow)
	arrow.global_position = get_bow_position()
	var aim_dir = get_aim_direction()
	arrow.linear_velocity = aim_dir * SHOOT_POWER
	arrow.rotation = aim_dir.angle()
	arrow.add_collision_exception_with(self)
	await get_tree().create_timer(SHOOT_COOLDOWN).timeout
	can_shoot = true

func get_bow_position() -> Vector2:
	if sprite and sprite.has_node("BowMarker"):
		return sprite.get_node("BowMarker").global_position
	return global_position

func flip_sprite(direction: float):
	if direction > 0:
		sprite.flip_h = false
		sprite.position.x = right_facing_position 
	elif direction < 0:
		sprite.flip_h = true
		sprite.position.x = left_facing_position

func play_animation(anim_name: String):
	if sprite and sprite.animation != anim_name:
		sprite.play(anim_name)

func _on_animation_finished():
	if sprite.animation == "beginfire":
		beginfire_finished = true
	elif sprite.animation == "endfire":
		is_firing = false 

func take_damage(amount: int):
	health -= amount
	health_changed.emit(health, max_health)
	if sprite:
		var tween = create_tween()
		sprite.modulate = Color(1, 0, 0)
		tween.tween_property(sprite, "modulate", Color.WHITE, 0.2)
	if health <= 0:
		die()

func heal(amount: int):
	if health < max_health:
		health += amount
		if health > max_health:
			health = max_health
		health_changed.emit(health, max_health)
		if sprite:
			var tween = create_tween()
			sprite.modulate = Color(0, 1, 0) 
			tween.tween_property(sprite, "modulate", Color.WHITE, 0.2)

func consume_stew(heal_amount: int, bars_to_add: int):
	heal(heal_amount)
	stew_bars += bars_to_add
	if stew_bars > max_stew_bars:
		stew_bars = max_stew_bars
		
	current_stew_timer = time_per_bar 
	stew_buff_changed.emit(stew_bars, max_stew_bars) 

func die():
	health = max_health
	health_changed.emit(health, max_health)
	velocity = Vector2.ZERO
	global_position = respawn_position
	is_respawning = true
	await get_tree().create_timer(1.0).timeout
	is_respawning = false

func add_to_inventory(item: String, amount: int):
	if inventory.has(item):
		inventory[item] += amount
	else:
		inventory[item] = amount
	if item == "mushroom":
		update_ui()

func get_inventory_count(item: String) -> int:
	if inventory.has(item):
		return inventory[item]
	return 0

func update_ui():
	mushrooms_changed.emit(get_inventory_count("mushroom"))

func set_respawn_point(new_pos: Vector2):
	respawn_position = new_pos

func drop_all_items(item: String) -> int:
	var dropped_amount = 0
	if inventory.has(item):
		dropped_amount = inventory[item]
		inventory[item] = 0
	if item == "mushroom":
		update_ui()
	return dropped_amount

func drop_amount(item: String, amount: int) -> int:
	var actual_drop = 0
	if inventory.has(item):
		actual_drop = min(inventory[item], amount)
		inventory[item] -= actual_drop
	if item == "mushroom":
		update_ui()
	return actual_drop
