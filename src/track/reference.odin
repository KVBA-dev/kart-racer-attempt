package track

import "core:fmt"
import fp "core:path/filepath"
import st "core:strings"
import rl "vendor:raylib"


FileReference :: union {
	ModelReference,
	TextureReference,
}

ModelReference :: struct {
	model:      rl.Model,
	meshLayers: []StaticLayer,
	path_obj:   string,
	textureIdx: []^TextureReference,
}

TextureReference :: struct {
	texture: rl.Texture,
	path:    string,
}

modelReferences := make([dynamic]ModelReference)
textureReferences := make([dynamic]TextureReference)

get_textures :: proc() -> (tex: TextureReference, ok: bool) {
	for ref in textureReferences {
		return ref, true
	}
	return {}, false
}

get_models :: proc() -> (mod: ^ModelReference, ok: bool) {
	for &ref in modelReferences {
		return &ref, true
	}
	return {}, false
}

try_load_file :: proc(path: string) -> FileReference {
	ref: FileReference = nil
	allocator := context.temp_allocator
	switch fp.ext(path) {
	case ".obj":
		mref := ModelReference {
			model    = rl.LoadModel(st.clone_to_cstring(path, allocator)),
			path_obj = path,
		}
		mref.meshLayers = make([]StaticLayer, mref.model.meshCount)
		// unload default materials, coz we use our materials anyway
		for matIdx in 0 ..< mref.model.materialCount {
			rl.MemFree(mref.model.materials[matIdx].maps)
		}
		rl.MemFree(mref.model.materials)
		mref.textureIdx = make([]^TextureReference, mref.model.meshCount)
		for &mti in mref.textureIdx {
			mti = nil
		}
		ref = mref
	case ".png", ".jpg":
		for t in textureReferences {
			if t.path == path {
				return nil
			}
		}
		tref := TextureReference {
			texture = rl.LoadTexture(st.clone_to_cstring(path, allocator)),
			path    = path,
		}
		ref = tref
	}
	return ref
}

delete_model_reference :: proc(idx: int) {
	r := modelReferences[idx]
	unordered_remove(&modelReferences, idx)
	rl.MemFree(r.model.meshMaterial)
	free(r.model.materials)
	for i in 0 ..< r.model.meshCount {
		rl.UnloadMesh(r.model.meshes[i])
	}
	rl.MemFree(r.model.meshes)
	rl.MemFree(r.model.bones)
	rl.MemFree(r.model.bindPose)
	delete(r.meshLayers)
	delete(r.textureIdx)
}

delete_texture_reference :: proc(idx: int) {
	last_idx := len(textureReferences) - 1
	for &model in modelReferences {
		for &tex in model.textureIdx {
			if tex == &textureReferences[idx] {
				tex = nil
			} else if tex == &textureReferences[last_idx] {
				tex = &textureReferences[idx]
			}
		}
	}
	rl.UnloadTexture(textureReferences[idx].texture)
	unordered_remove(&textureReferences, idx)
}

clear_references :: proc() {
	for ref, ri in modelReferences {
		delete_model_reference(ri)
	}
	for ref, ri in textureReferences {
		rl.UnloadTexture(ref.texture)
	}
	clear(&modelReferences)
	clear(&textureReferences)
}

delete_references :: proc() {
	clear_references()
	delete(modelReferences)
	delete(textureReferences)
}
