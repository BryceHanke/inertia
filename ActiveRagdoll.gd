extends RigidBody3D

# ActiveRagdoll.gd
# Core character controller for a physically simulated character.

@export_group("Movement")
@export var move_speed: float = 50.0 # Force multiplier for running
@export var sprint_multiplier: float = 1.5
@export var jump_force: float = 500.0 # Impulse strength

@export_group("Balancing")
@export var upright_torque: float = 100.0 # How hard it tries to stand up
@export var upright_damping: float = 5.0 # Reduces wobble

@export_group("Suspension (Legs)")
@export var suspension_height: float = 1.2 # Target hover height
@export var suspension_spring: float = 200.0 # Spring stiffness
@export var suspension_damp: float = 10.0 # Spring damping
@export var ground_ray_path: NodePath = "RayCast3D"

@export_group("Stamina")
@export var max_stamina: float = 100.0
@export var stamina_drain_rate: float = 20.0
@export var stamina_regen_rate: float = 10.0

@export_group("References")
@export var camera_path: NodePath

var current_stamina: float = 100.0
var _ground_ray: RayCast3D
var _camera: Camera3D

func _ready():
	current_stamina = max_stamina
	if has_node(ground_ray_path):
		_ground_ray = get_node(ground_ray_path)
		_ground_ray.add_exception(self)

	if camera_path and has_node(camera_path):
		_camera = get_node(camera_path)
	else:
		# Fallback to finding a camera if not assigned
		var viewport = get_viewport()
		if viewport:
			_camera = viewport.get_camera_3d()

func _integrate_forces(state: PhysicsDirectBodyState3D):
	var delta = state.step

	_handle_balancing(state)
	_handle_movement(state, delta)
	_handle_suspension_and_jump(state)

func _handle_balancing(state: PhysicsDirectBodyState3D):
	# Calculate the rotation difference between the Torso's current up vector and Vector3.UP
	var current_up = global_transform.basis.y
	var target_up = Vector3.UP

	# Cross product gives the axis of rotation needed to align current_up to target_up
	var axis = current_up.cross(target_up)

	# Calculate torque
	# Proportional term: tries to align the body
	var p_term = axis * upright_torque

	# Derivative term: fights the angular velocity to prevent wobbling
	var d_term = -state.angular_velocity * upright_damping

	apply_torque(p_term + d_term)

func _handle_movement(state: PhysicsDirectBodyState3D, delta: float):
	# Get input
	# Assuming Input Map actions: "move_left", "move_right", "move_forward", "move_backward", "sprint"
	var input_dir = Vector2.ZERO
	input_dir.x = Input.get_axis("move_left", "move_right")
	input_dir.y = Input.get_axis("move_forward", "move_backward") # forward/back

	# Stamina Logic
	var is_sprinting = Input.is_action_pressed("sprint")
	var speed_mult = 1.0

	if is_sprinting and current_stamina > 0:
		speed_mult = sprint_multiplier
		current_stamina -= stamina_drain_rate * delta
	else:
		# Regenerate stamina if not sprinting
		if not is_sprinting:
			current_stamina += stamina_regen_rate * delta

	# Clamp stamina
	current_stamina = clamp(current_stamina, 0, max_stamina)

	if input_dir.length() > 0:
		input_dir = input_dir.normalized()

		var forward = Vector3.FORWARD
		var right = Vector3.RIGHT

		# If a camera is available, move relative to the camera view
		if _camera:
			var cam_basis = _camera.global_transform.basis
			forward = -cam_basis.z
			right = cam_basis.x

		# Flatten vectors to the horizontal plane to avoid flying/digging
		forward.y = 0
		right.y = 0
		forward = forward.normalized()
		right = right.normalized()

		# Calculate movement direction
		# input_dir.y is "up/down" (forward/back), so negative y is forward usually?
		# Standard WASD: W (up) is negative Y in 2D, but let's assume "move_up" means Forward.
		# If "move_up" is positive 1.0, and we want to go forward:
		# Let's assume standard mapping: move_up (W) -> 1.0 ? Usually get_axis(neg, pos).
		# If move_up is the negative arg: get_axis("move_up", "move_down") -> W = -1.
		# Let's stick to standard input vector logic.
		# move_dir = forward * -input_dir.y + right * input_dir.x

		# However, if user maps "move_up" to W and "move_down" to S,
		# get_axis("move_down", "move_up") returns 1 for W.
		# The prompt says "move_up", "move_down". Let's assume input_dir.y captures Forward/Back.
		# To be safe, let's treat input_dir.y < 0 as forward (Up on stick).

		var move_force_dir = (forward * -input_dir.y + right * input_dir.x).normalized()

		# Apply Force
		apply_central_force(move_force_dir * move_speed * speed_mult)

func _handle_suspension_and_jump(state: PhysicsDirectBodyState3D):
	if not _ground_ray:
		return

	if _ground_ray.is_colliding():
		var hit_point = _ground_ray.get_collision_point()
		var ray_origin = _ground_ray.global_transform.origin
		var distance = ray_origin.distance_to(hit_point)

		# Calculate spring compression
		# suspension_height is the desired distance from ray origin to ground
		var compression = suspension_height - distance

		if compression > 0:
			var spring_dir = Vector3.UP # Simple approximation, or use contact normal

			# Spring Force: F = k * x
			var spring_force_mag = compression * suspension_spring

			# Damping Force: F = -b * v
			# We need vertical velocity
			var vertical_velocity = state.linear_velocity.dot(Vector3.UP)
			var damping_force_mag = -vertical_velocity * suspension_damp

			var total_upward_force = spring_force_mag + damping_force_mag

			# Apply to body
			apply_central_force(spring_dir * total_upward_force)

			# Jump Logic
			# Only jump if grounded (ray is colliding and compressed/hovering)
			if Input.is_action_just_pressed("jump"):
				apply_central_impulse(Vector3.UP * jump_force)
