extends Node2D

const CELL:= 50
const COLS := 30
const ROWS := 20
const SUNFLOWER_LIFE := 9.0
const MUSHROOM_LIFE := 9.0
const SPAWN_EVERY := 5.0
const MAX_ITEM = 6
const POTION_LIFE := 10.0
const CANDY_EVERY := 15.0
const NORMAL_SPEED := 0.20
const BOOST_SPEED := 0.10
const BOOST_TIME := 5.0
const ITEM_COLORS := {
	"sunflower": Color.YELLOW,
	"mushroom": Color.CYAN,
	"potion": Color.PURPLE,
	"candy": Color.HOT_PINK
}
const BAD_EVERY := 30.0
const WARN_TIME := 2.0
const BAD_LEN := 5
const WARNING_TEX := preload("res://assets/graphs/bad_warning.PNG")
const HEAD_TEX := preload("res://assets/graphs/snake_head.PNG")
const BODY_TEX := preload("res://assets/graphs/snake_body.PNG")
const TAIL_TEX := preload("res://assets/graphs/snake_tail.PNG")
const BAD_HEAD_TEX := preload("res://assets/graphs/bad_head.PNG")
const BAD_BODY_TEX := preload("res://assets/graphs/bad_body.PNG")
const BAD_TAIL_TEX := preload("res://assets/graphs/bad_tail.PNG")
const APPLE_TEX := preload("res://assets/graphs/apple.PNG")
const WALL_TEX := preload("res://assets/graphs/wall.PNG")
const PORTAL_TEX := preload("res://assets/graphs/portal.PNG")
const SAVE_PATH := "user://save.cfg"   #high score file

# sounds
const MUSIC := preload("res://assets/audio/ebs.ogg")
const SFX_APPLE := preload("res://assets/audio/eat_apple.wav")
const SFX_SUNFLOWER := preload("res://assets/audio/eat_sf.wav")
const SFX_MUSHROOM := preload("res://assets/audio/eat_mushroom.wav")
const SFX_JACKPOT := preload("res://assets/audio/jackpot.wav")
const SFX_POTION_GET := preload("res://assets/audio/potion_get.wav")
const SFX_POTION_WASTE := preload("res://assets/audio/potion_waste.wav")
const SFX_WARNING := preload("res://assets/audio/warning.wav")
const SFX_PORTAL := preload("res://assets/audio/portal_open.wav")
const SFX_BAD_DIED := preload("res://assets/audio/bad_snake_died.wav")
const SFX_DEATH := preload("res://assets/audio/death.wav")
const SFX_LOSE := preload("res://assets/audio/lose.wav")
const MUSIC_VOLUME_DB := -10.0   # music quieter than effects; 0 = full volume

# title screen + tutorial
const GAME_TITLE := "Who's the Bad SNAKE?"
const TUTORIAL := [
	{"tex": "res://assets/graphs/snake_head.PNG", "title": "Move",
		"text": "Use the arrow keys to move.\nDon't hit the walls or your own body!"},
	{"tex": "res://assets/graphs/apple.PNG", "title": "Apple",
		"text": "+10 points and your snake grows."},
	{"tex": "res://assets/graphs/sunflower.PNG", "title": "Sunflower",
		"text": "+50 points and your snake grows.\nIt disappears quickly, so hurry!"},
	{"tex": "res://assets/graphs/mushroom.PNG", "title": "Poison Mushroom",
		"text": "-30 points. Every mushroom hurts twice as much as the last: -30, -60, -120...\nIf your score drops below 0, you lose!"},
	{"tex": "res://assets/graphs/speed_2x_candy.PNG", "title": "Candy",
		"text": "Makes you faster for 5 seconds.\nOnly one candy at a time, and it never disappears."},
	{"tex": "res://assets/graphs/bad_warning.PNG", "title": "The Bad Snake",
		"text": "Every 30 seconds a bad snake comes out of a portal.\nHit it with your head and you die.\nBut if it crashes into your BODY, it dies instead!"},
	{"tex": "res://assets/graphs/potion.PNG", "title": "Purple Potion",
		"text": "Kill the bad snake to get a potion.\nThen eat a mushroom: +500 points, and the poison is cured!\nEating anything else first wastes the potion."},
]
const ITEM_TEX := {
	"sunflower": preload("res://assets/graphs/sunflower.PNG"),
	"mushroom": preload("res://assets/graphs/mushroom.PNG"),
	"potion": preload("res://assets/graphs/potion.PNG"),
	"candy": preload("res://assets/graphs/speed_2x_candy.PNG"),
}

var snake: Array[Vector2i] = [Vector2i(5, 7)]
var direction:= Vector2i.RIGHT
var next_direction:= Vector2i.RIGHT
var is_death:= false
var timer: Timer
var apple: Vector2i
var score:= 0
var items: Array = []
var mushrooms_eaten := 0
var spawn_clock := 0.0
var has_potion := false
var candy_clock :=0.0
var boost_left := 0.0
var bad: Array[Vector2i] = [] 
var bad_dir := Vector2i.ZERO
var bad_clock := 0.0
var warn_left := 0.0
var entry := Vector2i(-1, -1)
var high_score := 0

# game over screen 
var game_over: ColorRect
var final_label: Label
var best_label: Label
var hint_label: Label
var best_top_label: Label
var music: AudioStreamPlayer

# "title" -> "tutorial" -> "play"
var state := "title"
var page := 0
static var seen_title := false   # static: survives the restart after game over
var menu: ColorRect
var menu_title: Label
var menu_image: TextureRect
var menu_text: Label
var menu_hint: Label

@onready var score_label: Label = $TopBar/ScoreLabel
@onready var poison_label: Label = $TopBar/PoisonLabel
@onready var potion_icon: TextureRect = $TopBar/PotionIcon

func _ready() :
	timer = Timer.new()
	timer.wait_time = NORMAL_SPEED
	timer.timeout.connect(_on_tick)
	add_child(timer)
	apple = random_free_cell()
	load_high_score()
	build_game_over()
	# show the best score in the top bar too
	best_top_label = make_label("Best: " + str(high_score), 36)
	$TopBar.add_child(best_top_label)
	start_music()
	build_menu()
	if seen_title:
		begin_play()      # after a game over, skip the title and play right away
	else:
		show_title()
	
func _on_tick():
	direction = next_direction
	var new_head := snake[0] + direction
	
	if is_wall(new_head) or new_head in snake.slice(0, -1) or new_head in bad:
		die()
		return

	snake.insert(0, new_head)
	var grow := false

	# apple
	if new_head == apple:
		play_sfx(SFX_APPLE)
		add_score(10)
		apple = random_free_cell()
		grow = true
		waste_potion()

	# other items
	for item in items:
		if item["cell"] == new_head:
			items.erase(item)
			if item["type"] == "sunflower":
				play_sfx(SFX_SUNFLOWER)
				add_score(50)
				grow = true
				waste_potion()
			elif item["type"] == "mushroom":
				if has_potion:
					play_sfx(SFX_JACKPOT)
					add_score(500)
					has_potion = false
					mushrooms_eaten = 0
				else:
					play_sfx(SFX_MUSHROOM)
					add_score(-next_penalty())
					mushrooms_eaten += 1
				update_poison_label()
			elif item["type"] == "potion":
				play_sfx(SFX_POTION_GET)
				has_potion = true
			elif item["type"] == "candy":
				play_sfx(SFX_SUNFLOWER, 1.6)   # no candy sound yet: reuse sunflower, higher pitch
				timer.wait_time = BOOST_SPEED
				boost_left = BOOST_TIME
				waste_potion()
			break

	if not grow:
		snake.pop_back()
	move_bad_snake()
	queue_redraw()
	
func _unhandled_input(event):
	if state != "play":
		menu_input(event)
		return
	if is_death:
		if event.is_action_pressed("ui_accept"):
			get_tree().reload_current_scene()
		return
	
	var new_dir := next_direction
	if event.is_action_pressed("ui_right"):
		new_dir = Vector2i.RIGHT
	elif event.is_action_pressed("ui_left"):
		new_dir = Vector2i.LEFT
	elif event.is_action_pressed("ui_up"):
		new_dir = Vector2i.UP
	elif event.is_action_pressed("ui_down"):
		new_dir = Vector2i.DOWN
	
	if new_dir != -direction:
		next_direction = new_dir

func is_wall(cell: Vector2i) -> bool:
	return cell.x == 0 or cell.y == 0 or cell.x == COLS-1 or cell.y == ROWS-1

func die():
	if is_death:
		return            # already dead, don't do it twice
	is_death = true
	timer.stop()

	var new_best := score > high_score
	if new_best:
		high_score = score
		save_high_score()

	final_label.text = "Score: " + str(score)
	if new_best:
		best_label.text = "NEW BEST: " + str(high_score) + "!"
		best_label.add_theme_color_override("font_color", Color.GOLD)
	else:
		best_label.text = "Best: " + str(high_score)

	game_over.visible = true
	queue_redraw()

	# sounds: stop music, crash, then the sad jingle
	music.stop()
	play_sfx(SFX_DEATH)
	# 0.7 s later play the lose jingle (safe even if the player restarts right away)
	get_tree().create_timer(0.7).timeout.connect(play_sfx.bind(SFX_LOSE))

func _draw():
	# background: plain green
	draw_rect(Rect2(0, 0, COLS * CELL, ROWS * CELL), Color("#35763a"))

	# walls
	for x in COLS:
		for y in ROWS:
			if is_wall(Vector2i(x, y)):
				draw_piece(WALL_TEX, Vector2i(x, y))

	# apple
	draw_piece(APPLE_TEX, apple)

	# items
	for item in items:
		if item["time"] < 3.0 and int(item["time"] * 5) % 2 == 0:
			continue
		var tex: Texture2D = ITEM_TEX[item["type"]]
		draw_piece(tex, item["cell"])

	# portal: spins, a bit bigger than a cell
	if warn_left > 0 or entry in bad:
		var spin := Time.get_ticks_msec() / 1000.0 * 3.0
		draw_piece(PORTAL_TEX, entry, spin, Color.WHITE, CELL * 1.4)

	# warning picture
	if warn_left > 0 and int(warn_left * 4) % 2 == 0:
		var size := CELL * 3
		var spot := entry + bad_dir * 2
		var cntr := Vector2(spot * CELL) + Vector2(CELL / 2.0, CELL / 2.0)
		var top_left := cntr - Vector2(size / 2.0, size / 2.0)
		draw_texture_rect(WARNING_TEX, Rect2(top_left, Vector2(size, size)), false)

	# player snake
	var tint := Color.WHITE
	if is_death:
		tint = Color(0.4, 0.4, 0.4)       # gray
	elif has_potion:
		tint = Color(0.8, 0.5, 1.0)       # purple
	for i in snake.size():
		var tex := BODY_TEX
		if i == 0:
			tex = HEAD_TEX
		elif i == snake.size() - 1:
			tex = TAIL_TEX
		draw_piece(tex, snake[i], piece_angle(snake, i, direction), tint)

	# bad snake
	for i in bad.size():
		var tex := BAD_BODY_TEX
		if i == 0:
			tex = BAD_HEAD_TEX
		elif i == bad.size() - 1:
			tex = BAD_TAIL_TEX
		draw_piece(tex, bad[i], piece_angle(bad, i, bad_dir))

func random_free_cell() -> Vector2i:
	var cell:= Vector2i(randi_range(1, COLS-2), randi_range(1, ROWS-2))
	while is_taken(cell):
		cell = Vector2i(randi_range(1, COLS - 2), randi_range(1, ROWS - 2))
	return cell

func is_taken(cell: Vector2i) -> bool:
	if cell in snake or cell == apple or cell in bad:
		return true
	for item in items:
		if item["cell"] == cell:
			return  true
	return false

func add_score(amount: int):
	score += amount
	score_label.text = "Score: " + str(score)
	if score<0:
		die()

func _process(delta: float) -> void:
	potion_icon.visible = has_potion
	hint_label.visible = int(Time.get_ticks_msec() / 500) % 2 == 0   # blink every 0.5 s
	menu_hint.modulate.a = 0.55 + 0.45 * sin(Time.get_ticks_msec() / 250.0)   # gentle pulse
	if is_death or state != "play":
		return
	#count down every items time
	for item in items :
		item["time"] -= delta
	# item got time
	items = items.filter(func(item): return item["time"]>0)
	#try to add new item
	spawn_clock += delta
	if spawn_clock >= SPAWN_EVERY:
		spawn_clock =0.0
		if items.size() < MAX_ITEM:
			spawn_item()
	#candy
	if not has_item("candy"):
		candy_clock+=delta
		if candy_clock >= CANDY_EVERY:
			candy_clock = 0.0
			items.append({"type": "candy", "cell": random_free_cell(), "time": INF})
	#speed boost
	if boost_left>0:
		boost_left -= delta
		if boost_left <= 0:
			timer.wait_time = NORMAL_SPEED
	# bad snake: wait, warn, then come out
	if bad.is_empty() and warn_left <= 0:
		bad_clock += delta
		if bad_clock >= BAD_EVERY:
			bad_clock = 0.0
			start_warning()
	if warn_left > 0:
		warn_left -= delta
		if warn_left <= 0:
			bad.append(entry)
			play_sfx(SFX_PORTAL)
	queue_redraw()

func spawn_item():
	var roll:= randf()
	var kind : String
	var life : float
	if roll < 0.5 :
		kind = "sunflower"
		life = SUNFLOWER_LIFE
	else:
		kind = "mushroom"
		life = MUSHROOM_LIFE
	items.append({"type": kind, "cell": random_free_cell(), "time": life})
		
func has_item(kind: String) -> bool:
	for item in items:
		if item["type"] == kind:
			return true
	return false
	
func waste_potion():
	if has_potion:
		has_potion = false
		play_sfx(SFX_POTION_WASTE)
		
func update_poison_label():
	poison_label.text = "-" + str(next_penalty())

func next_penalty() -> int:
	return 30 * 2 ** mushrooms_eaten

func start_warning():
	var side := randi_range(0, 3)
	match side:
		0:   # left wall, moving right
			entry = Vector2i(0, randi_range(1, ROWS - 2))
			bad_dir = Vector2i.RIGHT
		1:   # right wall, moving left
			entry = Vector2i(COLS - 1, randi_range(1, ROWS - 2))
			bad_dir = Vector2i.LEFT
		2:   # top wall, moving down
			entry = Vector2i(randi_range(1, COLS - 2), 0)
			bad_dir = Vector2i.DOWN
		3:   # bottom wall, moving up
			entry = Vector2i(randi_range(1, COLS - 2), ROWS - 1)
			bad_dir = Vector2i.UP
	warn_left = WARN_TIME
	play_sfx(SFX_WARNING)

func is_outside(cell: Vector2i) -> bool:
	return cell.x < 0 or cell.y < 0 or cell.x >= COLS or cell.y >= ROWS

func move_bad_snake():
	if bad.is_empty():
		return
	var bad_new := bad[0] + bad_dir

	if bad_new in snake:
		if bad_new == snake[0]:
			die() # head to head: player dies
		else:
			kill_bad_snake() # it hit your body: trapped!
		return

	bad.insert(0, bad_new)
	if bad.size() > BAD_LEN:
		bad.pop_back()
	if is_outside(bad[bad.size() - 1]):
		bad.clear() # its tail left the screen: it's gone

func kill_bad_snake():
	play_sfx(SFX_BAD_DIED)
	var drop: Vector2i = bad[0]
	bad.clear()
	if is_wall(drop) or is_taken(drop):
		drop = random_free_cell()
	items.append({"type": "potion", "cell": drop, "time": INF})

func draw_piece(tex: Texture2D, cell: Vector2i, angle: float = 0.0, tint: Color = Color.WHITE, size: float = CELL):
	var center := Vector2(cell * CELL) + Vector2(CELL / 2.0, CELL / 2.0)
	draw_set_transform(center, angle) # move pen + turn paper
	draw_texture_rect(tex, Rect2(-size / 2.0, -size / 2.0, size, size), false, tint)
	draw_set_transform(Vector2.ZERO, 0.0) # put paper back

func piece_angle(body: Array[Vector2i], i: int, head_dir: Vector2i) -> float:
	if i == 0:
		return Vector2(head_dir).angle() # head faces where it's going
	return Vector2(body[i - 1] - body[i]).angle() # others face the piece in front

# ---------- high score ----------

func load_high_score():
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:          # OK = the file exists and loaded fine
		high_score = cfg.get_value("game", "high_score", 0)

func save_high_score():
	var cfg := ConfigFile.new()
	cfg.set_value("game", "high_score", high_score)
	cfg.save(SAVE_PATH)

# ---------- game over screen ----------

func make_label(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	return label

func build_game_over():
	# dark see-through layer over the board
	game_over = ColorRect.new()
	game_over.color = Color(0, 0, 0, 0.65)
	game_over.position = Vector2.ZERO
	game_over.size = Vector2(COLS * CELL, ROWS * CELL)   # same size as the board
	game_over.visible = false
	add_child(game_over)   # added last, so it is drawn on top of everything

	# a column that keeps the text in the middle
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 24)
	game_over.add_child(box)

	var title := make_label("GAME OVER", 140)
	title.add_theme_color_override("font_color", Color("#ff4d4d"))
	box.add_child(title)

	final_label = make_label("Score: 0", 64)
	box.add_child(final_label)

	best_label = make_label("Best: 0", 64)
	box.add_child(best_label)

	hint_label = make_label("Press Enter to play again", 44)
	box.add_child(hint_label)

# ---------- sound helpers ----------

func start_music():
	var stream: AudioStreamOggVorbis = MUSIC
	stream.loop = true                 # repeat forever
	music = AudioStreamPlayer.new()
	music.stream = stream
	music.volume_db = MUSIC_VOLUME_DB
	add_child(music)
	music.play()

# plays a sound once; a new player each time so sounds can overlap
func play_sfx(stream: AudioStream, pitch: float = 1.0):
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.pitch_scale = pitch
	add_child(player)
	player.play()
	player.finished.connect(player.queue_free)   # delete it when done

# ---------- title screen + tutorial ----------

func build_menu():
	menu = ColorRect.new()
	menu.color = Color(0, 0, 0, 0.85)
	menu.position = Vector2.ZERO
	menu.size = Vector2(COLS * CELL, ROWS * CELL)
	add_child(menu)

	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 28)
	menu.add_child(box)

	menu_title = make_label("", 110)
	menu_title.add_theme_color_override("font_color", Color("#9be37a"))
	box.add_child(menu_title)

	# light rounded card behind the picture, so dark art (the bad snake) is visible
	var card := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.93, 0.95, 0.9)
	style.set_corner_radius_all(40)
	style.set_content_margin_all(24)
	card.add_theme_stylebox_override("panel", style)
	card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(card)

	menu_image = TextureRect.new()
	menu_image.custom_minimum_size = Vector2(260, 260)
	menu_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	menu_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	card.add_child(menu_image)

	menu_text = make_label("", 44)
	menu_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	menu_text.custom_minimum_size = Vector2(COLS * CELL * 0.7, 0)
	menu_text.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(menu_text)

	menu_hint = make_label("", 34)
	menu_hint.add_theme_color_override("font_color", Color("#cccccc"))
	box.add_child(menu_hint)

func show_title():
	state = "title"
	menu.visible = true
	menu_title.text = GAME_TITLE
	# start big, then shrink the font until the name fits in 90% of the board width
	var font := menu_title.get_theme_font("font")
	var font_size := 160
	while font_size > 40 and font.get_string_size(GAME_TITLE, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > COLS * CELL * 0.9:
		font_size -= 4
	menu_title.add_theme_font_size_override("font_size", font_size)
	menu_image.texture = HEAD_TEX
	menu_text.text = "Best: " + str(high_score)
	menu_hint.text = "Press Enter to start"

func show_page():
	state = "tutorial"
	var info: Dictionary = TUTORIAL[page]
	menu_title.text = info["title"]
	menu_title.add_theme_font_size_override("font_size", 90)
	menu_image.texture = load(info["tex"])
	menu_text.text = info["text"]
	var last := page == TUTORIAL.size() - 1
	var next_word := "play!" if last else "next"
	menu_hint.text = "(" + str(page + 1) + "/" + str(TUTORIAL.size()) + ")   Enter: " + next_word + "   Left: back   Esc: skip"

func menu_input(event):
	if event.is_action_pressed("ui_cancel") and state == "tutorial":
		begin_play()                      # Esc skips the tutorial
	elif event.is_action_pressed("ui_accept"):
		if state == "title":
			page = 0
			show_page()
		else:
			page += 1
			if page >= TUTORIAL.size():
				begin_play()
			else:
				show_page()
	elif event.is_action_pressed("ui_left") and state == "tutorial" and page > 0:
		page -= 1
		show_page()

func begin_play():
	state = "play"
	seen_title = true
	menu.visible = false
	timer.start()
