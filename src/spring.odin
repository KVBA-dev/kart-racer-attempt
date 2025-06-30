package main

import "core:fmt"
import la "core:math/linalg"
import rl "vendor:raylib"

WheelRaycaster :: struct {
	normal:      rl.Vector3,
	relPosition: rl.Vector3,
	length:      f32,
	isGrounded:  bool,
}

update_wheel :: proc(using spring: ^WheelRaycaster, player: ^Player, direction: rl.Vector3) {
	isGrounded = false
	worldpos := player.position + la.quaternion_mul_vector3(player.rotation, relPosition)
	ray := rl.Ray{worldpos, direction}
	hitinfo: rl.RayCollision
	for &m in StaticColliders {
		hitinfo = CheckCollisionMeshRay(m.mesh, ray)
		if !hitinfo.hit || hitinfo.distance > length {
			continue
		}
		normal = hitinfo.normal
		isGrounded = la.dot(player.localUp, normal) > 0.7
	}
}

draw_wheel :: proc(
	wheel: WheelRaycaster,
	position: rl.Vector3,
	rotation: rl.Quaternion,
	up: rl.Vector3,
) {
	start := la.quaternion_mul_vector3(rotation, wheel.relPosition) + position
	end := start - up * wheel.length
	col := wheel.isGrounded ? rl.GREEN : rl.RED
	rl.DrawLine3D(start, end, col)
}
