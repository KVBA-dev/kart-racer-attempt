package main

import "core:math"
import la "core:math/linalg"
import rl "vendor:raylib"

@(require_results)
lerp :: proc {
	lerp_f32,
	lerp_vec3,
}

@(require_results)
lerp_f32 :: proc(a, b, t: f32) -> f32 {
	return a + t * (b - a)
}

@(require_results)
lerp_vec3 :: proc(a, b: [3]f32, t: f32) -> [3]f32 {
	return a + t * (b - a)
}

@(require_results)
get_hl :: proc(time, precision: f32) -> f32 {
	return -time / math.log2(precision)
}

@(require_results)
nondt_lerp :: proc {
	nondt_lerp_vec3,
	nondt_lerp_f32,
}

@(require_results)
nondt_lerp_vec3 :: proc(a, b: [3]f32, dt: f32, hl: f32) -> [3]f32 {
	return lerp(a, b, 1 - math.pow(2, dt / hl))
}

@(require_results)
nondt_lerp_f32 :: proc(a, b: f32, dt: f32, hl: f32) -> f32 {
	return lerp(a, b, 1 - math.pow(2, dt / hl))
}

@(require_results)
axis_angle :: proc(q: rl.Quaternion) -> (axis: rl.Vector3, angle: f32) {
	angle = 2 * math.acos(q.w)
	axis = {q.x, q.y, q.z} / math.sqrt(1 - q.w * q.w)
	return
}

@(require_results)
angle_between_norm :: proc(a, b: rl.Vector3) -> f32 {
	return math.acos(la.dot(a, b))
}
