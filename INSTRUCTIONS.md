# Active Ragdoll Setup Instructions

## 1. Scene & Node Hierarchy

Create the following structure in your Scene dock:

```text
PlayerRoot (Node3D)
├── Torso (RigidBody3D)       <-- Attach 'ActiveRagdoll.gd' here
│   ├── CollisionShape3D      <-- Shape: CapsuleShape3D
│   ├── RayCast3D             <-- Rename to 'GroundRay', Pointing: Down (Target Position: 0, -2, 0)
│   └── CameraPivot (Node3D)  <-- Optional: To hold your Camera3D
│       └── Camera3D
└── Head (RigidBody3D)        <-- Optional: For the head
    ├── CollisionShape3D      <-- Shape: SphereShape3D
    └── ConeTwistJoint3D      <-- Connects Torso (Node A) to Head (Node B)
```

**Notes:**
- **PlayerRoot**: Acts as a container.
- **Torso**: The main body that moves and balances.
- **RayCast3D**: Used for the "Leg Suspension". Ensure it is enabled!
- **Joints**: If you add a Head or Arms, use joints to connect them to the Torso.

## 2. RigidBody3D Settings (Torso)

Select the `Torso` node and adjust these settings in the Inspector to ensure stability:

*   **Mass**: `1.0` (Default is fine, but if you increase it, increase `move_speed` and `jump_force` proportionally).
*   **Physics Material Override**:
    *   Create a new `PhysicsMaterial`.
    *   **Friction**: `0.5` (Adjust as needed).
    *   **Bounce**: `0.0`.
*   **Linear > Damping**: `0.5` (Helps stop sliding when force stops).
*   **Angular > Damping**: `1.0` (Crucial to prevent the body from spinning out of control even with the self-balancing script).
*   **Axis Lock**: None (The script handles staying upright).

## 3. Script Configuration

Select the `Torso` node (where the script is attached) and set the Export Variables in the Inspector:

*   **Movement**:
    *   `Move Speed`: `50.0` (Tweak this to feel right).
    *   `Sprint Multiplier`: `1.5`.
    *   `Jump Force`: `500.0`.
*   **Balancing**:
    *   `Upright Torque`: `100.0` (Higher = stiffer, harder to knock over).
    *   `Upright Damping`: `5.0` (Higher = less wobble, slower return to upright).
*   **Suspension (Legs)**:
    *   `Suspension Height`: `1.2` (How high the torso floats above ground).
    *   `Suspension Spring`: `200.0`.
    *   `Suspension Damp`: `10.0`.
    *   `Ground Ray Path`: Assign the `RayCast3D` node here.
*   **References**:
    *   `Camera Path`: Assign your `Camera3D` node so movement is relative to the view.

## 4. Input Map Setup

Go to **Project > Project Settings > Input Map** and add these actions:

*   `move_left`
*   `move_right`
*   `move_up` (Forward)
*   `move_down` (Backward)
*   `sprint` (e.g., Joystick Trigger or Shift key)
*   `jump` (e.g., Joystick Button A or Space bar)
