package main

import "core:fmt"
import "core:math"
import la "core:math/linalg"
import rl "vendor:raylib"

hl := get_hl(.5, .01)

Player :: struct {
	collider:        SphereCollider,
	rotation:        rl.Quaternion,
	position:        rl.Vector3,
	localUp:         rl.Vector3,
	orientationUp:   rl.Vector3,
	speedHorizontal: f32,
	speedVertical:   f32,
	isGrounded:      bool,
}

create_player :: proc() -> ^Player {
	p := new(Player)
	p.collider = SphereCollider {
		radius = .5,
	}
	p.rotation = la.QUATERNIONF32_IDENTITY
	p.localUp = {0, 1, 0}
	return p
}

player_update :: proc(using player: ^Player, dt: f32) {
	axisH: f32 = (Input.keys[.D].held ? 1 : 0) - (Input.keys[.A].held ? 1 : 0)
	axisV: f32 = (Input.keys[.W].held ? 1 : 0) - (Input.keys[.S].held ? 1 : 0)

	forw := player_forward(player)

	direction := math.sign(la.vector_dot(forw, forw * speedHorizontal))
	if math.is_nan(direction) do direction = 0
	maxspeedHorizontal: f32 = 30
	if (direction * axisV == 1) {
		maxspeedHorizontal = direction > 0 ? 30 : -10
	}

	// forward/backward
	if isGrounded {
		speedHorizontal += axisV * lerp(50 * dt, 0, (speedHorizontal / maxspeedHorizontal))
		if axisV == 0 do speedHorizontal *= .998
	}
	position += (speedHorizontal * forw + speedVertical * localUp) * dt
	collider.center = position

	// turning
	rotation =
		la.quaternion_from_euler_angles_f32(
			0,
			speedHorizontal * -axisH * 2 * dt * math.RAD_PER_DEG,
			0,
			.XYZ,
		) *
		rotation

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

	angle := la.angle_between(localUp, orientationUp)
	axis := la.cross(orientationUp, player_up(player))
	rotation = la.quaternion_angle_axis_f32(-angle * dt, axis) * rotation
}

// TODO: interact with other objects
player_physics_update :: proc(using player: ^Player, dt: f32) {
	speedVertical -= 10 * dt

	isGrounded = false
	for &mc in StaticColliders {
		collisions := CheckCollisionMeshSphere(mc.mesh, collider)
		for c in collisions {
			penetration := c.direction * c.distance
			position -= penetration / 2

			dot := la.dot(localUp, -c.direction)

			if dot > .7 {
				isGrounded = true
				speedVertical = max(0, speedVertical)
			} else if dot < .3 {
				speedHorizontal -=
					speedHorizontal *
					la.dot(c.direction, player_forward(player) * math.sign(speedHorizontal))
			}
		}
	}
}

player_render :: proc(using player: ^Player, model: ^rl.Model) {
	rot := rotation * la.quaternion_from_euler_angle_y_f32(math.PI)
	an, ax := la.angle_axis_from_quaternion_f32(rot)

	if math.is_nan(ax.x) || math.is_nan(ax.y) || math.is_nan(ax.z) {
		ax = rl.Vector3{0, 0, 0}
	}

	// rotation glitch fix
	if abs(rot.y) < .5 && rot.w < 0 {
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
