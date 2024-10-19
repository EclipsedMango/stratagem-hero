extends ColorRect

@onready var label: Label = %Label
@onready var icons: HBoxContainer = %Icons
@onready var arrow_container: HBoxContainer = %Arrows
@onready var camera_2d: Camera2D = %Camera2D
@onready var progress_bar: ProgressBar = %ProgressBar
@onready var round_num: Label = %RoundNum
@onready var score_num: Label = %ScoreNum
@onready var name_bar: ColorRect = %Name
@onready var button_press_sound: AudioStreamPlayer2D = %ButtonPress
@onready var button_press_error_sound: AudioStreamPlayer2D = %ButtonPressError
@onready var game_music_sound: AudioStreamPlayer2D = %GameMusic
@onready var game_over_sound: AudioStreamPlayer2D = %GameOver
@onready var round_over_sound: AudioStreamPlayer2D = %RoundOver
@onready var round_start_coin_1_sound: AudioStreamPlayer2D = %RoundStartCoin1
@onready var round_start_coin_2_sound: AudioStreamPlayer2D = %RoundStartCoin2
@onready var sequence_success_sound: AudioStreamPlayer2D = %SequenceSuccess

@onready var style_box := progress_bar.get_theme_stylebox("fill")

static var yellow := Color.from_string("ffd612", Color.WHITE)
static var gray := Color.from_string("cccccc", Color.WHITE)
static var red := Color.from_string("c15045", Color.WHITE)

var arrow_res: PackedScene = preload("res://Arrow.tscn")
var icon_res: PackedScene = preload("res://Icon.tscn")
var current_strategem: Strategem
var current_strategem_index: int = 0
var current_round_strategems: Array[Strategem] = []
var rounds: int = 0
var score: int = 0

var is_reset: bool = false
var is_screen_shaking: bool = false
var can_play: bool = true
var game_just_started: bool = true

var strategems: Array = []

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var split := FileAccess.get_file_as_string("res://strategems.txt").split('\n')
	
	for i in range(0, split.size(), 2):
		var strategem: Strategem = Strategem.new()
		
		var split_split: PackedStringArray = split[i].split("\t", false)
		
		if split_split.is_empty():
			break
		
		var icon_name: String = split_split[0].replace(" Stratagem Icon ", ".svg")
		
		strategem.icon = load("res://Helldivers-2-Stratagems-icons-svg-master/" + icon_name)
		strategem.name = split_split[1]
		
		var arrows_raw: PackedStringArray = split[i + 1].split(".png ", false)
		var arrows_cooked: PackedStringArray = []
		
		for arrow in arrows_raw:
			if arrow.contains("U"): arrows_cooked.append("U")
			elif arrow.contains("D"): arrows_cooked.append("D")
			elif arrow.contains("L"): arrows_cooked.append("L")
			elif arrow.contains("R"): arrows_cooked.append("R")
		
		strategem.arrows = arrows_cooked
		strategems.append(strategem)
	
	game_music_sound.play()
	
	load_strategem()


func load_strategem() -> void:
	if !current_round_strategems.is_empty():
		current_round_strategems.remove_at(0)
		icons.get_child(0).free()
	
	if current_round_strategems.size() <= 0 || !can_play:
		current_round_strategems.clear()
		for child in icons.get_children():
			child.queue_free()
			icons.remove_child(child)
		
		if !game_just_started:
			score += 150
			score_num.text = str(score)
		
		for i in range(6):
			current_round_strategems.append(strategems.pick_random())
			var icon = icon_res.instantiate()
			icons.add_child(icon)
			icon.get_child(0).texture = current_round_strategems[i].icon
			
		
		progress_bar.value = 100
		
		if can_play:
			game_just_started = false
			rounds += 1
			round_num.text = str(rounds)
			
	
	icons.get_child(0).custom_minimum_size = Vector2(128, 128)
	icons.get_child(0).self_modulate = Color.WHITE
	
	current_strategem = current_round_strategems[0]
	label.text = current_strategem.name
	
	for child in arrow_container.get_children():
		child.queue_free()
	
	for dir in current_strategem.arrows:
		var arrow = arrow_res.instantiate()
		match dir:
			"U": arrow.get_child(0).rotation = TAU * -0.25
			"D": arrow.get_child(0).rotation = TAU * 0.25
			"L": arrow.get_child(0).rotation = TAU * 0.5
			"R": arrow.get_child(0).rotation = TAU * 0.0
		
		arrow_container.add_child(arrow)


func _process(delta: float) -> void:
	process_dir("Up", "U")
	process_dir("Down", "D")
	process_dir("Left", "L")
	process_dir("Right", "R")
	
	if is_screen_shaking:
		camera_2d.position = Vector2(randf() * 2.0 - 1.0, randf() * 2.0 - 1.0)
	else:
		camera_2d.position = Vector2(0, 0)
	
	progress_bar.value -= 10.0 * delta
	
	if progress_bar.value <= 30:
		name_bar.color = red
		style_box.bg_color = red
		round_num.label_settings.font_color = red
		score_num.label_settings.font_color = red
		icons.get_child(0).get_theme_stylebox("panel").border_color = red
	else:
		name_bar.color = yellow
		style_box.bg_color = yellow
		round_num.label_settings.font_color = yellow
		score_num.label_settings.font_color = yellow
		icons.get_child(0).get_theme_stylebox("panel").border_color = yellow
	
	if progress_bar.value <= 0:
		if can_play:
			game_music_sound.stop()
			game_over_sound.play()
		is_screen_shaking = true
		can_play = false
		rounds = 1
		score = 0
		score_num.text = str(score)
		round_num.text = str(rounds)
		get_tree().create_timer(0.50).timeout.connect(func(): is_screen_shaking = false)
		if Input.is_action_just_pressed("Enter"):
			get_tree().create_timer(0.5).timeout.connect(func(): load_strategem())
			is_reset = true
	
	if is_reset:
		progress_bar.value += 100 * delta
		if progress_bar.value == 100:
			is_reset = false
			can_play = true


func process_dir(action: StringName, dir: String) -> void:
	if not Input.is_action_just_pressed(action) || !can_play:
		return
	
	var current_dir_strategem: PackedStringArray = current_strategem.arrows.duplicate()
	
	if dir == current_dir_strategem[current_strategem_index]:
		arrow_container.get_child(current_strategem_index).modulate = yellow
		button_press_sound.play()
		current_strategem_index += 1
		
		if current_dir_strategem.size() <= current_strategem_index:
			current_strategem_index = 0
			sequence_success_sound.play()
			progress_bar.value += 12.0
			score += 3 * (progress_bar.value / 2)
			score_num.text = str(score)
			load_strategem()
	else:
		current_strategem_index = 0
		button_press_error_sound.play()
		is_screen_shaking = true
		for i in arrow_container.get_children():
			i.modulate = red
			get_tree().create_timer(0.25).timeout.connect(func(): i.modulate = gray)
		
		get_tree().create_timer(0.25).timeout.connect(func(): is_screen_shaking = false)
