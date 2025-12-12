extends RigidBody3D

# ActiveRagdoll.gd
# Core character controller for a physically simulated character.

enum State { NORMAL, TACKLING, CRUMPLED }
var current_state: State = State.NORMAL

@export_group("Movement")
@export var move_speed: float = 50.0 # Force multiplier for running
@export var sprint_multiplier: float = 1.5
@export var jump_force: float = 500.0 # Impulse strength

@export_group("Combat")
@export var tackle_force: float = 1000.0 # Impulse strength for tackling
@export var tackle_duration: float = 0.5 # Duration of TACKLING state
@export var tackle_cooldown: float = 1.0 # Time before next tackle
@export var tackle_stamina_cost: float = 20.0
@export var brace_mass_multiplier: float = 1.5
@export var brace_angular_damp_add: float = 2.0
@export var impact_threshold: float = 5.0 # Velocity threshold for crumbling.
@export var crumple_duration: float = 2.0

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

# Internal Combat Variables
var _tackle_timer: float = 0.0
var _cooldown_timer: float = 0.0
var _crumple_timer: float = 0.0
var _default_mass: float
var _default_angular_damp: float
var _is_bracing: bool = false

func _ready():
	current_stamina = max_stamina
	_default_mass = mass
	_default_angular_damp = angular_damp

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

	# Timer Updates
	if _tackle_timer > 0:
		_tackle_timer -= delta
		if _tackle_timer <= 0 and current_state == State.TACKLING:
			current_state = State.NORMAL

	if _cooldown_timer > 0:
		_cooldown_timer -= delta

	if current_state == State.CRUMPLED:
		_crumple_timer -= delta
		if _crumple_timer <= 0:
			current_state = State.NORMAL
			# Restore upright force implied by state change

	# Logic Routing
	_handle_combat_inputs(state, delta) # Handle inputs regardless of state (mostly for brace)

	if current_state != State.CRUMPLED:
		_handle_balancing(state)

	if current_state == State.NORMAL:
		_handle_movement(state, delta)
		_handle_suspension_and_jump(state)
	elif current_state == State.TACKLING:
		# Maybe allow suspension so they don't fall through floor, but no movement control
		_handle_suspension_and_jump(state)
		# No _handle_movement (steering disabled during tackle)

	# Collisions & Crumple Logic
	_handle_collisions(state)

func _handle_combat_inputs(state: PhysicsDirectBodyState3D, delta: float):
	# 3. The Brace Mechanic
	# Check Brace Input (LT)
	if Input.is_action_pressed("brace"):
		if not _is_bracing:
			mass = _default_mass * brace_mass_multiplier
			angular_damp = _default_angular_damp + brace_angular_damp_add
			_is_bracing = true
	else:
		if _is_bracing:
			mass = _default_mass
			angular_damp = _default_angular_damp
			_is_bracing = false

	# 2. The Tackle
	# Can only initiate tackle in NORMAL state and if cooldown allows
	if current_state == State.NORMAL and _cooldown_timer <= 0:
		if Input.is_action_just_pressed("tackle") or Input.is_action_just_pressed("hard_tackle"):
			if current_stamina > 20: # Check threshold
				_perform_tackle()

func _perform_tackle():
	current_state = State.TACKLING
	_tackle_timer = tackle_duration
	_cooldown_timer = tackle_cooldown
	# Optional: Consume stamina? The prompt says "Can only tackle if stamina > 20".
	# Usually this implies cost.
	current_stamina -= 20.0

	# Calculate Tackle Direction
	var tackle_dir = Vector3.FORWARD
	if _camera:
		tackle_dir = -_camera.global_transform.basis.z
	else:
		# Fallback to global forward if no camera
		tackle_dir = Vector3.FORWARD

	tackle_dir.y = 0
	tackle_dir = tackle_dir.normalized()

	# Apply Massive Impulse
	apply_central_impulse(tackle_dir * tackle_force)

func _handle_collisions(state: PhysicsDirectBodyState3D):
	# 4. Collision & "The Crumple"
	var contact_count = state.get_contact_count()
	if contact_count > 0:
		for i in range(contact_count):
			var collider = state.get_contact_collider_object(i)
			if collider is RigidBody3D:
				# Check relative velocity
				var v1 = state.get_contact_local_velocity_at_position(i)
				var v2 = state.get_contact_collider_velocity_at_position(i)
				var relative_velocity = (v1 - v2).length()

				# Prompt says: "If the player collides with another RigidBody at a high velocity (e.g., relative velocity > 5.0)"
				if relative_velocity > 5.0:
					# Check Brace
					var effective_impact = relative_velocity
					if _is_bracing:
						effective_impact *= 0.5 # "reduce the impact force calculation"

					play_impact_sound(effective_impact)

					if effective_impact > impact_threshold:
						# Trigger Crumple
						current_state = State.CRUMPLED
						_crumple_timer = crumple_duration
						break # Only crumple once per frame

func play_impact_sound(intensity):
	print("playing thud sound: [%s]" % intensity)

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
