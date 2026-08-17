extends CharacterBody2D

enum State { PATROL, CHASE }
var state = State.PATROL

# --- Health System ---
@export var max_health := 20
var health := max_health
var is_dead := false 

# --- Drop System ---
@export var drop_scene: PackedScene 

@export var patrol_speed := 65.0
@export var chase_speed := 145.0
@export var jump_velocity := -450.0
@export var gravity := 900.0

@export var chase_duration := 5.0
@export var stop_jump_distance := 40.0

# --- FIX 1: Range bumped to 70.0 so they swing before bumping! ---
@export var attack_range := 70.0 
@export var attack_cooldown := 1.0
@export var attack_damage := 10 
@export var attack_hit_delay := 0.4 

@export var ledge_grace_time := 0.15
@export var max_wall_stuck_time := 0.8

# --- NEW: Soft Collision ---
@export var repel_force := 45.0

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

# --- Areas ---
@onready var hitbox: Area2D = $HitboxArea
@onready var soft_collision: Area2D = $SoftCollisionArea

func _ready():
	vision_area.body_entered.connect(_on_vision_entered)
	vision_area.body_exited.connect(_on_vision_exited)
	
	hitbox.body_entered.connect(_on_hitbox_body_entered)
	hitbox.monitoring = false

	ledge_start_pos = ledge_check.position
	wall_start_pos = wall_check.position

	ledge_check.exclude_parent = true
	wall_check.exclude_parent = true
	alert_anim.hide()

	# --- SCRIPT-BASED COLLISION FIX ---
	set_collision_layer_value(1, false)
	set_collision_layer_value(2, false)
	set_collision_layer_value(3, true) 
	
	set_collision_mask_value(1, true)  
	set_collision_mask_value(2, true)  
	set_collision_mask_value(3, false) 
	
	ledge_check.set_collision_mask_value(3, false)
	wall_check.set_collision_mask_value(3, false)
	
	# --- NEW: Setup Soft Collision Area ---
	if soft_collision:
		soft_collision.set_collision_layer_value(1, false) 
		soft_collision.set_collision_mask_value(1, false)  
		soft_collision.set_collision_mask_value(3, true)   

func _physics_process(delta):
	if !is_on_floor():
		velocity.y += gravity * delta

	if is_stunned or is_dead:
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

	# --- NEW: Apply our push before moving ---
	_apply_soft_collision()

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

	# Check for attack FIRST before changing movement direction
	if distance <= attack_range and attack_timer <= 0:
		if sign(diff) != 0:
			direction = sign(diff)
		_start_attack()
		return

	if distance > 12:
		var new_dir = sign(diff)
		if new_dir != direction and !turn_locked:
			direction = new_dir
			direction_cooldown = 0.25
			turn_locked = true

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

# --- FIX 2: Prevents the Double-Await Deadlock completely! ---
func _start_attack():
	is_attacking = true
	velocity.x = 0
	attack_timer = attack_cooldown
	sprite.play("attack")
	
	# NEW: A background timer that turns the hitbox on without freezing the script!
	get_tree().create_timer(attack_hit_delay).timeout.connect(func():
		if is_attacking and not is_dead:
			hitbox.monitoring = true
	)
	
	# Now we only wait for ONE thing: the animation to finish
	await sprite.animation_finished
	
	# Turn it off and reset!
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

func _apply_soft_collision():
	if not soft_collision: 
		return
		
	var push_force = 0.0
	
	# Check for any other enemies inside our bubble
	for body in soft_collision.get_overlapping_bodies():
		if body != self: # Don't repel from yourself!
			var diff = global_position.x - body.global_position.x
			
			if diff > 0:
				push_force += repel_force 
			elif diff < 0:
				push_force -= repel_force 
			else:
				push_force += repel_force if get_instance_id() > body.get_instance_id() else -repel_force
				
	# Apply the push vector to our current velocity
	velocity.x += push_force

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

func _on_hitbox_body_entered(body):
	if body.is_in_group("player"):
		if body.has_method("take_damage"):
			body.take_damage(attack_damage)

func take_damage(amount, _attacker_x = null):
	if is_dead:
		return
		
	health -= amount
	
	if health <= 0:
		is_dead = true
	
	is_stunned = true
	is_attacking = false
	velocity.x = 0
	
	hitbox.monitoring = false
	
	sprite.play("hit")
	
	var tween = create_tween()
	sprite.modulate = Color(1, 0, 0)
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.2)
	
	await sprite.animation_finished
	
	if is_dead:
		die()
		return
		
	is_stunned = false

func die():
	if drop_scene != null:
		var drop = drop_scene.instantiate()
		drop.global_position = global_position
		get_tree().current_scene.add_child(drop)
		
	queue_free()
