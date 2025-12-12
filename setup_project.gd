@tool
extends EditorScript

func _run():
	print("Running INERTIA Project Setup Tool...")

	# 1. Input Map Configuration
	setup_inputs()

	# 2. Physics Engine Optimization
	setup_physics()

	# 3. Folder Structure Generation
	create_folders()

	# Save changes to project.godot
	var err = ProjectSettings.save()
	if err == OK:
		print("Project setup configuration saved successfully.")
		print("IMPORTANT: Reload the project settings (Project -> Reload Project Settings) or restart the editor to see changes.")
	else:
		printerr("Failed to save project settings. Error code: ", err)

func setup_inputs():
	print("Configuring Input Map (Xbox 360/One Standard)...")

	# Clear existing input actions from ProjectSettings
	# This ensures we start with a clean slate as requested.
	var props = ProjectSettings.get_property_list()
	for prop in props:
		var name = prop["name"]
		if name.begins_with("input/"):
			ProjectSettings.set_setting(name, null)

	# Define actions and their events
	# Structure: { "action_name": { "deadzone": float, "events": [InputEvent...] } }

	var input_config = {}

	# Movement (Left Stick) - Deadzone 0.2
	input_config["move_left"] = create_axis_config(JOY_AXIS_LEFT_X, -1.0, 0.2)
	input_config["move_right"] = create_axis_config(JOY_AXIS_LEFT_X, 1.0, 0.2)
	input_config["move_forward"] = create_axis_config(JOY_AXIS_LEFT_Y, -1.0, 0.2)
	input_config["move_backward"] = create_axis_config(JOY_AXIS_LEFT_Y, 1.0, 0.2)

	# Camera (Right Stick) - Deadzone 0.2
	input_config["look_left"] = create_axis_config(JOY_AXIS_RIGHT_X, -1.0, 0.2)
	input_config["look_right"] = create_axis_config(JOY_AXIS_RIGHT_X, 1.0, 0.2)
	input_config["look_up"] = create_axis_config(JOY_AXIS_RIGHT_Y, -1.0, 0.2)
	input_config["look_down"] = create_axis_config(JOY_AXIS_RIGHT_Y, 1.0, 0.2)

	# Triggers - Deadzone 0.2
	# sprint (Right Trigger / Axis 5)
	input_config["sprint"] = create_axis_config(JOY_AXIS_TRIGGER_RIGHT, 1.0, 0.2)
	# brace (Left Trigger / Axis 4)
	input_config["brace"] = create_axis_config(JOY_AXIS_TRIGGER_LEFT, 1.0, 0.2)

	# Face Buttons
	# jump (Button A / Index 0)
	input_config["jump"] = create_button_config(JOY_BUTTON_A)
	# tackle (Button B / Index 1)
	input_config["tackle"] = create_button_config(JOY_BUTTON_B)
	# pass_ground (Button X / Index 2)
	input_config["pass_ground"] = create_button_config(JOY_BUTTON_X)
	# pass_high (Button Y / Index 3)
	input_config["pass_high"] = create_button_config(JOY_BUTTON_Y)

	# Bumpers
	# hard_tackle (Right Bumper / Index 5)
	input_config["hard_tackle"] = create_button_config(JOY_BUTTON_RIGHT_SHOULDER)
	# mark_target (Left Bumper / Index 4)
	input_config["mark_target"] = create_button_config(JOY_BUTTON_LEFT_SHOULDER)

	# Stick Clicks
	# camera_flick (R3 / Index 9)
	input_config["camera_flick"] = create_button_config(JOY_BUTTON_RIGHT_STICK)

	# Apply configurations to ProjectSettings
	for action in input_config:
		var setting_path = "input/" + action
		ProjectSettings.set_setting(setting_path, input_config[action])

func create_axis_config(axis: int, value: float, deadzone: float) -> Dictionary:
	var event = InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = value

	return {
		"deadzone": deadzone,
		"events": [event]
	}

func create_button_config(button_index: int) -> Dictionary:
	var event = InputEventJoypadButton.new()
	event.button_index = button_index

	# Default deadzone for buttons usually 0.5, rarely matters
	return {
		"deadzone": 0.5,
		"events": [event]
	}

func setup_physics():
	print("Configuring Physics Engine Optimization...")

	# physics/common/physics_ticks_per_second -> 60
	ProjectSettings.set_setting("physics/common/physics_ticks_per_second", 60)

	# physics/3d/default_gravity -> -9.8
	# Note: Standard gravity strength is 9.8. Setting this to -9.8 with a standard (0, -1, 0) vector
	# results in (0, 9.8, 0) which is UP. Assuming this is intentional per instructions.
	ProjectSettings.set_setting("physics/3d/default_gravity", -9.8)

	# physics/3d/solver/default_contact_bias -> 0.05
	ProjectSettings.set_setting("physics/3d/solver/default_contact_bias", 0.05)

	# physics/3d/run_on_separate_thread -> True
	ProjectSettings.set_setting("physics/3d/run_on_separate_thread", true)

func create_folders():
	print("Generating Folder Structure...")

	var folders = [
		"res://Scenes/Characters",
		"res://Scenes/Arena",
		"res://Scripts/Core",
		"res://Scripts/AI",
		"res://Materials/Physics",
		"res://Audio/SFX"
	]

	var dir = DirAccess.open("res://")
	if dir:
		for folder_path in folders:
			if not dir.dir_exists(folder_path):
				var err = dir.make_dir_recursive(folder_path)
				if err == OK:
					print("Created folder: " + folder_path)
				else:
					printerr("Failed to create folder: " + folder_path + " (Error: " + str(err) + ")")
			else:
				print("Folder already exists: " + folder_path)
	else:
		printerr("Could not access res:// root directory.")
