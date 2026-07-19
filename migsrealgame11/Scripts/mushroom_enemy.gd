extends CharacterBody2D

enum State { PATROL, CHASE }
var state = State.PATROL

# --- NEW: Health System ---
@export var max_health := 20 # Takes 2 hits from a 10-damage arrow
var health := max_health

@export var patrol_speed := 65.0
@export var chase_speed := 145.0
@export var jump_velocity := -450.0
@export var gravity := 900.0

@export var chase_duration := 5.0
@export var stop_jump_distance := 40.0

@export var attack_range := 30.0
@export var attack_cooldown := 1.0

@export var ledge_grace_time := 0.15
@export var max_wall_stuck_time := 0.8

var direction := 1
var player: Node2D = null

var chase_timer := 0.0
var direction_cooldown := 0.0
var jump_cooldown := 0.0
var attack_timer := 0.0

var turn_locked := false
var is_attacking := false
var is_stunned := false # NEW: Tracks if the enemy is in hit-stun

var ledge_timer := 0.0
var wall_stuck_timer := 0.0
var attempted_wall_jump := false

var ledge_start_pos := Vector2.ZERO
var wall_start_pos := Vector2.ZERO

@onready var vision_area: Area2D = $VisionArea
@onready var ledge_check: RayCast2D = $LedgeCheck
@onready var wall_check: RayCast2D = $WallCheck
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready():
	vision_area.body_entered.connect(_on_vision_entered)
	vision_area.body_exited.connect(_on_vision_exited)

	ledge_start_pos = ledge_check.position
	wall_start_pos = wall_check.position

	ledge_check.exclude_parent = true
	wall_check.exclude_parent = true

func _physics_process(delta):
	if !is_on_floor():
		velocity.y += gravity * delta

	# --- NEW: Hit Stun Freeze ---
	# If stunned, apply gravity and slide, but completely skip all AI and animations
	if is_stunned:
		move_and_slide()
		return

	if direction_cooldown > 0:
		direction_cooldown -= delta
	else:
		turn_locked = false

	if jump_cooldown > 0:
		jump_cooldown -= delta

	if attack_timer > 0:
		attack_timer -= delta

	match state:
		State.PATROL:
			_patrol(delta)
		State.CHASE:
			_chase(delta)

	_update_raycasts()
	_update_animation()

	move_and_slide()

func _patrol(delta):
	if is_attacking:
		return

	velocity.x = direction * patrol_speed

	if turn_locked:
		return

	if wall_check.is_colliding():
		var hit = wall_check.get_collider()
		if hit != player:
			if !attempted_wall_jump and is_on_floor() and jump_cooldown <= 0:
				velocity.y = jump_velocity
				velocity.x = direction * (patrol_speed + 40)
				jump_cooldown = 0.8
				attempted_wall_jump = true
				wall_stuck_timer = 0
			else:
				wall_stuck_timer += delta
				if wall_stuck_timer >= max_wall_stuck_time:
					_flip_direction()
					attempted_wall_jump = false
					wall_stuck_timer = 0
	else:
		wall_stuck_timer = 0
		attempted_wall_jump = false

	if is_on_floor():
		if !ledge_check.is_colliding():
			ledge_timer += delta
			if ledge_timer >= ledge_grace_time:
				_flip_direction()
				ledge_timer = 0
		else:
			ledge_timer = 0

func _chase(delta):
	if is_attacking:
		velocity.x = 0
		return

	if player == null:
		chase_timer -= delta
		if chase_timer <= 0:
			state = State.PATROL
		return

	chase_timer = chase_duration

	var diff = player.global_position.x - global_position.x
	var distance = abs(diff)

	if distance > 12:
		var new_dir = sign(diff)
		if new_dir != direction and !turn_locked:
			direction = new_dir
			direction_cooldown = 0.25
			turn_locked = true

	if distance <= attack_range and attack_timer <= 0:
		_start_attack()
		return

	velocity.x = direction * chase_speed

	if distance <= stop_jump_distance:
		return

	if is_on_floor() and jump_cooldown <= 0:
		if wall_check.is_colliding():
			var hit = wall_check.get_collider()
			if hit != player:
				velocity.y = jump_velocity
				velocity.x = direction * (chase_speed + 40)
				jump_cooldown = 0.8
		elif !ledge_check.is_colliding():
			velocity.y = jump_velocity
			jump_cooldown = 0.8

func _start_attack():
	is_attacking = true
	velocity.x = 0
	attack_timer = attack_cooldown
	sprite.play("attack")
	
	await sprite.animation_finished
	
	# Once animation is done, they can move again
	is_attacking = false

func _flip_direction():
	if turn_locked:
		return
	direction *= -1
	direction_cooldown = 0.4
	turn_locked = true

func _update_raycasts():
	ledge_check.position.x = abs(ledge_start_pos.x) * direction
	ledge_check.position.y = ledge_start_pos.y

	wall_check.position.x = abs(wall_start_pos.x) * direction
	wall_check.position.y = wall_start_pos.y

	ledge_check.target_position.x = abs(ledge_check.target_position.x) * direction
	wall_check.target_position.x = abs(wall_check.target_position.x) * direction

func _update_animation():
	sprite.flip_h = direction > 0

	if is_attacking:
		return

	if abs(velocity.x) > 5 and is_on_floor():
		if sprite.animation != "running":
			sprite.play("running")
	else:
		if sprite.animation != "idle":
			sprite.play("idle")

func _on_vision_entered(body):
	if body.is_in_group("player"):
		player = body
		state = State.CHASE
		chase_timer = chase_duration

		wall_check.add_exception(player)
		ledge_check.add_exception(player)

func _on_vision_exited(body):
	if body == player:
		wall_check.remove_exception(player)
		ledge_check.remove_exception(player)
		player = null

func take_damage(amount):
	# Apply damage
	health -= amount
	
	# Die if health is depleted
	if health <= 0:
		queue_free()
		return
	
	# --- NEW: Stun & Hit Animation Logic ---
	is_stunned = true
	is_attacking = false # Break them out of the attack state if interrupted!
	velocity.x = 0
	
	# Play hit animation
	sprite.play("hit")
	
	# Create a tween to handle the red flicker effect safely
	var tween = create_tween()
	
	# Instantly turn the sprite red
	sprite.modulate = Color(1, 0, 0)
	
	# Smoothly transition back to normal (white) over 0.2 seconds
	tween.tween_property(sprite, "modulate", Color(1, 1, 1), 0.2)
	
	# Wait for 1/3 of a second before un-stunning
	await get_tree().create_timer(0.33).timeout
	
	# End the stun
	is_stunned = false
