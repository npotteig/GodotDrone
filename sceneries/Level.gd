extends Spatial


var pause_menu = preload("res://GUI/PauseMenu.tscn")

var cameras := []
var camera_index := 0
var camera: Camera = null

onready var drone := $Drone
onready var radio_controller := $RadioController

var tracks := []


func _ready() -> void:
	cameras = get_cameras(self)
	for c in cameras:
		if c.name == "FPVCamera":
			camera_index = cameras.find(c)
	camera = cameras[camera_index]
	change_camera()
	
	for c in get_children():
		if c is Track:
			tracks.append(c)
	var _discard = Global.connect("game_mode_changed", self, "_on_game_mode_changed")
	
	_discard = drone.connect("respawned", self, "_on_drone_reset")
	
	pause_menu = pause_menu.instance()
	add_child(pause_menu)
	pause_menu.visible = false
	_discard = pause_menu.connect("resumed", self, "_on_resume")
	_discard = pause_menu.connect("menu", self, "_on_return_to_menu")


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("change_camera"):
		camera_index += 1
		if camera_index >= cameras.size():
			camera_index = 0
		change_camera()
	
	if event.is_action("pause_menu") and event.is_pressed() and not event.is_echo():
		if !get_tree().paused:
			get_tree().paused = true
			pause_menu.visible = true
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		elif pause_menu.visible and pause_menu.can_resume:
			pause_menu.emit_signal("resumed")


func get_cameras(node: Node) -> Array:
	var cams := []
	for child in node.get_children():
		if child is Camera:
			cams.append(child)
		if not child is FPVCamera:
			cams += get_cameras(child)
	return cams


func change_camera() -> void:
	camera.visible = false
	camera.current = false
	if camera is FPVCamera and Graphics.graphics_settings["fisheye_mode"] != Graphics.FisheyeMode.OFF:
		camera.render_quad.visible = false
	camera = cameras[camera_index]
	camera.current = true
	if camera is FPVCamera and Graphics.graphics_settings["fisheye_mode"] != Graphics.FisheyeMode.OFF:
		camera.render_quad.visible = true
	camera.visible = true
	
	if camera is FPVCamera:
		drone.hud.visible = true
	else:
		drone.hud.visible = false


func _on_drone_reset() -> void:
	for track in tracks:
		track.reset_track()
	if Global.game_mode == Global.GameMode.RACE and Global.active_track:
		Global.active_track.initialize_replay(drone)
		Global.active_track.load_replays()
		Global.active_track.start_countdown()


func _on_resume() -> void:
	if pause_menu.can_resume:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		pause_menu.visible = false
		get_tree().paused = false


func _on_return_to_menu() -> void:
	var _discard = get_tree().change_scene("res://GUI/MainMenu.tscn")
	queue_free()


func _on_game_mode_changed(mode: int) -> void:
	if mode == Global.GameMode.FREE or tracks.empty():
		if Global.active_track:
			Global.active_track.stop_race()
			Global.active_track.stop_recording_replay()
		Global.active_track = null
	elif mode == Global.GameMode.RACE:
		Global.active_track = get_closest_track()
		drone.reset()


func get_closest_track() -> Track:
	var has_launchpad := false
	var closest_idx := 0
	var new_idx := -1
	var closest_distance := 9999.9
	var new_distance := 0.0
	if tracks.empty():
		return null
	for track in tracks:
		new_idx += 1
		if not track.has_launchpad:
			continue
		has_launchpad = true
		for launch_pos in track.launch_areas:
			new_distance = (launch_pos.global_transform.origin - drone.global_transform.origin).length()
			if new_distance < closest_distance:
				closest_distance = new_distance
				closest_idx = new_idx
	if has_launchpad:
		return tracks[closest_idx]
	return null
