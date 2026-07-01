extends CharacterBody2D

enum State { PATROL, CHASE }
var state = State.PATROL

@export var patrol_speed := 65.0
@export var chase_speed := 140.0
@export var jump_velocity := -420.0
@export var gravity := 900.0
@export var chase_duration := 5.0
@export var patrol_walk_time := 4.0
@export var stop_distance := 18.0

var direction := 1
var player: Node2D = null
var chase_timer := 0.0
var patrol_timer := 0.0
var direction_cooldown := 0.0
var jump_cooldown := 0.0
var jump_locked := false

@onready var vision_area: Area2D = $VisionArea
@onready var ledge_check: RayCast2D = $LedgeCheck
@onready var wall_check: RayCast2D = $WallCheck
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D


func _ready():
	patrol_timer = patrol_walk_time
	vision_area.body_entered.connect(_on_vision_entered)
	vision_area.body_exited.connect(_on_vision_exited)


func _physics_process(delta):

	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		# reset jump lock when grounded
		jump_locked = false

	if direction_cooldown > 0.0:
		direction_cooldown -= delta

	if jump_cooldown > 0.0:
		jump_cooldown -= delta

	match state:
		State.PATROL:
			_patrol(delta)

		State.CHASE:
			_chase(delta)

	_update_raycasts()
	_update_animation()
	move_and_slide()


func _patrol(delta):
	velocity.x = direction * patrol_speed
	patrol_timer -= delta

	if patrol_timer <= 0.0 or (wall_check.is_colliding() and direction_cooldown <= 0.0):
		direction *= -1
		patrol_timer = patrol_walk_time
		direction_cooldown = 0.5


func _chase(delta):

	# Keep chasing after losing sight
	if player == null:
		chase_timer -= delta

		if chase_timer <= 0.0:
			state = State.PATROL
			patrol_timer = patrol_walk_time
			return

	var target_x = global_position.x

	if player != null:
		chase_timer = chase_duration
		target_x = player.global_position.x

	var diff = target_x - global_position.x
	var distance = abs(diff)

	# Face player
	if distance > 8.0 and direction_cooldown <= 0.0:
		var new_dir = sign(diff)

		if new_dir != direction:
			direction = new_dir
			direction_cooldown = 0.2

	# Stop close
	if player != null and distance <= stop_distance:
		velocity.x = 0
		return

	velocity.x = direction * chase_speed

	# -------------------------------
	# FIXED JUMP SYSTEM (NO SPAM)
	# -------------------------------
	if is_on_floor() and jump_cooldown <= 0.0 and not jump_locked:

		var should_jump := false

		if wall_check.is_colliding():
			var hit = wall_check.get_collider()
			if hit != player:
				should_jump = true

		elif not ledge_check.is_colliding():
			should_jump = true

		if should_jump:
			velocity.y = jump_velocity
			jump_cooldown = 0.8
			jump_locked = true


func _update_raycasts():
	ledge_check.position.x = abs(ledge_check.position.x) * direction
	wall_check.position.x = abs(wall_check.position.x) * direction

	var ledge_dist: float = abs(ledge_check.target_position.x)
	var wall_dist: float = abs(wall_check.target_position.x)

	ledge_check.target_position.x = ledge_dist * direction
	wall_check.target_position.x = wall_dist * direction


func _update_animation():
	sprite.flip_h = direction == 1

	if abs(velocity.x) > 1.0:
		sprite.play("running")
	else:
		sprite.play("idle")


func _on_vision_entered(body):
	if body.is_in_group("player"):
		player = body
		state = State.CHASE
		chase_timer = chase_duration


func _on_vision_exited(body):
	if body == player:
		player = null
