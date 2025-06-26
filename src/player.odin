package main

import "core:fmt"
import "core:math"
import la "core:math/linalg"
import "core:time"
import rl "vendor:raylib"

hl: f32

Player :: struct {
	wheels:     [3]WheelRaycaster, // 29 * 3 = 87
	rb:         Rigidbody, // 40
	rotation:   rl.Quaternion, // 16
	position:   rl.Vector3, // 12
	localUp:    rl.Vector3, // 12
	up:         rl.Vector3, // 12
	forw:       rl.Vector3, // 12
	right:      rl.Vector3, // 12
	axisV:      f32, // 4
	axisH:      f32, // 4
	radius:     f32, // 4
	isGrounded: bool, // 1
}

create_player :: proc() -> Player {
	p := Player{}
	p.radius = .4
	p.rotation = la.QUATERNIONF32_IDENTITY
	p.localUp = {0, 1, 0}
	p.rb.mass = 200
	p.rb.linVel = {0, 0, 0}
	for i in 0 ..< 3 {
		p.wheels[i] = WheelRaycaster {
			length = p.radius * 1.05,
			normal = {0, 1, 0},
		}
		switch i {
		case 0:
			p.wheels[i].relPosition = {0, 0, 1} * p.radius
		case 1:
			p.wheels[i].relPosition = {-0.7, 0, -0.5} * p.radius
		case 2:
			p.wheels[i].relPosition = {0.7, 0, -0.5} * p.radius
		case:
			panic("something went REALLY wrong")
		}
	}
	return p
}

player_update :: proc(using player: ^Player, dt: f32) {
	up = player_up(player)
	forw = player_forward(player)
	right = player_right(player)
	moveDir := forw

	maxSpeed: f32 = axisV >= 0 ? 25 : 10
	desiredVel := moveDir * axisV * maxSpeed

	currentVel := rb.linVel
	currentHorzVel := currentVel - localUp * la.dot(currentVel, localUp)

	isGrounded = false
	for &w in wheels {
		update_wheel(&w, player, -up)
		isGrounded |= w.isGrounded
	}

	if isGrounded {
		acceleration: f32 = 20.0
		forceVec := desiredVel - currentHorzVel
		forceMag := la.length(forceVec)
		if forceMag > 0 {
			forceDir := forceVec / forceMag
			forceMagnitude := forceMag * acceleration
			add_force(&rb, forceVec * forceMagnitude)
		}

		if axisV == 0 && la.length2(currentHorzVel) > 0 {
			brakingForce := -la.normalize(currentHorzVel) * 10
			add_force(&rb, brakingForce)
		}
	}

	if axisH != 0 {
		turnSpeed: f32 = 100.0
		turnAmount := -axisH
		if isGrounded && la.length2(rb.linVel) > 0 {
			turnAmount *= la.clamp(la.length(rb.linVel / maxSpeed), 0, 1)
		}
		rotation =
			la.quaternion_angle_axis_f32(turnAmount * turnSpeed * dt * math.RAD_PER_DEG, localUp) *
			rotation
	}

}

player_orient_towards_up :: proc(
	using player: ^Player,
	mesh: ^Octree,
	dt: f32,
	maxDistance: f32 = 10,
) {
	ray := rl.Ray {
		position  = position,
		direction = -player_up(player),
	}

	orientationUp := localUp
	collision := CheckCollisionMeshRay(mesh, ray)
	if collision.hit && collision.distance < maxDistance {
		orientationUp = collision.normal
	}
	angle := angle_between_norm(localUp, orientationUp)
	axis := la.cross(orientationUp, up)
	if la.length2(axis) == 0 do return
	rotation = la.quaternion_angle_axis_f32(-angle * 2 * dt, axis) * rotation
}

// TODO: interact with other objects
allCollisions: [dynamic]Collision
player_physics_update :: proc(using player: ^Player, dt: f32) {
	GRAVITY :: 10.0

	add_acceleration(&rb, rl.Vector3{0, -GRAVITY, 0})
	localVel := rl.Vector3 {
		la.dot(right, rb.linVel),
		la.dot(up, rb.linVel),
		la.dot(forw, rb.linVel),
	}

	if isGrounded {
		sidewaysForce := localVel.x * 0.99
		add_acceleration(&rb, sidewaysForce * -right)
	}
	rigidbody_update(&rb, dt)

	clear(&allCollisions)
	for &mc in StaticColliders {
		collisions := CheckCollisionMeshSphere(mc.mesh, SphereCollider{position, radius})
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
		position += normal * c.distance
	}
	rigidbody_update_position(&rb, &position, dt)
	rigidbody_end_timestep(&rb)
}

player_render :: proc(using player: ^Player, model: ^rl.Model) {
	rot := rotation * la.quaternion_from_euler_angle_y_f32(math.PI)
	ax, an := axis_angle(rot)

	if math.is_nan(ax.x) || math.is_nan(ax.y) || math.is_nan(ax.z) {
		ax = rl.Vector3{0, 0, 0}
	}

	rl.DrawModelEx(model^, position - up * radius, ax, an * math.DEG_PER_RAD, {1, 1, 1}, rl.WHITE)
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
