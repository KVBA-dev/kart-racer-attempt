package main

import rl "vendor:raylib"

Input := _Input{}

_Input :: struct {
	keys: map[rl.KeyboardKey]KeyState,
}

init_input :: proc() {
	Input.keys = make(map[rl.KeyboardKey]KeyState)
}

destroy_input :: proc() {
	delete(Input.keys)
}

update_input :: proc() {
	for k, &v in Input.keys {
		v.held = rl.IsKeyDown(k)
		v.pressed = rl.IsKeyPressed(k)
		v.released = rl.IsKeyReleased(k)
	}
}

register_key :: proc(key: rl.KeyboardKey) {
	Input.keys[key] = KeyState{}
}

register_keys :: proc(keys: []rl.KeyboardKey) {
	for k in keys {
		Input.keys[k] = KeyState{}
	}
}

KeyState :: struct {
	pressed, held, released: bool,
}
