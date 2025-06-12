package main

import "core:math"

lerp :: proc {
	lerp_f32,
	lerp_vec3,
}

lerp_f32 :: proc(a, b, t: f32) -> f32 {
	return a + t * (b - a)
}

lerp_vec3 :: proc(a, b: [3]f32, t: f32) -> [3]f32 {
	return a + t * (b - a)
}

get_hl :: proc(time, precision: f32) -> f32 {
	return -time / math.log2(precision)
}

nondt_lerp :: proc {
	nondt_lerp_vec3,
	nondt_lerp_f32,
}

nondt_lerp_vec3 :: proc(a, b: [3]f32, dt: f32, hl: f32) -> [3]f32 {
	return lerp(a, b, 1 - math.pow(2, dt / hl))
}

nondt_lerp_f32 :: proc(a, b: f32, dt: f32, hl: f32) -> f32 {
	return lerp(a, b, 1 - math.pow(2, dt / hl))
}
