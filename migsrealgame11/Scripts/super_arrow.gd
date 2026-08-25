extends RigidBody2D

@export var min_damage_velocity := 50.0 
@export var damage := 30 # --- HIGH DAMAGE! ---

var has_hit_wall := false
var hit_enemies := [] # Tracks enemies we've pierced so they don't take damage twice per frame

func _ready():
	# Gravity is back to 1.0 so it arcs normally!
	gravity_scale = 1.0
	linear_damp = 0.0
	angular_damp = 0.0
	scale = Vector2(0.5, 0.5)
	contact_monitor = true
	# Increased so it can hit multiple overlapping things
	max_contacts_reported = 5 

	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

func _physics_process(_delta):
	# Rotates the arrow so it points exactly where it is flying in the arc
	if not has_hit_wall and linear_velocity.length() > 10:
		rotation = linear_velocity.angle()

func _on_body_entered(body):
	if has_hit_wall:
		return

	# 1. Did we hit the enemy? PIERCE THEM!
	if body.has_method("take_damage"):
		if not body in hit_enemies:
			body.take_damage(damage)
			hit_enemies.append(body) 
			
		# Notice there is NO queue_free() here! The arrow keeps going!
		return

	# 2. If we hit the environment (walls, floors)
	has_hit_wall = true
	set_deferred("freeze", true)
	
	# Disable the collision shape so it doesn't become a ramp
	$CollisionShape2D.set_deferred("disabled", true)

	# Start the cleanup timer
	await get_tree().create_timer(4.0).timeout

	# Fade out over 0.4 seconds then free
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.4)
	await tween.finished
	queue_free()
