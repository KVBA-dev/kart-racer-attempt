package track

import "core:encoding/cbor"
import "core:fmt"
import os "core:os/os2"
import fp "core:path/filepath"
import rl "vendor:raylib"

StaticLayer :: enum u8 {
	NoCollision = 0,
	Road,
	Ground,
	Ice,
	Water,
	Decor,
}

get_layer_name :: proc(l: StaticLayer) -> string {
	switch l {
	case .NoCollision:
		return "No Collision"
	case .Road:
		return "Road"
	case .Ground:
		return "Ground"
	case .Ice:
		return "Ice"
	case .Water:
		return "Water"
	case .Decor:
		return "Decor"
	case:
		return ""
	}
}

Track :: struct {
	staticModels: []StaticModel,
	minimap:      MinimapSettings,
}

StaticModel :: struct {
	meshes:    []StaticMesh,
	materials: []StaticMaterial,
	filepath:  string,
}

StaticMesh :: struct {
	idx:   i32,
	layer: StaticLayer,
}

StaticMaterial :: struct {
	albedo: string,
	idx:    i32,
}

MinimapSettings :: struct {
	offset: rl.Vector2,
	zoom:   f32,
}

destroy_track :: proc(t: ^Track) {
	for &sm in t.staticModels {
		delete(sm.meshes)
		delete(sm.materials)
	}
	delete(t.staticModels)
}
