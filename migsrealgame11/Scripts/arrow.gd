extends RigidBody2D

@export var min_damage_velocity := 150.0
@export var damage := 10

var has_hit := false

func _ready():
	gravity_scale = 1.0
	linear_damp = 0.0
	angular_damp = 0.0
	scale = Vector2(0.5, 0.5)
	contact_monitor = true
	max_contacts_reported = 1
	
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

func _physics_process(_delta):
	# Optimization: Only calculate rotation if it hasn't hit anything yet
	if not has_hit and linear_velocity.length() > 10:
		rotation = linear_velocity.angle()

func _on_body_entered(body):
	if has_hit:
		return
		
	has_hit = true
	
	# 1. Did we hit something hard enough?
	if linear_velocity.length() > min_damage_velocity:
		if body.has_method("take_damage"):
			
			# 2. Is it the enemy? Send damage + arrow X position
			if "is_stunned" in body:
				body.take_damage(damage, global_position.x)
			# 3. Is it something else (like the player)? Send ONLY damage
			else:
				body.take_damage(damage)
				
			# Destroy the arrow immediately on hitting something with health
			queue_free()
			return 
			
	# 4. If we hit the environment (or hit the enemy too slowly)
	# --- BUG FIX: Use set_deferred to safely freeze the physics body ---
	set_deferred("freeze", true)
	
	# Start the cleanup timer
	await get_tree().create_timer(4.0).timeout
	
	# Fade out over 0.4 seconds then free
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.4)
	await tween.finished
	queue_free()
