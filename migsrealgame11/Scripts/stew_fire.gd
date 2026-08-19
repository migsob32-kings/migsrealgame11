extends Area2D

# Export variables so you can assign these nodes in the Inspector
@export var pot_sprite: CanvasItem
@export var deposit_particles: Node2D
@export var stew_scene: PackedScene

var stored_mushrooms: int = 0
var max_capacity: int = 3
var stew_ready: bool = false # --- NEW: Prevents double-spawning glitches ---

func _ready():
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

func _on_body_entered(body):
	if body.name == "Player" or body.is_in_group("player"):
		
		# 1. Ignore the player if they literally just respawned here
		if body.get("is_respawning") == true:
			return 
			
		# 2. If the stew is already made, do nothing else
		if stew_ready:
			return
			
		# 3. Check how much space the pot has left
		var space_left = max_capacity - stored_mushrooms
		var dropped_amount = 0
		
		# 4. Only take mushrooms if there is space
		if space_left > 0 and body.has_method("drop_amount"):
			dropped_amount = body.drop_amount("mushroom", space_left)
			stored_mushrooms += dropped_amount
			
		# --- VISUAL EFFECTS & LOGIC ---
		if dropped_amount > 0:
			play_deposit_effect()
			
		# 5. Check if it JUST reached max capacity
		if stored_mushrooms >= max_capacity and not stew_ready:
			stew_ready = true # Lock the pot so it can never trigger this twice
			
			if body.has_method("set_respawn_point"):
				body.set_respawn_point(global_position)
			
			show_popup_message("Respawn Set!\nPot is Full (3/3)")
			play_full_color_effect()
			spawn_stew() # Spawns the stew!
				
		elif dropped_amount > 0:
			show_popup_message("Mushrooms Added!\nPot: " + str(stored_mushrooms) + "/" + str(max_capacity))
			
		elif stored_mushrooms > 0:
			show_popup_message("Need more to save!\nPot: " + str(stored_mushrooms) + "/" + str(max_capacity))
			
		elif stored_mushrooms == 0:
			show_popup_message("Empty pockets!\nNeed mushrooms to start stew.")

# --- EFFECT FUNCTIONS ---

func play_deposit_effect():
	if deposit_particles:
		deposit_particles.restart() 
		deposit_particles.emitting = true
		
		await get_tree().create_timer(3.0).timeout
		deposit_particles.emitting = false

func play_full_color_effect():
	if pot_sprite:
		var tween = create_tween()
		tween.tween_property(pot_sprite, "modulate", Color.GREEN, 0.3)
		tween.tween_interval(1.5)
		tween.tween_property(pot_sprite, "modulate", Color.WHITE, 1.0)


func show_popup_message(message: String):
	var label = Label.new()
	label.text = message
	label.add_theme_font_size_override("font_size", 24)
	label.modulate = Color.WHITE
	
	get_tree().root.add_child(label)
	
	label.anchor_left = 1.0
	label.anchor_top = 1.0
	label.offset_left = -250
	label.offset_top = -80
	
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_IN)
	tween.tween_property(label, "modulate", Color.TRANSPARENT, 2.0)
	tween.tween_callback(label.queue_free)

# --- SPAWN FUNCTION ---
func spawn_stew():
	if stew_scene != null:
		# --- NEW: Wait 0.3 seconds so it matches the pot turning green! ---
		await get_tree().create_timer(0.3).timeout 
		
		var stew_instance = stew_scene.instantiate()
		get_parent().add_child(stew_instance)
		
		stew_instance.global_position = global_position + Vector2(0, -40)
