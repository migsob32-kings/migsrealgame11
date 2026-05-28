extends CharacterBody2D

# =========================
# MOVEMENT
# =========================
const SPEED = 300.0
const JUMP_VELOCITY = -400.0

var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

# =========================
# SHOOTING
# =========================
const SHOOT_POWER = 1200
const TRAJECTORY_POINTS = 15
const TRAJECTORY_WIDTH = 2.5

# AIM LIMITS
const MAX_AIM_UP = -35
const MAX_AIM_DOWN = 35

@export var arrow_scene: PackedScene

# =========================
# TIMERS
# =========================
const COYOTE_TIME = 0.1
var coyote_timer = 0.0

const JUMP_BUFFER_TIME = 0.1
var jump_buffer_timer = 0.0

# =========================
# ANIMATION
# =========================
var was_on_floor_last_frame = false
var landing_tween: Tween
var is_jumping = false

# =========================
# SHOOTING STATE
# =========================
var is_aiming = false
var is_firing = false

var trajectory_line: Line2D
var trajectory_container: Node2D

# =========================
# READY
# =========================
func _ready():

	var sprite = get_sprite_node()

	if sprite:

		# Create/find trajectory container
		if sprite.has_node("TrajectoryContainer"):
			trajectory_container = sprite.get_node("TrajectoryContainer")
		else:
			trajectory_container = Node2D.new()
			trajectory_container.name = "TrajectoryContainer"
			sprite.add_child(trajectory_container)

		update_trajectory_container_position()

		# Create trajectory line
		trajectory_line = Line2D.new()
		trajectory_line.width = TRAJECTORY_WIDTH
		trajectory_line.default_color = Color.RED

		trajectory_container.add_child(trajectory_line)

		trajectory_line.hide()

# =========================
# PHYSICS
# =========================
func _physics_process(delta):

	var just_landed = is_on_floor() and not was_on_floor_last_frame and velocity.y > 0

	# Gravity
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

	# Jump buffer
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

	# Movement
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

# =========================
# SHOOTING
# =========================
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

		look_at_mouse()

		update_trajectory()

		velocity.x *= 0.5

	if Input.is_action_just_released("shoot") and is_aiming:

		play_animation("endfire")

		await get_tree().create_timer(0.3).timeout

		shoot_arrow()

		is_aiming = false
		is_firing = false

		trajectory_line.hide()

		var sprite = get_sprite_node()

		if sprite:
			sprite.rotation = 0

		if trajectory_container:
			trajectory_container.rotation = 0

		var direction = Input.get_axis("left", "right")

		if direction != 0:
			play_animation("walk")
		else:
			play_animation("idle")

# =========================
# AIMING
# =========================
func look_at_mouse():

	var bow_pos = get_bow_position()
	var mouse_pos = get_global_mouse_position()

	var direction = mouse_pos - bow_pos

	var sprite = get_sprite_node()

	if not sprite:
		return

	# LOCALIZED AIM ANGLE
	# This prevents weird flipping/twitching
	var angle = atan2(direction.y, abs(direction.x))

	# HARD LIMITS
	var max_up = deg_to_rad(MAX_AIM_UP)
	var max_down = deg_to_rad(MAX_AIM_DOWN)

	# Clamp aim
	angle = clamp(angle, max_up, max_down)

	# Apply facing direction
	if sprite.flip_h:
		sprite.rotation = PI - angle
	else:
		sprite.rotation = angle

	# Rotate trajectory too
	if trajectory_container:
		trajectory_container.rotation = sprite.rotation

# =========================
# TRAJECTORY
# =========================
func update_trajectory():

	var sprite = get_sprite_node()

	if not sprite:
		return

	var direction = Vector2.RIGHT.rotated(sprite.rotation)

	direction = direction.normalized()

	var velocity_vector = direction * SHOOT_POWER

	var points = []

	var time_step = 0.05

	for i in range(TRAJECTORY_POINTS):

		var time = i * time_step

		var x = velocity_vector.x * time
		var y = velocity_vector.y * time + 0.5 * gravity * time * time

		points.append(Vector2(x, y))

	trajectory_line.points = points

# =========================
# SHOOT ARROW
# =========================
func shoot_arrow():

	if arrow_scene == null:
		print("ERROR: Arrow scene not set!")
		return

	var arrow = arrow_scene.instantiate()

	get_parent().add_child(arrow)

	var bow_pos = get_bow_position()

	arrow.global_position = bow_pos

	var sprite = get_sprite_node()

	if not sprite:
		return

	var direction = Vector2.RIGHT.rotated(sprite.rotation)

	direction = direction.normalized()

	var velocity_vector = direction * SHOOT_POWER

	arrow.linear_velocity = velocity_vector

	arrow.rotation = direction.angle()

	arrow.add_collision_exception_with(self)

# =========================
# BOW POSITION
# =========================
func get_bow_position() -> Vector2:

	var sprite = get_sprite_node()

	if sprite and sprite.has_node("BowMarker"):
		return sprite.get_node("BowMarker").global_position

	return global_position

func update_trajectory_container_position():

	var sprite = get_sprite_node()

	if sprite and sprite.has_node("BowMarker") and trajectory_container:

		var bow_marker = sprite.get_node("BowMarker")

		trajectory_container.position = bow_marker.position

# =========================
# LANDING SQUASH
# =========================
func play_landing_squash():

	if landing_tween:
		landing_tween.kill()

	landing_tween = create_tween()

	landing_tween.tween_method(
		set_sprite_scale,
		Vector2(1, 1),
		Vector2(1.3, 0.7),
		0.1
	)

	landing_tween.tween_method(
		set_sprite_scale,
		Vector2(1.3, 0.7),
		Vector2(1, 1),
		0.2
	)

	landing_tween.set_ease(Tween.EASE_OUT)
	landing_tween.set_trans(Tween.TRANS_ELASTIC)

func set_sprite_scale(new_scale: Vector2):

	var sprite = get_sprite_node()

	if sprite:
		sprite.scale = new_scale

# =========================
# FLIP SPRITE
# =========================
func flip_sprite(direction: float):

	var sprite = get_sprite_node()

	if not sprite:
		return

	if direction > 0:
		sprite.flip_h = false

	elif direction < 0:
		sprite.flip_h = true

	update_trajectory_container_position()

# =========================
# ANIMATION
# =========================
func play_animation(anim_name: String):

	var sprite = get_sprite_node()

	if sprite and sprite is AnimatedSprite2D:

		if sprite.animation != anim_name:
			sprite.play(anim_name)

# =========================
# GET SPRITE NODE
# =========================
func get_sprite_node():

	if has_node("AnimatedSprite2D"):
		return $AnimatedSprite2D

	elif has_node("Sprite2D"):
		return $Sprite2D

	for child in get_children():

		if child is AnimatedSprite2D or child is Sprite2D:
			return child

	return null
