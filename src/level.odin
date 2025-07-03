package main

import "track"
import rl "vendor:raylib"

Level :: struct {
	meshes:               [dynamic]rl.Mesh,
	materials:            [dynamic]rl.Material,
	textures:             [dynamic]track.TextureReference,
	colliding_meshes:     [dynamic][2]int,
	non_colliding_meshes: [dynamic][2]int,
	finish_line:          track.FinishLine,
}

make_level :: proc() -> ^Level {
	level := new(Level)
	level.meshes = make([dynamic]rl.Mesh)
	level.materials = make([dynamic]rl.Material)
	level.textures = make([dynamic]track.TextureReference)
	level.colliding_meshes = make([dynamic][2]int)
	level.non_colliding_meshes = make([dynamic][2]int)

	return level
}

delete_level :: proc(level: ^Level) {
	for &mesh in level.meshes {
		rl.UnloadMesh(mesh)
	}
	for &mat in level.materials {
		rl.UnloadMaterial(mat)
	}
	for &tex in level.textures {
		rl.UnloadTexture(tex.texture)
	}
	delete(level.meshes)
	delete(level.materials)
	delete(level.textures)
	delete(level.colliding_meshes)
	delete(level.non_colliding_meshes)
	free(level)
}
