extends CharacterBody2D

@onready var detection_zone = $DetectionZone
@onready var visible_zone = $VisibleZone
@onready var radar_zone = $RadarZone

@onready var speed_label = $Camera2D/UI/RichTextLabel
@onready var health_label = $Camera2D/UI/LifeBar/Label

@onready var green_bar = $Camera2D/UI/LifeBar/GreenBar
@onready var boost_bar = $Camera2D/UI/BoostBar
@onready var boost_timer = $BoostTimer

@onready var bodies_indicators = $BodiesIndicators
@onready var crosshair = $CollisionShape2D/Crosshair
@onready var inertia_crosshair = $InertiaCrosshair

@onready var bg_circle = $Camera2D/UI/Minimap/BGCircle
@onready var minimap = $Camera2D/UI/Minimap
@onready var minimap_points = $Camera2D/UI/Minimap/Points
@onready var minimap_center = $Camera2D/UI/Minimap/Center

const INDICATOR_MARGIN = 50
const MINIMAP_RADIUS = 100
const MINIMAP_POINT_RADIUS = 5
const LINE_INERTIA_SEGMENT_COUNT = 10

@export var maxspeed = 300.
@export var acceleration = 100.
@export var rotationnalspeed = PI/60.
@export var boost = 200.
var can_boost = true
var maxhealth = 200.
var health = maxhealth

#var bodies_detected = []
#var bodies_visible = []
var areas_radar = []
var areas_detected = []
var areas_visible = []
var indicator_polygon = PackedVector2Array([Vector2(0, -15), Vector2(-10, 8), Vector2(0, 12), Vector2(10, 8)])
var wb_regex = RegEx.new()
var minimap_point_polygon = create_circle(8, MINIMAP_POINT_RADIUS)

func _ready():
	wb_regex.compile(r'(WB_.*)|(Player)')
	bg_circle.polygon = create_circle(360, MINIMAP_RADIUS)
	minimap_center.polygon = create_circle(8, 3)
	inertia_crosshair.position = Vector2(0, -250)
	
		
func _physics_process(delta):
	handle_movement(delta)
	handle_indicators()
	handle_minimap()
	
	print()
	
	crosshair.rotation = - $CollisionShape2D.rotation
	inertia_crosshair.position = velocity.normalized() * 250 if velocity != Vector2.ZERO else inertia_crosshair.position
	health_label.text = str(int(health)) + " HP"
	green_bar.scale.x = health/maxhealth
	boost_bar.scale.x = boost_timer.time_left / boost_timer.wait_time
	queue_redraw()
	
func _draw():
	var dashed_line_inertia_points = []
	for i in range(LINE_INERTIA_SEGMENT_COUNT):
		var point = ((inertia_crosshair.global_position - global_position) / (LINE_INERTIA_SEGMENT_COUNT)) * i
		var margin = ((inertia_crosshair.global_position - global_position) / (LINE_INERTIA_SEGMENT_COUNT)) * 0.11
		dashed_line_inertia_points.push_back(point)
		dashed_line_inertia_points.push_back(point + margin)
	draw_multiline(PackedVector2Array(dashed_line_inertia_points), Color(1, 1, 1, 0.25), 3)
	
## Handles all of the movement and updates the speed label
func handle_movement(delta: float) -> void:
	var direction_input = Input.get_vector("left", "right", "up", "down")
	var acceleration_delta = acceleration * delta
	
	# Stabilisation
	if Input.is_action_pressed("stop"):	
		velocity = velocity.normalized() * max(0, velocity.length() - acceleration_delta)
		
	# Boost
	if can_boost and velocity.length() < maxspeed + boost and Input.is_action_just_pressed("boost"):	
		can_boost = false
		$BoostTimer.start()
		if direction_input.y == 0:
			velocity += Vector2(0, -boost).rotated($CollisionShape2D.rotation)
		else:
			velocity += Vector2(0, direction_input.y * boost).rotated($CollisionShape2D.rotation)
		velocity = velocity.normalized() * min(maxspeed + boost, velocity.length())
		
	else: # No boost ? 
		velocity += Vector2(0, direction_input.y * acceleration_delta).rotated($CollisionShape2D.rotation)
		
	# NOTE: If overspeed, slow down by 2x acceleration so cant maintain speed if pressing w/z
	velocity = velocity.normalized() * (velocity.length() - 2 * acceleration_delta) if velocity.length() > maxspeed else velocity
	
	$CollisionShape2D.rotation += direction_input.x * rotationnalspeed
	move_and_slide()
	
	speed_label.text = "[i]%4d km/h[/i]" %  int(velocity.length())
	
	
## Handles the indicators poiting to the enemies offscreen
func handle_indicators() -> void:
	var indicators_name_list = []
	for node in bodies_indicators.get_children():
		indicators_name_list.append(node.name)
		
	for area in areas_detected:
		if area not in areas_visible: # Body near but outside of screen
			var indicator
			
			# Indicator not yet created
			if area.name not in indicators_name_list:
				indicator = Polygon2D.new()
				indicator.name = area.name
				indicator.polygon = indicator_polygon
				indicator.color = Color(0.9, 0.1, 0.1, 1)	
				bodies_indicators.add_child(indicator)	

			# Indicator already created
			else:			
				for node in bodies_indicators.get_children():
					if node.name == area.name:
						indicator = node
						break
			
			indicator.rotation = (area.position - position).angle() + PI/2
			
			var screen_position = area.position - position
			indicator.position.x = max(INDICATOR_MARGIN - get_window().size.x/2, min(get_window().size.x/2 - INDICATOR_MARGIN, screen_position.x))
			indicator.position.y = max(INDICATOR_MARGIN - get_window().size.y/2, min(get_window().size.y/2 - INDICATOR_MARGIN, screen_position.y))
	
	
## Handles all aspects related to the minimap
func handle_minimap() -> void:
	var points_name_list = []
	
	for node in minimap_points.get_children():
		points_name_list.append(node.name)
		
	for area in areas_radar:
		var point_position = (area.position - position) / (detection_zone.get_child(0).scale.x * 20)
		if point_position.length() > 1:	# Outside of minimap
			continue
		
		var point: Polygon2D
		if area.name not in points_name_list:	# Point not yet created
			point = Polygon2D.new()
			point.name = area.name
			point.polygon = minimap_point_polygon
			point.color = Color(0.9, 0.1, 0.1, 1)	
			minimap_points.add_child(point)	

		else:	# Point already created		
			for node in minimap_points.get_children():
				if node.name == area.name:
					point = node
					break
					
		point.position = bg_circle.position + point_position * MINIMAP_RADIUS

	
## Returns the data representing a circle to be used in a Polygon2D
func create_circle(sides: int, radius: int) -> PackedVector2Array:
	var polygon_array = PackedVector2Array()
	var range_sides = []
	
	for i in range(sides): range_sides.push_back((360./sides) * i)
	
	for i in range_sides:
		var angle = deg_to_rad(i)
		polygon_array.push_back(Vector2(cos(angle), sin(angle)) * radius)
	return polygon_array
	
## ===================================================
## =============== Functions connected ===============
## ===================================================
			
func _on_boost_timer_timeout():
	can_boost = true
	boost_timer.stop()

#func _on_detection_zone_body_entered(body):
	#if not wb_regex.search(body.name):
		#bodies_detected.append(body)
#
#func _on_detection_zone_body_exited(body):
	#bodies_detected.erase(body)
#
#func _on_visible_zone_body_entered(body):
	#if not wb_regex.search(body.name):
		#bodies_visible.append(body)
#
#func _on_visible_zone_body_exited(body):
	#bodies_visible.erase(body)

func _on_detection_zone_area_entered(area):
	if not area.owner.name == "Player":
		areas_detected.append(area)
		
func _on_detection_zone_area_exited(area):
	areas_detected.erase(area)
		
	for indicator in bodies_indicators.get_children():
		if indicator.name == area.name:
			indicator.queue_free()
			break

func _on_visible_zone_area_entered(area):
	if not area.owner.name == "Player":
		areas_visible.append(area)
		
	for indicator in bodies_indicators.get_children():
		if indicator.name == area.name:
			indicator.queue_free()
			break
		
func _on_visible_zone_area_exited(area):
		areas_visible.erase(area)

func _on_radar_zone_area_entered(area):
	if not area.owner.name == "Player":
		areas_radar.append(area)

func _on_radar_zone_area_exited(area):
	areas_radar.erase(area)
	
	for point in minimap_points.get_children():
		if point.name == area.name:
			point.queue_free()
			break
