package main
import "core:fmt"
import la "core:math/linalg"
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
	hl = get_hl(0.5, 0.01)

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

	append(&trackMeshes, track.meshes[0])

	skybox_model.materials[0].shader = skybox

	add_mesh_collider(track.meshes[0], &StaticColliders)
	add_mesh_collider(track.meshes[2], &StaticColliders)

	player := create_player()
	defer free(player)

	player.position = {30, 10, -40}

	rl.DisableCursor()
	defer rl.EnableCursor()

	dt: f32
	//rl.SetTargetFPS(60)

	for !rl.WindowShouldClose() {
		//rl.UpdateCamera(&cam, .FREE)
		dt = rl.GetFrameTime()
		//dt = 0
		//if rl.IsKeyPressed(.PERIOD) do dt = 0.016667
		update_input()
		player_update(player, dt)
		fmt.println("pre orient:", player.rotation)
		player_orient_towards_up(player, track.meshes[0], dt)
		fmt.println("post orient:", player.rotation)
		player_physics_update(player, dt)

		camera_follow_player(&cam, player, dt)
		if rl.IsKeyPressed(.ONE) {
			player.rotation = quaternion128(1)
			player.position = {30, -1, -40}
			player.rb.linVel = {0, 0, 0}
		}
		rl.BeginDrawing()
		{
			rayDistance: f32
			rayHit: bool
			rl.ClearBackground(rl.WHITE)
			rl.BeginMode3D(cam)
			{
				rl.DrawModelEx(skybox_model, cam.position, {1, 0, 0}, 90, {-1, -1, -1}, rl.WHITE)
				player_render(player, &player_model)
				rl.DrawModel(track, {0, 0, 0}, 1, rl.WHITE)
				draw_collider(player.collider)
				for w in player.wheels {
					draw_wheel(w, player.position, player.rotation, player.orientationUp)
				}
				ray := rl.Ray {
					position  = player.position,
					direction = -player_up(player),
				}
				hitInfo := rl.GetRayCollisionMesh(ray, track.meshes[0], rl.Matrix(1))
				rayHit = hitInfo.hit
				rayDistance = hitInfo.distance
				if rayHit {
					rl.DrawLine3D(
						player.position,
						player.position + rayDistance * ray.direction,
						rl.RED,
					)
					rl.DrawCircle3D(
						player.position + rayDistance * ray.direction,
						.1,
						{1, 0, 0},
						90,
						rl.RED,
					)
				}
			}
			rl.EndMode3D()
			rl.DrawRectangle(0, 0, 500, 400, rl.ColorAlpha(rl.BLACK, .5))
			rl.DrawText("Hello, world!", 20, 20, 20, rl.RED)
			rl.DrawFPS(20, 50)
			rl.DrawText(
				rl.TextFormat("speed: %.4f", la.length(player.rb.linVel)),
				20,
				80,
				20,
				rl.SKYBLUE,
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
			rl.DrawText(
				rl.TextFormat(
					"Velocity: [%.3f %.3f %.3f]",
					player.rb.linVel.x,
					player.rb.linVel.y,
					player.rb.linVel.z,
				),
				20,
				170,
				20,
				rl.ORANGE,
			)
			rl.DrawText(
				rl.TextFormat(
					"Rotation: [%.3f, %.3f, %.3f, %.3f]",
					player.rotation.x,
					player.rotation.y,
					player.rotation.z,
					player.rotation.w,
				),
				20,
				200,
				20,
				rl.LIGHTGRAY,
			)
			forw := player_forward(player)
			rl.DrawText(
				rl.TextFormat("Forward: [%.3f %.3f %.3f]", forw.x, forw.y, forw.z),
				20,
				230,
				20,
				rl.LIGHTGRAY,
			)
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

camera_follow_player :: proc(cam: ^rl.Camera3D, player: ^Player, dt: f32) {
	cam.target = player.position + player.localUp
	targetPos := cam.target - player_forward(player) * 3
	cam.position = nondt_lerp(targetPos, cam.position, dt, hl)
}
