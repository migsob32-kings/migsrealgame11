extends CharacterBody2D

# Movement constants
const SPEED = 300.0
const JUMP_VELOCITY = -400.0

# Shooting constants
const SHOOT_POWER = 800.0
const TRAJECTORY_POINTS = 30

var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

# Timers
const COYOTE_TIME = 0.1
var coyote_timer = 0.0
const JUMP_BUFFER_TIME = 0.1
var jump_buffer_timer = 0.0

# Animation
var was_on_floor_last_frame = false
var landing_tween: Tween

# Shooting
var is_aiming = false
var trajectory_line: Line2D

@export var arrow_scene: PackedScene

func _ready():
	# Create trajectory line
	trajectory_line = Line2D.new()
	trajectory_line.width = 3
	trajectory_line.default_color = Color.RED
	add_child(trajectory_line)
	trajectory_line.hide()

func _physics_process(delta):
	var just_landed = is_on_floor() and not was_on_floor_last_frame and velocity.y > 0
	
	# Gravity
	if not is_on_floor():
		velocity.y += gravity * delta
		coyote_timer -= delta
	else:
		coyote_timer = COYOTE_TIME
	
	if just_landed:
		play_landing_squash()
	
	was_on_floor_last_frame = is_on_floor()
	
	# Jump
	if Input.is_action_just_pressed("ui_accept"):
		jump_buffer_timer = JUMP_BUFFER_TIME
	
	if jump_buffer_timer > 0:
		jump_buffer_timer -= delta
	
	if jump_buffer_timer > 0 and (is_on_floor() or coyote_timer > 0):
		velocity.y = JUMP_VELOCITY
		jump_buffer_timer = 0.0
		coyote_timer = 0.0
	
	# Movement
	var direction = Input.get_axis("left", "right")
	if direction != 0:
		velocity.x = direction * SPEED
		flip_sprite(direction)
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED * delta * 8)
	
	# Shooting
	handle_shooting(delta)
	
	move_and_slide()

func handle_shooting(delta):
	# Show trajectory while aiming
	if Input.is_action_pressed("shoot"):
		is_aiming = true
		update_trajectory()
		trajectory_line.show()
	
	# Shoot instantly on release
	if Input.is_action_just_released("shoot") and is_aiming:
		shoot_arrow()
		is_aiming = false
		trajectory_line.hide()

func update_trajectory():
	var mouse_pos = get_global_mouse_position()
	var start_pos = global_position
	var direction = (mouse_pos - start_pos).normalized()
	var velocity_vector = direction * SHOOT_POWER
	
	var points = []
	var time_step = 0.05
	
	for i in range(TRAJECTORY_POINTS):
		var time = i * time_step
		var x = start_pos.x + velocity_vector.x * time
		var y = start_pos.y + velocity_vector.y * time + 0.5 * gravity * time * time
		var local_point = to_local(Vector2(x, y))
		points.append(local_point)
	
	trajectory_line.points = points

func shoot_arrow():
	if arrow_scene == null:
		print("ERROR: Arrow scene not set! Drag arrow.tscn to Inspector")
		return
	
	var arrow = arrow_scene.instantiate()
	get_parent().add_child(arrow)
	arrow.global_position = global_position
	
	var mouse_pos = get_global_mouse_position()
	var direction = (mouse_pos - global_position).normalized()
	var velocity_vector = direction * SHOOT_POWER
	
	arrow.linear_velocity = velocity_vector
	arrow.rotation = direction.angle()

func play_landing_squash():
	if landing_tween:
		landing_tween.kill()
	
	landing_tween = create_tween()
	landing_tween.tween_method(set_sprite_scale, Vector2(1, 1), Vector2(1.3, 0.7), 0.1)
	landing_tween.tween_method(set_sprite_scale, Vector2(1.3, 0.7), Vector2(1, 1), 0.2)
	landing_tween.set_ease(Tween.EASE_OUT)
	landing_tween.set_trans(Tween.TRANS_ELASTIC)

func set_sprite_scale(new_scale: Vector2):
	var sprite = get_sprite_node()
	if sprite:
		sprite.scale = new_scale

func flip_sprite(direction: float):
	var sprite = get_sprite_node()
	if sprite:
		if direction > 0:
			sprite.flip_h = false
		elif direction < 0:
			sprite.flip_h = true

func get_sprite_node():
	if has_node("Sprite2D"):
		return $Sprite2D
	elif has_node("AnimatedSprite2D"):
		return $AnimatedSprite2D
	for child in get_children():
		if child is Sprite2D or child is AnimatedSprite2D:
			return child
	return null
