extends CharacterBody2D

# Movement constants
const SPEED = 300.0
const JUMP_VELOCITY = -400.0

# Shooting constants
const SHOOT_POWER = 1200
const TRAJECTORY_POINTS = 30
const BOW_OFFSET_X = 38
const BOW_OFFSET_Y = -47

var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

# Timers
const COYOTE_TIME = 0.1
var coyote_timer = 0.0
const JUMP_BUFFER_TIME = 0.1
var jump_buffer_timer = 0.0

# Animation
var was_on_floor_last_frame = false
var landing_tween: Tween
var is_jumping = false

# Shooting
var is_aiming = false
var trajectory_line: Line2D
var is_firing = false

@export var arrow_scene: PackedScene

func _ready():
	trajectory_line = Line2D.new()
	trajectory_line.width = 3
	trajectory_line.default_color = Color.RED
	add_child(trajectory_line)
	trajectory_line.hide()

func _physics_process(delta):
	var just_landed = is_on_floor() and not was_on_floor_last_frame and velocity.y > 0
	
	if not is_on_floor():
		velocity.y += gravity * delta
		coyote_timer -= delta
		is_jumping = true
	else:
		coyote_timer = COYOTE_TIME
		is_jumping = false
	
	if just_landed:
		play_landing_squash()
	
	was_on_floor_last_frame = is_on_floor()
	
	if Input.is_action_just_pressed("ui_accept"):
		jump_buffer_timer = JUMP_BUFFER_TIME
	
	if jump_buffer_timer > 0:
		jump_buffer_timer -= delta
	
	if jump_buffer_timer > 0 and (is_on_floor() or coyote_timer > 0):
		velocity.y = JUMP_VELOCITY
		jump_buffer_timer = 0.0
		coyote_timer = 0.0
		is_jumping = true
		play_animation("jump")
	
	var direction = Input.get_axis("left", "right")
	if direction != 0:
		velocity.x = direction * SPEED
		flip_sprite(direction)
		if not is_aiming and not is_firing and not is_jumping:
			play_animation("walk")
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED * delta * 8)
		if not is_aiming and not is_firing and not is_jumping:
			play_animation("idle")
	
	handle_shooting(delta)
	
	move_and_slide()

func handle_shooting(delta):
	if Input.is_action_just_pressed("shoot"):
		is_aiming = true
		is_firing = true
		update_trajectory()
		trajectory_line.show()
		play_animation("beginfire")
	
	if Input.is_action_pressed("shoot") and is_aiming:
		var sprite = get_sprite_node()
		if sprite and sprite.animation != "holdfire":
			play_animation("holdfire")
		update_trajectory()
	
	if Input.is_action_just_released("shoot") and is_aiming:
		play_animation("endfire")
		await get_tree().create_timer(0.3).timeout
		shoot_arrow()
		is_aiming = false
		is_firing = false
		trajectory_line.hide()
		var direction = Input.get_axis("left", "right")
		if direction != 0:
			play_animation("walk")
		else:
			play_animation("idle")

func get_bow_position() -> Vector2:
	var offset_x = BOW_OFFSET_X
	var sprite = get_sprite_node()
	if sprite and sprite.flip_h:
		offset_x = -BOW_OFFSET_X + 18  # Changed from -10 to +5
	return global_position + Vector2(offset_x, BOW_OFFSET_Y)

func update_trajectory():
	var mouse_pos = get_global_mouse_position()
	var bow_pos = get_bow_position()
	
	var direction = (mouse_pos - bow_pos).normalized()
	var velocity_vector = direction * SHOOT_POWER
	
	var points = []
	var time_step = 0.05
	
	for i in range(TRAJECTORY_POINTS):
		var time = i * time_step
		var x = bow_pos.x + velocity_vector.x * time
		var y = bow_pos.y + velocity_vector.y * time + 0.5 * gravity * time * time
		var local_point = to_local(Vector2(x, y))
		points.append(local_point)
	
	trajectory_line.points = points

func shoot_arrow():
	if arrow_scene == null:
		print("ERROR: Arrow scene not set!")
		return
	
	var arrow = arrow_scene.instantiate()
	get_parent().add_child(arrow)
	
	var bow_pos = get_bow_position()
	arrow.global_position = bow_pos
	
	var mouse_pos = get_global_mouse_position()
	var direction = (mouse_pos - bow_pos).normalized()
	var velocity_vector = direction * SHOOT_POWER
	
	arrow.linear_velocity = velocity_vector
	arrow.rotation = direction.angle()
	arrow.add_collision_exception_with(self)

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

func play_animation(anim_name: String):
	var sprite = get_sprite_node()
	if sprite and sprite is AnimatedSprite2D:
		if sprite.animation != anim_name:
			sprite.play(anim_name)

func get_sprite_node():
	if has_node("Sprite2D"):
		return $Sprite2D
	elif has_node("AnimatedSprite2D"):
		return $AnimatedSprite2D
	for child in get_children():
		if child is Sprite2D or child is AnimatedSprite2D:
			return child
	return null
