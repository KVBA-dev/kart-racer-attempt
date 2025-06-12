package main

import "core:time"
import rl "vendor:raylib"

WINDOW_WIDTH :: 1920
WINDOW_HEIGHT :: 1080

track: rl.Model
player_model: rl.Model
skybox_model: rl.Model

normal_preview: rl.Shader
uv_preview: rl.Shader
unlit: rl.Shader
skybox: rl.Shader

main :: proc() {
	rl.InitWindow(WINDOW_WIDTH, WINDOW_HEIGHT, "kart-racer-attempt")
	defer {
		unload_models()
		unload_shaders()
		destroy_input()
		destroy_collision()
		rl.CloseWindow()
	}

	rl.SetWindowState({.FULLSCREEN_MODE})

	cam := rl.Camera3D {
		up         = {0, 1, 0},
		position   = {2, 1, 0},
		target     = {0, 0, 0},
		fovy       = 70,
		projection = .PERSPECTIVE,
	}

	load_models()
	load_shaders()
	init_input()
	init_collision()

	keys := [?]rl.KeyboardKey{.W, .S, .A, .D}
	register_keys(keys[:])

	track.materials[0].shader = unlit
	track.materials[1].shader = uv_preview

	skybox_model.materials[0].shader = skybox

	add_mesh_collider(track.meshes[0], &StaticColliders)
	add_mesh_collider(track.meshes[2], &StaticColliders)

	player := create_player()
	defer free(player)

	player.position = {30, -1, -40}

	rl.DisableCursor()
	defer rl.EnableCursor()

	dt: f32
	//rl.SetTargetFPS(60)

	for !rl.WindowShouldClose() {
		//rl.UpdateCamera(&cam, .FREE)
		camera_follow_player(&cam, player)
		dt = rl.GetFrameTime()
		//dt = 0
		//if rl.IsKeyPressed(.PERIOD) do dt = 0.016667
		update_input()
		player_update(player, dt)
		player_physics_update(player, dt)
		player_orient_towards_up(player, track.meshes[0], dt)
		rl.BeginDrawing()
		{
			rl.ClearBackground(rl.WHITE)
			rl.BeginMode3D(cam)
			{
				rl.DrawModelEx(skybox_model, cam.position, {1, 0, 0}, 90, {-1, -1, -1}, rl.WHITE)
				player_render(player, &player_model)
				rl.DrawModel(track, {0, 0, 0}, 1, rl.WHITE)
				draw_collider(player.collider)
			}
			rl.EndMode3D()
			rl.DrawText("Hello, world!", 20, 20, 20, rl.RED)
			rl.DrawFPS(20, 50)
			rl.DrawText(
				rl.TextFormat("speed: %.4f", player.speedHorizontal),
				20,
				80,
				20,
				rl.DARKPURPLE,
			)
			rl.DrawText(
				rl.TextFormat(
					"pos: [%.3f, %.3f, %.3f]",
					player.position.x,
					player.position.y,
					player.position.z,
				),
				20,
				110,
				20,
				rl.PURPLE,
			)
			rl.DrawText(rl.TextFormat("Grounded: %i", player.isGrounded), 20, 140, 20, rl.ORANGE)
		}
		rl.EndDrawing()
	}
}

load_models :: proc() {
	track = rl.LoadModel("res/models/track1.obj")
	track.materials[0].maps[rl.MaterialMapIndex.ALBEDO].texture = rl.LoadTexture(
		"res/textures/road.png",
	)
	player_model = rl.LoadModel("res/models/vehicle-racer.obj")
	player_model.materials[0].maps[rl.MaterialMapIndex.ALBEDO].texture = rl.LoadTexture(
		"res/textures/colormap.png",
	)
	skybox_model = rl.LoadModelFromMesh(rl.GenMeshSphere(800, 16, 16))
}

load_shaders :: proc() {
	normal_preview = rl.LoadShader(
		"res/shaders/debug-normal-v.glsl",
		"res/shaders/debug-normal-f.glsl",
	)
	uv_preview = rl.LoadShader(nil, "res/shaders/debug-uv-f.glsl")
	unlit = rl.LoadShader(nil, "res/shaders/textured-unlit-f.glsl")
	skybox = rl.LoadShader(nil, "res/shaders/skybox-f.glsl")
}

unload_models :: proc() {
	rl.UnloadTexture(player_model.materials[0].maps[rl.MaterialMapIndex.ALBEDO].texture)
	rl.UnloadTexture(track.materials[0].maps[rl.MaterialMapIndex.ALBEDO].texture)
	rl.UnloadModel(track)
	rl.UnloadModel(player_model)
	rl.UnloadModel(skybox_model)
}

unload_shaders :: proc() {
	rl.UnloadShader(normal_preview)
	rl.UnloadShader(uv_preview)
	rl.UnloadShader(unlit)
	rl.UnloadShader(skybox)
}

camera_follow_player :: proc(cam: ^rl.Camera3D, player: ^Player) {
	cam.target = player.position + player.localUp
	cam.position = player.position + player_forward(player) * -3 + player.localUp * 1
}
