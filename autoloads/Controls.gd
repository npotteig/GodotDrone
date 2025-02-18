extends Node


var input_map_path := "%s/InputMap.cfg" % Global.config_dir
var active_controller_guid := ""
var default_controller_guid := ""

var action_list := []


func _ready() -> void:
	create_action_list()


func update_active_device(device: int) -> int:
	active_controller_guid = Input.get_joy_guid(device)
	var config := ConfigFile.new()
	var err := config.load(input_map_path)
	if err == OK or err == ERR_FILE_NOT_FOUND:
		config.set_value("controls", "active_controller_guid", active_controller_guid)
		config.set_value("controls", "active_controller_name", Input.get_joy_name(device))
		err = config.save(input_map_path)
		if err != OK:
			Global.log_error(err, "Error while updating active device in config file.")
	else:
		Global.log_error(err, "Error while updating active device in config file.")
	return err


func update_default_device(device: int) -> int:
	var config := ConfigFile.new()
	var err := config.load(input_map_path)
	if err == OK or err == ERR_FILE_NOT_FOUND:
		if device >= 0:
			default_controller_guid = Input.get_joy_guid(device)
		else:
			default_controller_guid = ""
		config.set_value("controls", "default_controller", default_controller_guid)
		err = config.save(input_map_path)
		if err != OK:
			Global.log_error(err, "Error while updating default device in config file.")
	else:
		Global.log_error(err, "Error while updating default device in config file.")
	return err


func load_input_map(update_controller: bool = false) -> String:
	var config := ConfigFile.new()
	var err := config.load(input_map_path)
	if err == OK:
		var controller_list := get_joypad_guid_list()
		active_controller_guid = config.get_value("controls", "active_controller_guid")
		var active_device := controller_list.find(active_controller_guid)
		if update_controller:
			var default_device := -1
			if config.has_section_key("controls", "default_controller"):
				default_controller_guid = config.get_value("controls", "default_controller")
				default_device = controller_list.find(default_controller_guid)
			if default_device >= 0:
				active_device = default_device
				active_controller_guid = default_controller_guid
				var _discard = update_active_device(active_device)
			if default_device < 0 and !Input.get_connected_joypads().empty():
				active_device = Input.get_connected_joypads()[0]
				var _discard = update_active_device(active_device)
		if active_device >= 0:
			var section := "controls_%s" % [active_controller_guid]
			var actions := config.get_section_keys(section)
			var event: InputEvent
			var current_action := ""
			var action_idx := -1
			var binding_type := 0
			for action in actions:
				if action.begins_with("throttle") or action.begins_with("yaw") \
						or action.begins_with("pitch") or action.begins_with("roll"):
					if ["throttle_up", "yaw_left", "pitch_up", "roll_left"].has(action):
						event = InputEventJoypadMotion.new()
						event.axis = Input.get_joy_axis_index_from_string(config.get_value(section, action))
						event.axis_value = -1.0
						current_action = action
						continue
					elif ["throttle_inverted", "yaw_inverted", "pitch_inverted", "roll_inverted"].has(action):
						if config.get_value(section, action) == true:
							event.axis_value = 1.0
					event.device = active_device
					InputMap.action_erase_events(current_action)
					InputMap.action_add_event(current_action, event)
					if current_action.ends_with("_up"):
						current_action = current_action.replace("up", "down")
						event = event.duplicate()
					elif current_action.ends_with("_left"):
						current_action = current_action.replace("left", "right")
						event = event.duplicate()
					event.axis_value = -event.axis_value
					InputMap.action_erase_events(current_action)
					InputMap.action_add_event(current_action, event)
				else:
					if InputMap.has_action(action):
						current_action = action
						InputMap.action_erase_events(current_action)
						binding_type = config.get_value(section, action)
						for i in range(action_list.size()):
							if action_list[i].action_name == action:
								action_idx = i
								action_list[action_idx].bound = true
								action_list[action_idx].type = binding_type
								break
							action_idx = -1
						continue
					if binding_type == ControllerAction.Type.BUTTON:
						if action == current_action + "_button":
							action_list[action_idx].button = Input.get_joy_button_index_from_string(config.get_value(section, action))
							event = InputEventJoypadButton.new()
							event.device = active_device
							event.button_index = action_list[action_idx].button
							InputMap.action_add_event(current_action, event)
					elif binding_type == ControllerAction.Type.AXIS:
						if action == current_action + "_axis":
							action_list[action_idx].axis = Input.get_joy_axis_index_from_string(config.get_value(section, action))
						elif action == current_action + "_min":
							action_list[action_idx].axis_min = config.get_value(section, action)
						elif action == current_action + "_max":
							action_list[action_idx].axis_max = config.get_value(section, action)
			restore_keyboard_shortcuts()
		else:
			var active_name: String = config.get_value("controls", "active_controller_name")
			var error = """%s not found!
					Please check it is properly plugged in,
					or head to the Controls settings to update your controller.""" % [active_name]
			return error
	elif err != ERR_FILE_NOT_FOUND:
		Global.log_error(err, "Could not open controls configuration file.")
		return "Could not open config file.\nPlease check Controls settings."
	return ""


func create_action_list() -> void:
	var actions := [["arm", "Arm (hold)"],
			["toggle_arm", "Arm (toggle)"],
			["respawn", "Reset drone"],
			["cycle_flight_modes", "Cycle modes"],
			["mode_horizon", "Mode: Horizon"],
			["mode_angle", "Mode: Angle"],
			["mode_speed", "Mode: Speed"],
			["mode_position", "Mode: Position"],
			["mode_turtle", "Mode: Turtle"],
			["mode_launch", "Mode: Launch Control"],
			["altitude_hold", "Altitude hold"]]
	for action in actions:
		action_list.append(ControllerAction.new())
		action_list[-1].init(action[0], action[1])


func get_joypad_guid_list() -> Array:
	var controller_list := Input.get_connected_joypads()
	for i in range(controller_list.size()):
		controller_list[i] = Input.get_joy_guid(controller_list[i])
	
	return controller_list


func restore_keyboard_shortcuts() -> void:
	var e = InputEventKey.new()
	e.scancode = KEY_M
	if not InputMap.action_has_event("cycle_flight_modes", e):
		InputMap.action_add_event("cycle_flight_modes", e)
	e.scancode = KEY_SPACE
	if not InputMap.action_has_event("toggle_arm", e):
		InputMap.action_add_event("toggle_arm", e)
	e.scancode = KEY_BACKSPACE
	if not InputMap.action_has_event("respawn", e):
		InputMap.action_add_event("respawn", e)
