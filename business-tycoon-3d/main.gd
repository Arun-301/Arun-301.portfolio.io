extends Node3D

const GREEN = Color("#247a50")
const GOLD = Color("#f5c451")
const DARK = Color("#14242a")
const PANEL = Color("#20363d")
var cash: int = 10000
var day: int = 1
var level: int = 1
var stock: int = 20
var upgrades: int = 0
var cafe_unlocked: bool = false
var camera: Camera3D
var camera_target := Vector3(0, 0, 0)
var camera_distance := 16.0
var dragging := false
var last_mouse := Vector2.ZERO
var cash_label: Label
var status_label: Label
var scene_root: Node3D
var ui: CanvasLayer

func _ready():
	_build_world()
	_build_ui()
	_update_ui()

func _mat(color: Color, roughness := 0.9) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	return m

func _box(parent: Node3D, pos: Vector3, size: Vector3, color: Color, name := "Object") -> MeshInstance3D:
	var item := MeshInstance3D.new()
	item.name = name
	var mesh := BoxMesh.new()
	mesh.size = size
	item.mesh = mesh
	item.position = pos
	item.material_override = _mat(color)
	parent.add_child(item)
	return item

func _build_world():
	scene_root = Node3D.new()
	scene_root.name = "LowPolyShop"
	add_child(scene_root)
	# Floor and colored tile strips
	_box(scene_root, Vector3(0,-0.2,0), Vector3(18,0.4,14), Color("#c5bba4"), "Shop floor")
	for x in range(-8, 9, 2):
		_box(scene_root, Vector3(x,0.015,0), Vector3(0.035,0.02,13.5), Color("#b1a68e"), "Tile seam")
	# Back wall and side walls
	_box(scene_root, Vector3(0,2.1,-6.7), Vector3(18,4.2,0.3), Color("#e8e5d9"), "Back wall")
	_box(scene_root, Vector3(-8.8,2.1,0), Vector3(0.3,4.2,13.5), Color("#d4dfd5"), "Left wall")
	_box(scene_root, Vector3(8.8,2.1,0), Vector3(0.3,4.2,13.5), Color("#d4dfd5"), "Right wall")
	# Store fascia
	_box(scene_root, Vector3(0,3.6,-6.45), Vector3(8,0.9,0.18), GREEN, "Store sign")
	_box(scene_root, Vector3(0,3.6,-6.32), Vector3(7.2,0.12,0.06), GOLD, "Sign trim")
	# Entrance marker
	_box(scene_root, Vector3(0,0.08,6.4), Vector3(4.5,0.12,0.25), GOLD, "Entrance")
	# Shelving rows with colorful products
	for row in range(3):
		var z := -3.7 + row * 2.45
		_box(scene_root, Vector3(-4.8,0.8,z), Vector3(2.0,1.6,0.72), Color("#805638"), "Shelf")
		_box(scene_root, Vector3(-4.8,1.58,z), Vector3(2.1,0.08,0.8), Color("#d7c9ac"), "Shelf top")
		for p in range(5):
			var col: Color = [Color("#e75b48"),Color("#f0b83d"),Color("#55a6bd"),Color("#73ad67"),Color("#bd79b5")][p]
			_box(scene_root, Vector3(-5.55 + p*0.37,1.08,z), Vector3(0.25,0.42,0.32), col, "Product")
			_box(scene_root, Vector3(-5.55 + p*0.37,1.45,z), Vector3(0.25,0.2,0.32), col.lightened(0.12), "Product")
	# Produce bins
	for x in [-1.7, 1.0]:
		_box(scene_root, Vector3(x,0.48,-2.8), Vector3(1.65,0.9,1.25), Color("#98704a"), "Produce counter")
		for i in range(4):
			for j in range(3):
				var fruit_color: Color = [Color("#d94b3d"),Color("#e9b83d"),Color("#65a85b")][(i+j)%3]
				var fruit := _box(scene_root, Vector3(x-0.55+i*0.36,1.0,-3.2+j*0.34), Vector3(0.25,0.22,0.25), fruit_color, "Fruit")
	# Checkout
	_box(scene_root, Vector3(5.4,0.55,3.3), Vector3(2.2,1.1,1.1), Color("#6d8f8a"), "Checkout")
	_box(scene_root, Vector3(5.4,1.15,3.3), Vector3(1.2,0.08,0.65), Color("#303c42"), "Register")
	# Cooler
	_box(scene_root, Vector3(5.7,1.35,-4.8), Vector3(1.5,2.7,0.8), Color("#8eb9c1"), "Cooler")
	for y in range(3):
		_box(scene_root, Vector3(5.7,0.55+y*0.72,-4.32), Vector3(1.28,0.04,0.04), Color("#eaf6f5"), "Cooler shelf")
	# Tiny low-poly customers
	for i in range(5):
		var x := -2.4 + float(i%3)*2.0
		var z := -0.4 + float(i/3)*2.0
		_box(scene_root, Vector3(x,0.72,z), Vector3(0.42,1.05,0.34), [Color("#406c91"),Color("#bb7151"),Color("#6c8b54")][i%3], "Customer")
		var head := _box(scene_root, Vector3(x,1.42,z), Vector3(0.38,0.38,0.38), Color("#d9a77d"), "Customer head")
	# Cafe corner starts closed; visible unlock spot
	_box(scene_root, Vector3(-6.0,0.5,4.3), Vector3(3.0,1.0,1.5), Color("#8c6a4e"), "Expansion plot")
	_box(scene_root, Vector3(-6.0,1.15,4.3), Vector3(2.8,0.12,1.3), Color("#e4b65b"), "Expansion sign")
	# Lighting and sky
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-52,-35,0)
	light.light_energy = 1.25
	add_child(light)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_SKY
	e.sky = Sky.new()
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("#b9cbd0")
	e.ambient_light_energy = 0.65
	env.environment = e
	add_child(env)
	camera = Camera3D.new()
	camera.name = "ManagementCamera"
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 17.5
	add_child(camera)
	_update_camera()

func _update_camera():
	if camera:
		camera.position = camera_target + Vector3(camera_distance*0.72, camera_distance*0.88, camera_distance*0.95)
		camera.look_at(camera_target, Vector3.UP)

func _build_ui():
	ui = CanvasLayer.new()
	add_child(ui)
	var top := PanelContainer.new()
	top.position = Vector2(18,16)
	top.size = Vector2(420,94)
	top.add_theme_stylebox_override("panel", _panel_style(Color("#14242a"), 0.93))
	ui.add_child(top)
	var topcol := VBoxContainer.new()
	topcol.add_theme_constant_override("separation", 4)
	top.add_child(topcol)
	var title := Label.new()
	title.text = "  BUSINESS TYCOON 3D"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", GOLD)
	topcol.add_child(title)
	cash_label = Label.new()
	cash_label.add_theme_font_size_override("font_size", 20)
	topcol.add_child(cash_label)
	status_label = Label.new()
	status_label.add_theme_font_size_override("font_size", 15)
	topcol.add_child(status_label)
	var actions := VBoxContainer.new()
	actions.position = Vector2(18,126)
	actions.size = Vector2(230,300)
	actions.add_theme_constant_override("separation", 8)
	ui.add_child(actions)
	_add_button(actions, "Restock shelves  ·  ₹1,000", _restock)
	_add_button(actions, "Improve shop  ·  ₹3,000", _upgrade)
	_add_button(actions, "Serve customers  ·  Earn cash", _serve)
	_add_button(actions, "Unlock café  ·  ₹8,000", _unlock_cafe)
	_add_button(actions, "Next day  ·  Collect profit", _next_day)
	var camera_box := HBoxContainer.new()
	camera_box.position = Vector2(18, get_viewport().get_visible_rect().size.y - 72)
	camera_box.size = Vector2(330,54)
	camera_box.add_theme_constant_override("separation", 8)
	ui.add_child(camera_box)
	_add_button(camera_box, "− Zoom", func(): _zoom(1.8))
	_add_button(camera_box, "+ Zoom", func(): _zoom(-1.8))
	_add_button(camera_box, "Reset view", func(): camera_target=Vector3.ZERO; camera_distance=16.0; _update_camera())
	var hint := Label.new()
	hint.text = "Drag to rotate view  •  Wheel to zoom  •  Tap buttons to manage"
	hint.position = Vector2(270, get_viewport().get_visible_rect().size.y - 42)
	hint.add_theme_color_override("font_color", Color("#17282d"))
	hint.add_theme_font_size_override("font_size", 15)
	ui.add_child(hint)

func _panel_style(color: Color, alpha: float) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(color.r,color.g,color.b,alpha)
	s.corner_radius_top_left = 12
	s.corner_radius_top_right = 12
	s.corner_radius_bottom_left = 12
	s.corner_radius_bottom_right = 12
	s.content_margin_left = 12
	s.content_margin_right = 12
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	return s

func _add_button(parent: Node, text_value: String, callback: Callable):
	var b := Button.new()
	b.text = text_value
	b.custom_minimum_size = Vector2(0,48)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", 16)
	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_stylebox_override("normal", _panel_style(GREEN,1.0))
	b.add_theme_stylebox_override("hover", _panel_style(Color("#329969"),1.0))
	b.add_theme_stylebox_override("pressed", _panel_style(Color("#175b3a"),1.0))
	b.pressed.connect(callback)
	parent.add_child(b)

func _update_ui():
	if cash_label:
		cash_label.text = "  Cash: ₹%s     Day %d" % [str(cash),day]
		status_label.text = "  Level %d  •  Stock %d  •  Upgrades %d%s" % [level,stock,upgrades, "  •  CAFÉ OPEN" if cafe_unlocked else ""]

func _notify(message: String):
	status_label.text = "  " + message
	_update_ui()
	status_label.text = "  " + message

func _restock():
	if cash < 1000:
		_notify("Not enough cash to restock.")
		return
	cash -= 1000
	stock += 20
	_notify("Restocked 20 units. Shelves look full!")
	_update_ui()

func _upgrade():
	if cash < 3000:
		_notify("Need ₹3,000 for the next upgrade.")
		return
	cash -= 3000
	upgrades += 1
	level += 1
	camera_target.x = clamp(camera_target.x + 0.15, -2.0, 2.0)
	_notify("Shop upgraded! Customer capacity increased.")
	_update_ui()

func _serve():
	if stock <= 0:
		_notify("Out of stock! Restock first.")
		return
	var units := mini(stock, randi_range(4,8))
	stock -= units
	var earned := units * (90 + upgrades * 15)
	cash += earned
	_notify("Customers bought %d items. +₹%d" % [units,earned])
	_update_ui()

func _unlock_cafe():
	if cafe_unlocked:
		_notify("Café is already open!")
		return
	if level < 3:
		_notify("Reach Level 3 to unlock the café.")
		return
	if cash < 8000:
		_notify("Need ₹8,000 and Level 3 to open the café.")
		return
	cash -= 8000
	cafe_unlocked = true
	_box(scene_root, Vector3(-6.0,0.9,4.3), Vector3(2.6,1.6,1.2), Color("#c27b49"), "Cafe kiosk")
	_box(scene_root, Vector3(-6.0,1.9,4.3), Vector3(2.7,0.35,1.25), Color("#247a50"), "Cafe sign")
	_notify("Café unlocked! Your business is expanding.")
	_update_ui()

func _next_day():
	day += 1
	var profit := 700 + level*250 + upgrades*350 + (1200 if cafe_unlocked else 0)
	cash += profit
	stock = mini(stock + 5, 100)
	_notify("Day %d complete. Daily profit +₹%d" % [day,profit])
	_update_ui()

func _zoom(amount: float):
	camera_distance = clamp(camera_distance + amount, 8.0, 25.0)
	camera.size = clamp(camera_distance + 1.5, 9.5, 26.5)
	_update_camera()

func _unhandled_input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			dragging = event.pressed
			last_mouse = event.position
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom(-1.2)
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom(1.2)
	elif event is InputEventMouseMotion and dragging:
		var drag_delta: Vector2 = event.position - last_mouse
		last_mouse = event.position
		camera_target.x = clamp(camera_target.x - drag_delta.x*0.025, -5.0, 5.0)
		camera_target.z = clamp(camera_target.z - drag_delta.y*0.025, -4.0, 4.0)
		_update_camera()
	elif event is InputEventScreenDrag:
		camera_target.x = clamp(camera_target.x - event.relative.x*0.025, -5.0, 5.0)
		camera_target.z = clamp(camera_target.z - event.relative.y*0.025, -4.0, 4.0)
		_update_camera()
	elif event is InputEventMagnifyGesture:
		_zoom(-event.factor*2.0)
