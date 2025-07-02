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

open_level :: proc(path: string) -> (level: ^Level, ok: bool) {
	path := path
	if !fp.is_abs(path) {
		path, _ = fp.abs(path, context.temp_allocator)
	}

	track_def := track.Track{}
	if !load_cbor(path, &track_def) {
		return nil, false
	}
	defer track.destroy_track(&track_def)

	level = make_level()
	append(&level.materials, rl.LoadMaterialDefault())

	dir := fp.dir(path)
	defer delete(dir)

	for &sm in track_def.staticModels {
		fpath, err := fp.clean(
			fp.join({dir, sm.filepath}, context.temp_allocator),
			context.temp_allocator,
		)
		if err != nil do panic(fmt.tprint("error:", sm.filepath, "doesn't exist"))
		mref := track.try_load_file(fpath).(track.ModelReference)
		defer {
			rl.MemFree(mref.model.meshes)
			delete(mref.meshLayers)
		}

		matloop: for &smmat in sm.materials {
			if smmat.albedo == "" {
				continue
			}
			fpath, err := fp.clean(
				fp.join({dir, smmat.albedo}, context.temp_allocator),
				context.temp_allocator,
			)
			for &tref in level.textures {
				if fpath == tref.path {
					mref.textureIdx[smmat.idx] = &tref
					continue matloop
				}
			}
			tex_ref := track.try_load_file(fpath).(track.TextureReference)
			append(&level.textures, tex_ref)
			mref.textureIdx[smmat.idx] = &level.textures[len(level.textures) - 1]
		}
		for &smm in sm.meshes {
			append(&level.meshes, mref.model.meshes[smm.idx])
			mesh_mat := [2]int{}
			mesh_mat[0] = int(smm.idx)
			mesh_mat[1] = 0
			if mref.textureIdx[smm.idx] != nil {
				// find the material that uses this texture
				found := false
				for &mat, idx in level.materials {
					if mat.maps[rl.MaterialMapIndex.ALBEDO].texture ==
					   mref.textureIdx[smm.idx].texture {
						found = true
						mesh_mat[1] = idx
						break
					}
				}
				if !found {
					mesh_mat[1] = len(level.materials)
					newMat := rl.LoadMaterialDefault()
					newMat.maps[rl.MaterialMapIndex.ALBEDO].texture =
						mref.textureIdx[smm.idx].texture
					append(&level.materials, newMat)
				}
			}
			if smm.layer == .NoCollision {
				append(&level.non_colliding_meshes, mesh_mat)
			} else {
				append(&level.colliding_meshes, mesh_mat)
			}
		}
	}

	/* TODO: minimap handling
	minimapCam.position.xz = track_def.minimap.offset
	minimapCam.target.xz = track_def.minimap.offset
	minimapCam.fovy = track_def.minimap.zoom
	*/

	return level, true
}
