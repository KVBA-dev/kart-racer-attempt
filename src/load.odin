package main

import "core:fmt"
import fp "core:path/filepath"
import st "core:strings"
import "track"
import rl "vendor:raylib"

TrackMesh :: struct {
	mesh:     rl.Mesh,
	material: rl.Material,
}

open_level :: proc(
	path: string,
	collidingMeshes: ^[dynamic]TrackMesh,
	noCollisionMeshes: ^[dynamic]TrackMesh,
	textures: ^[dynamic]track.TextureReference,
) -> bool {
	path := path
	if !fp.is_abs(path) {
		path, _ = fp.abs(path, context.temp_allocator)
	}

	track_def := track.Track{}
	if !load_cbor(path, &track_def) {
		return false
	}
	defer track.destroy_track(&track_def)

	dir := fp.dir(path)
	defer delete(dir)

	clear(collidingMeshes)
	clear(noCollisionMeshes)
	clear(textures)

	for &sm in track_def.staticModels {
		fpath, err := fp.clean(
			fp.join({dir, sm.filepath}, context.temp_allocator),
			context.temp_allocator,
		)
		if err != nil do panic(fmt.tprint("error:", sm.filepath, "doesn't exist"))
		ref := track.try_load_file(fpath)

		mref := ref.(track.ModelReference)

		matloop: for &smmat in sm.materials {
			if smmat.albedo == "" {
				continue
			}
			fpath, err := fp.clean(
				fp.join({dir, smmat.albedo}, context.temp_allocator),
				context.temp_allocator,
			)
			for &tref in textures {
				if fpath == tref.path {
					mref.textureIdx[smmat.idx] = &tref
					continue matloop
				}
			}
			tex_ref := track.try_load_file(fpath).(track.TextureReference)
			append(textures, tex_ref)
			mref.textureIdx[smmat.idx] = &textures[len(textures) - 1]
		}
		for &smm in sm.meshes {
			track_mesh := TrackMesh{}
			track_mesh.mesh = mref.model.meshes[smm.idx]
			if mref.textureIdx[smm.idx] != nil {
				track_mesh.material = rl.LoadMaterialDefault()
				track_mesh.material.maps[rl.MaterialMapIndex.ALBEDO].texture =
					mref.textureIdx[smm.idx].texture
			}
			if smm.layer == .NoCollision {
				append(noCollisionMeshes, track_mesh)
			} else {
				append(collidingMeshes, track_mesh)
			}
		}
	}

	/* TODO: minimap handling
	minimapCam.position.xz = track_def.minimap.offset
	minimapCam.target.xz = track_def.minimap.offset
	minimapCam.fovy = track_def.minimap.zoom
	*/

	return true
}
