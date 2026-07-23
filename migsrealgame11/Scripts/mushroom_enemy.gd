extends CharacterBody2D

enum State { PATROL, CHASE }
var state = State.PATROL

# --- Health System ---
@export var max_health := 20
var health := max_health

# --- Drop System ---
@export var drop_scene: PackedScene # Drag your mushroompickup.tscn here in the editor!

@export var patrol_speed := 65.0
@export var chase_speed := 145.0
@export var jump_velocity := -450.0
@export var gravity := 900.0

@export var chase_duration := 5.0
@export var stop_jump_distance := 40.0

@export var attack_range := 30.0
@export var attack_cooldown := 1.0
@export var attack_damage := 10 # How much damage the enemy deals
@export var attack_hit_delay := 0.4 # Configurable delay before hitbox activates

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
var is_stunned := false 

var ledge_timer := 0.0
var wall_stuck_timer := 0.0
var attempted_wall_jump := false

var ledge_start_pos := Vector2.ZERO
var wall_start_pos := Vector2.ZERO

@onready var vision_area: Area2D = $VisionArea
@onready var ledge_check: RayCast2D = $LedgeCheck
@onready var wall_check: RayCast2D = $WallCheck
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var alert_anim: AnimatedSprite2D = $Alert/AlertAnimation

# --- The Hitbox ---
@onready var hitbox: Area2D = $HitboxArea

func _ready():
	vision_area.body_entered.connect(_on_vision_entered)
	vision_area.body_exited.connect(_on_vision_exited)
	
	# Connect the hitbox signal
	hitbox.body_entered.connect(_on_hitbox_body_entered)
	# Turn it off by default so it doesn't hurt the player while walking
	hitbox.monitoring = false

	ledge_start_pos = ledge_check.position
	wall_start_pos = wall_check.position

	ledge_check.exclude_parent = true
	wall_check.exclude_parent = true
	
	alert_anim.hide()

func _physics_process(delta):
	if !is_on_floor():
		velocity.y += gravity * delta

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
	
	# 1. Wait for your configured delay (the wind-up of the attack)
	await get_tree().create_timer(attack_hit_delay).timeout
	
	# 2. Safety Check: Make sure the enemy wasn't stunned or killed during the wind-up
	if is_attacking:
		hitbox.monitoring = true # Turn the hitbox ON at the exact moment of impact!
	
	# 3. Wait for the rest of the animation to finish
	await sprite.animation_finished
	
	# 4. Turn the hitbox OFF when the attack ends!
	hitbox.monitoring = false
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
	
	# --- FIXED: Flips the whole hitbox node based on direction! ---
	if hitbox:
		hitbox.scale.x = direction

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
		if state != State.CHASE:
			_show_alert()
			
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

func _show_alert():
	alert_anim.show()
	alert_anim.play("alert")
	await alert_anim.animation_finished
	alert_anim.hide() 

# --- When the hitbox touches a body during the attack ---
func _on_hitbox_body_entered(body):
	if body.is_in_group("player"):
		if body.has_method("take_damage"):
			body.take_damage(attack_damage)

func take_damage(amount, _attacker_x = null):
	health -= amount
	
	is_stunned = true
	is_attacking = false
	velocity.x = 0
	
	# Safety measure: if we get stunned mid-attack, turn the hitbox off!
	hitbox.monitoring = false
	
	sprite.play("hit")
	
	var tween = create_tween()
	sprite.modulate = Color(1, 0, 0)
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.2)
	
	await sprite.animation_finished
	is_stunned = false
	
	if health <= 0:
		die()

func die():
	if drop_scene != null:
		var drop = drop_scene.instantiate()
		drop.global_position = global_position
		get_tree().current_scene.add_child(drop)
		
	queue_free()
