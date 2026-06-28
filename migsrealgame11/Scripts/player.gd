extends CharacterBody2D

const SPEED = 300.0
const JUMP_VELOCITY = -400.0
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

# Shooting
const SHOOT_POWER = 1200
const TRAJECTORY_POINTS = 30
const TRAJECTORY_TIME_STEP = 0.07
const TRAJECTORY_WIDTH = 2.5
const ARROW_GRAVITY_SCALE = 1.0
const SHOOT_COOLDOWN = 0.05

# Aim
const MAX_AIM_UP = -35
const MAX_AIM_DOWN = 35
const AIM_DEAD_ZONE = 30.0

@export var arrow_scene: PackedScene

# Camera zoom
@onready var camera = $Camera2D
var target_zoom = Vector2.ONE

const ZOOM_SPEED = 18.0
const MIN_ZOOM = 0.15
const MAX_ZOOM = 1.40
const ZOOM_STEP = 0.03

# Jump helpers
const COYOTE_TIME = 0.1
var coyote_timer = 0.0

const JUMP_BUFFER_TIME = 0.1
var jump_buffer_timer = 0.0

var double_jump_available = false
var landing_velocity = 0.0

# Animation
var is_jumping = false

# Shooting state
var is_aiming = false
var is_firing = false
var beginfire_finished = false

var can_shoot = true
var shot_locked = false

var last_aim_direction: Vector2 = Vector2.RIGHT

var trajectory_line: Line2D
var trajectory_container: Node2D

# Inventory
var inventory = {
	"mushroom": 0
}

func _ready():
	target_zoom = camera.zoom

	var sprite = get_sprite_node()

	if sprite:
		if sprite.has_node("TrajectoryContainer"):
			trajectory_container = sprite.get_node("TrajectoryContainer")
		else:
			trajectory_container = Node2D.new()
			trajectory_container.name = "TrajectoryContainer"
			sprite.add_child(trajectory_container)

		update_trajectory_container_position()

		trajectory_line = Line2D.new()
		trajectory_line.width = TRAJECTORY_WIDTH
		trajectory_line.default_color = Color.RED
		trajectory_container.add_child(trajectory_line)
		trajectory_line.hide()

		if sprite is AnimatedSprite2D:
			sprite.animation_finished.connect(_on_animation_finished)

func _input(event):
	if event.is_action_pressed("zoom_in"):
		target_zoom = camera.zoom - Vector2.ONE * ZOOM_STEP

	if event.is_action_pressed("zoom_out"):
		target_zoom = camera.zoom + Vector2.ONE * ZOOM_STEP

	target_zoom.x = clamp(target_zoom.x, MIN_ZOOM, MAX_ZOOM)
	target_zoom.y = clamp(target_zoom.y, MIN_ZOOM, MAX_ZOOM)

func _physics_process(delta):
	var was_airborne = not is_on_floor()

	# Gravity
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

	# Jump buffer
	if Input.is_action_just_pressed("ui_accept"):
		jump_buffer_timer = JUMP_BUFFER_TIME

	if jump_buffer_timer > 0:
		jump_buffer_timer -= delta

	# First jump
	if jump_buffer_timer > 0 and (is_on_floor() or coyote_timer > 0):
		velocity.y = JUMP_VELOCITY
		jump_buffer_timer = 0
		coyote_timer = 0
		is_jumping = true

		if not is_aiming and not is_firing:
			play_animation("jump")

	# Double jump
	elif Input.is_action_just_pressed("ui_accept") and not is_on_floor() and double_jump_available and coyote_timer <= 0:
		velocity.y = JUMP_VELOCITY
		double_jump_available = false
		is_jumping = true

		if not is_aiming and not is_firing:
			play_animation("jump")

	# Movement
	var direction = Input.get_axis("left", "right")

	if direction != 0:
		velocity.x = direction * SPEED

		if not is_aiming:
			flip_sprite(direction)

		if not is_aiming and not is_jumping:
			play_animation("walk")
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED * delta * 8)

		if not is_aiming and not is_jumping:
			play_animation("idle")

	handle_shooting(delta)

	move_and_slide()

	update_camera_zoom(delta)

	# Landing check
	if was_airborne and is_on_floor():
		if landing_velocity > 500:
			play_jump_particles()

		landing_velocity = 0

func update_camera_zoom(delta):
	camera.zoom = camera.zoom.lerp(target_zoom, ZOOM_SPEED * delta)

	if camera.zoom.distance_to(target_zoom) < 0.001:
		camera.zoom = target_zoom

func handle_shooting(_delta):
	if Input.is_action_just_pressed("shoot") and can_shoot:
		is_aiming = true
		is_firing = true
		beginfire_finished = false
		shot_locked = false

		update_trajectory_container_position()
		update_trajectory()
		trajectory_line.show()

		play_animation("beginfire")

	elif Input.is_action_pressed("shoot") and is_aiming:
		var sprite = get_sprite_node()

		if sprite.animation == "beginfire" and beginfire_finished:
			play_animation("holdfire")

		look_at_mouse()
		update_trajectory_container_position()
		update_trajectory()

		velocity.x *= 0.5

	if Input.is_action_just_released("shoot") and is_aiming and not shot_locked:
		shot_locked = true
		play_animation("endfire")

		await get_tree().create_timer(0.3).timeout

		if can_shoot:
			shoot_arrow()

		is_aiming = false
		is_firing = false

		trajectory_line.hide()

		var sprite = get_sprite_node()
		sprite.rotation = 0

		if trajectory_container:
			trajectory_container.rotation = 0

func play_jump_particles():
	var sprite = get_sprite_node()

	if sprite and sprite.has_node("GPUParticles2D"):
		var particles = sprite.get_node("GPUParticles2D")

		particles.global_position = global_position + Vector2(0, 7.5)

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

	var sprite = get_sprite_node()
	var facing_left = sprite.flip_h

	var angle = atan2(to_mouse.y, abs(to_mouse.x))
	angle = clamp(angle, deg_to_rad(MAX_AIM_UP), deg_to_rad(MAX_AIM_DOWN))

	var dir = Vector2(cos(angle), sin(angle))

	if facing_left:
		dir.x = -dir.x

	last_aim_direction = dir
	return dir

func look_at_mouse():
	var sprite = get_sprite_node()
	var mouse_pos = get_global_mouse_position()

	sprite.flip_h = mouse_pos.x < global_position.x

	update_trajectory_container_position()

	var aim_dir = get_aim_direction()

	if sprite.flip_h:
		sprite.rotation = PI + aim_dir.angle()
	else:
		sprite.rotation = aim_dir.angle()

func update_trajectory():
	var aim_dir = get_aim_direction()
	var velocity_vector = aim_dir * SHOOT_POWER
	var effective_gravity = gravity * ARROW_GRAVITY_SCALE

	var points = []

	for i in range(TRAJECTORY_POINTS):
		var time = i * TRAJECTORY_TIME_STEP
		var x = velocity_vector.x * time
		var y = velocity_vector.y * time + (0.5 * effective_gravity * time * time)

		points.append(Vector2(x, y))

	var sprite = get_sprite_node()

	if sprite and trajectory_container:
		trajectory_container.rotation = -sprite.rotation

	trajectory_line.points = points

func shoot_arrow():
	if arrow_scene == null or not can_shoot:
		return

	can_shoot = false

	var arrow = arrow_scene.instantiate()
	get_parent().add_child(arrow)

	arrow.global_position = get_bow_position()

	var aim_dir = get_aim_direction()

	arrow.linear_velocity = aim_dir * SHOOT_POWER
	arrow.rotation = aim_dir.angle()
	arrow.add_collision_exception_with(self)

	await get_tree().create_timer(SHOOT_COOLDOWN).timeout
	can_shoot = true

func get_bow_position() -> Vector2:
	var sprite = get_sprite_node()

	if sprite.has_node("BowMarker"):
		return sprite.get_node("BowMarker").global_position

	return global_position

func update_trajectory_container_position():
	var sprite = get_sprite_node()

	if sprite.has_node("BowMarker") and trajectory_container:
		trajectory_container.position = sprite.get_node("BowMarker").position

func flip_sprite(direction: float):
	var sprite = get_sprite_node()

	if direction > 0:
		sprite.flip_h = false
	elif direction < 0:
		sprite.flip_h = true

	update_trajectory_container_position()

func play_animation(anim_name: String):
	var sprite = get_sprite_node()

	if sprite.animation != anim_name:
		sprite.play(anim_name)

func _on_animation_finished():
	var sprite = get_sprite_node()

	if sprite.animation == "beginfire":
		beginfire_finished = true

func get_sprite_node():
	if has_node("AnimatedSprite2D"):
		return $AnimatedSprite2D

	return null
