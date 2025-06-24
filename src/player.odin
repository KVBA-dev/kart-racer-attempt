package main

import "core:fmt"
import "core:math"
import la "core:math/linalg"
import rl "vendor:raylib"

hl: f32

Player :: struct {
	wheels:        [4]WheelRaycaster,
	rb:            Rigidbody,
	collider:      SphereCollider,
	rotation:      rl.Quaternion,
	position:      rl.Vector3,
	localUp:       rl.Vector3,
	orientationUp: rl.Vector3,
	isGrounded:    bool,
}

create_player :: proc() -> ^Player {
	p := new(Player)
	p.collider = SphereCollider {
		radius = .3,
	}
	p.rotation = la.QUATERNIONF32_IDENTITY
	p.localUp = {0, 1, 0}
	p.rb.mass = 200
	p.rb.linVel = {0, 0, 0}
	p.rb.angVel = {0, 0, 0}
	for i in 0 ..< 4 {
		p.wheels[i] = WheelRaycaster {
			length = p.collider.radius * 1.05,
			normal = {0, 1, 0},
		}
		switch i {
		case 0:
			p.wheels[i].relPosition = {-1, 0, -1} * p.collider.radius
		case 1:
			p.wheels[i].relPosition = {-1, 0, 1} * p.collider.radius
		case 2:
			p.wheels[i].relPosition = {1, 0, -1} * p.collider.radius
		case 3:
			p.wheels[i].relPosition = {1, 0, 1} * p.collider.radius
		case:
			panic("something went REALLY wrong")
		}
	}
	return p
}

player_update :: proc(using player: ^Player, dt: f32) {
	axisH: f32 = (Input.keys[.D].held ? 1 : 0) - (Input.keys[.A].held ? 1 : 0)
	axisV: f32 = (Input.keys[.W].held ? 1 : 0) - (Input.keys[.S].held ? 1 : 0)

	moveDir := player_forward(player)
	up := player_up(player)

	maxSpeed: f32 = axisV > 0 ? 25 : 10
	desiredVel := moveDir * (axisV * maxSpeed)

	currentVel := rb.linVel
	currentHorzVel := currentVel - localUp * la.dot(currentVel, localUp)

	isGrounded = false
	for &w in wheels {
		update_wheel(&w, player, -up)
		isGrounded |= w.isGrounded
	}

	if isGrounded {
		acceleration: f32 = 1.0
		forceDir := (desiredVel - currentHorzVel)
		if la.length2(forceDir) > 0 {
			forceDir = la.normalize(forceDir)
			forceMagnitude := la.length(desiredVel - currentHorzVel) * rb.mass * acceleration
			add_force(&rb, forceDir * forceMagnitude)
		}

		if axisV == 0 && la.length2(currentHorzVel) > 0 {
			brakingForce := -la.normalize(currentHorzVel) * rb.mass * 0.01
			add_force(&rb, brakingForce)
		}
	}

	if axisH != 0 {
		turnSpeed: f32 = 60.0
		turnAmount := -axisH
		if isGrounded && la.length2(rb.linVel) > 0 {
			turnAmount *=
				la.dot(moveDir, la.normalize(rb.linVel)) *
				la.clamp(la.length(rb.linVel / maxSpeed), 0, 1)
		}
		rotation =
			la.quaternion_angle_axis_f32(turnAmount * turnSpeed * dt * math.RAD_PER_DEG, localUp) *
			rotation
	}

	collider.center = position
}

player_orient_towards_up :: proc(
	using player: ^Player,
	mesh: rl.Mesh,
	dt: f32,
	maxDistance: f32 = 10,
) {

	ray := rl.Ray {
		position  = position,
		direction = -player_up(player),
	}

	orientationUp = localUp
	collision := rl.GetRayCollisionMesh(ray, mesh, rl.Matrix(1))
	if collision.hit && collision.distance < maxDistance {
		orientationUp = collision.normal
	}
	fmt.println("orientationUp =", orientationUp)

	angle := la.angle_between(localUp, orientationUp)
	axis := la.cross(orientationUp, player_up(player))
	fmt.println("axis =", axis)
	if la.length2(axis) == 0 do return
	rotation = la.quaternion_angle_axis_f32(-angle * 8 * dt, axis) * rotation
}


// TODO: interact with other objects
allCollisions: [dynamic]Collision
player_physics_update :: proc(using player: ^Player, dt: f32) {
	GRAVITY :: 10.0

	add_force(&rb, rl.Vector3{0, -GRAVITY * rb.mass, 0})
	rigidbody_update(&rb, dt)

	clear(&allCollisions)
	for &mc in StaticColliders {
		collisions := CheckCollisionMeshSphere(mc.mesh, collider)
		append(&allCollisions, ..collisions)
	}
	sort_collisions_by_grounding(allCollisions[:], localUp)
	for c in allCollisions {
		normal := -c.direction
		v_normal := la.dot(rb.linVel, normal)
		if v_normal < 0 {
			impulse := -v_normal * rb.mass
			rb.linVel += (impulse / rb.mass) * normal
		}
		position += normal * c.distance * .6
	}
	rigidbody_update_position(&rb, &position, &rotation, dt)
	rigidbody_end_timestep(&rb)
}

player_render :: proc(using player: ^Player, model: ^rl.Model) {
	rot := rotation * la.quaternion_from_euler_angle_y_f32(math.PI)
	an, ax := la.angle_axis_from_quaternion(rot)

	if math.is_nan(ax.x) || math.is_nan(ax.y) || math.is_nan(ax.z) {
		ax = rl.Vector3{0, 0, 0}
	}

	// rotation glitch fix

	forw := player_forward(player)
	if forw.z <= -.5 {
		an = an - math.TAU
	}
	if abs(rotation.w) < .5 && rotation.z < 0 {
		an = math.TAU - an
	}


	rl.DrawModelEx(model^, position, ax, an * math.DEG_PER_RAD, {1, 1, 1}, rl.WHITE)
}

player_forward :: proc(using player: ^Player) -> rl.Vector3 {
	return la.quaternion_mul_vector3(rotation, rl.Vector3{0, 0, 1})
}

player_up :: proc(using player: ^Player) -> rl.Vector3 {
	return la.quaternion_mul_vector3(rotation, rl.Vector3{0, 1, 0})
}

player_right :: proc(using player: ^Player) -> rl.Vector3 {
	return la.quaternion_mul_vector3(rotation, rl.Vector3{1, 0, 0})
}

player_transform :: proc(using player: ^Player) -> rl.Matrix {
	x, y, z := la.euler_angles_xyz_from_quaternion(rotation)
	return rl.MatrixRotateXYZ({x, y, z}) + rl.MatrixTranslate(position.x, position.y, position.z)
}
