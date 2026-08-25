extends CanvasLayer

# --- Node References ---
@onready var health_bar = $TextureProgressBar
@onready var hunger_bar = $HungerBar
@onready var mushroom_label = $MushroomLabel 
@onready var super_popup = $SuperPopupLabel 
@onready var special_arrow_prompt = $SpecialArrowPrompt # --- NEW: Reference the F prompt ---

var player: CharacterBody2D
var original_bar_pos: Vector2
var original_hunger_pos: Vector2

func _ready():
	player = get_tree().get_first_node_in_group("player")
	
	if player:
		connect_player_signals()
		
	if health_bar:
		original_bar_pos = health_bar.position
		
	if hunger_bar:
		original_hunger_pos = hunger_bar.position
		
	# Ensure text popup starts invisible
	if super_popup:
		super_popup.modulate.a = 0.0
		
	# Ensure the 'F' prompt starts hidden
	if special_arrow_prompt:
		special_arrow_prompt.hide()

func connect_player_signals():
	if not player.health_changed.is_connected(_on_player_health_changed):
		player.health_changed.connect(_on_player_health_changed)
		
	if not player.mushrooms_changed.is_connected(_on_player_mushrooms_changed):
		player.mushrooms_changed.connect(_on_player_mushrooms_changed)
		
	if not player.stew_buff_changed.is_connected(_on_stew_buff_changed):
		player.stew_buff_changed.connect(_on_stew_buff_changed)
		
	# --- Super Mode Signals ---
	if not player.super_mode_activated.is_connected(_on_super_mode_activated):
		player.super_mode_activated.connect(_on_super_mode_activated)
		
	if not player.super_mode_timer_changed.is_connected(_on_super_mode_timer_changed):
		player.super_mode_timer_changed.connect(_on_super_mode_timer_changed)
		
	if not player.super_mode_deactivated.is_connected(_on_super_mode_deactivated):
		player.super_mode_deactivated.connect(_on_super_mode_deactivated)
		
	# Force an initial update
	_on_player_health_changed(player.health, player.max_health)
	_on_player_mushrooms_changed(player.get_inventory_count("mushroom"))
	_on_stew_buff_changed(player.stew_bars, player.max_stew_bars)

# --- Signal Receiver Functions ---

func _on_player_health_changed(new_health: int, max_health: int):
	if health_bar:
		var took_damage = new_health < health_bar.value
		health_bar.max_value = max_health
		health_bar.value = new_health
		if took_damage:
			play_hurt_effect()

func _on_player_mushrooms_changed(count: int):
	if mushroom_label:
		mushroom_label.text = "Mushrooms: " + str(count) + " / 3"
		if count >= 3:
			mushroom_label.modulate = Color(0.2, 0.8, 0.2)
		else:
			mushroom_label.modulate = Color.WHITE

func _on_stew_buff_changed(current_bars: int, max_bars: int):
	# Only update standard logic if we aren't using the bar as a timer
	if hunger_bar and not player.is_super_mode:
		hunger_bar.max_value = max_bars
		hunger_bar.value = current_bars
		
		# Show the 'F' prompt if the bar is full!
		if special_arrow_prompt:
			if current_bars >= max_bars:
				special_arrow_prompt.show()
			else:
				special_arrow_prompt.hide()

# --- Super Mode Receiver Functions ---

func _on_super_mode_activated(duration: float):
	# Hide the 'F' prompt since we just activated it
	if special_arrow_prompt:
		special_arrow_prompt.hide()
		
	if super_popup:
		# Flash text instantly
		super_popup.modulate.a = 1.0 
		var tween = create_tween()
		tween.tween_property(super_popup, "modulate:a", 0.0, 1.0).set_delay(1.5) 
		
	if hunger_bar:
		# Change color to look like an active timer! (Adjust this color as needed)
		hunger_bar.modulate = Color(1.0, 0.8, 0.0)

func _on_super_mode_timer_changed(time_left: float, max_time: float):
	if hunger_bar:
		# Set the bar's max value to the 15 seconds, and drain it down to 0
		hunger_bar.max_value = max_time
		hunger_bar.value = time_left

func _on_super_mode_deactivated():
	if hunger_bar:
		# Revert bar color to normal
		hunger_bar.modulate = Color.WHITE
		# The player script immediately emits stew_buff_changed to set the visual bar back to 0

# --- Visual Effects ---

func play_hurt_effect():
	if health_bar:
		var tween = create_tween()
		tween.tween_property(health_bar, "position", original_bar_pos + Vector2(5, 0), 0.05)
		tween.tween_property(health_bar, "position", original_bar_pos - Vector2(5, 0), 0.05)
		tween.tween_property(health_bar, "position", original_bar_pos, 0.05)
		
	if hunger_bar:
		var hunger_tween = create_tween()
		hunger_tween.tween_property(hunger_bar, "position", original_hunger_pos + Vector2(5, 0), 0.05)
		hunger_tween.tween_property(hunger_bar, "position", original_hunger_pos - Vector2(5, 0), 0.05)
		hunger_tween.tween_property(hunger_bar, "position", original_hunger_pos, 0.05)
