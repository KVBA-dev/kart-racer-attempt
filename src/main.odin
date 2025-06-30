package main
import it "base:intrinsics"
import "core:fmt"
import la "core:math/linalg"
import "core:mem"
import "core:sync"
import th "core:thread"
import "core:time"
import "track"
import rl "vendor:raylib"

WINDOW_WIDTH :: 1920
WINDOW_HEIGHT :: 1080

PHYSICS_DT :: .001
PHYSICS_NS :: time.Millisecond

player_model: rl.Model
skybox_model: rl.Model

normal_preview: rl.Shader
uv_preview: rl.Shader
unlit: rl.Shader
skybox: rl.Shader

physics_lock := sync.Mutex{}
running := true
physicsTime: f64

NUM_PLAYERS :: 1
players: [NUM_PLAYERS]Player

physics_thread :: proc() {
	duration: time.Duration
	previous := time.now()
	for running {
		duration := time.since(previous)
		if time.duration_milliseconds(duration) < PHYSICS_DT do continue
		previous = time.time_add(previous, PHYSICS_NS)
		if sync.mutex_guard(&physics_lock) {
			start := time.now()
			for &player in players {
				player_update(&player, PHYSICS_DT)
				player_physics_update(&player, PHYSICS_DT)
			}
			physicsTime = time.duration_microseconds(time.since(start))
		}
	}
}

main :: proc() {
	rl.InitWindow(WINDOW_WIDTH, WINDOW_HEIGHT, "kart-racer-attempt")
	defer {
		unload_shaders()
		unload_models()
		destroy_input()
		destroy_collision()
		rl.CloseWindow()
	}

	rl.SetWindowState({.FULLSCREEN_MODE, .MSAA_4X_HINT})
	hl = get_hl(3, 0.01)

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

	register_keys([]rl.KeyboardKey{.W, .S, .A, .D})

	skybox_model.materials[0].shader = skybox

	player := create_player()
	player.position = {30, -1, -40}
	players[0] = player
	//playersRenderBuffer[0] = player

	rl.DisableCursor()
	defer rl.EnableCursor()

	colliding_meshes := make([dynamic]TrackMesh)
	defer delete(colliding_meshes)

	no_collision_meshes := make([dynamic]TrackMesh)
	defer delete(no_collision_meshes)

	if !open_level(
		"level1.klv",
		&colliding_meshes,
		&no_collision_meshes,
		&track.textureReferences,
	) {
		fmt.println("couldn't open level")
		return
	}

	for &m in colliding_meshes {
		add_mesh_collider(m.mesh, &StaticColliders)
	}

	dt: f32
	rayDistance: f32
	rayHit: bool
	currplayer: ^Player

	physicsThread := th.create_and_start(physics_thread)
	//rl.SetTargetFPS(60)

	for !rl.WindowShouldClose() {
		dt = rl.GetFrameTime()
		update_input()
		if sync.mutex_guard(&physics_lock) {
			currplayer = &players[0]
			currplayer.axisH = (Input.keys[.D].held ? 1 : 0) - (Input.keys[.A].held ? 1 : 0)
			currplayer.axisV = (Input.keys[.W].held ? 1 : 0) - (Input.keys[.S].held ? 1 : 0)
			player_orient_towards_up(currplayer, StaticColliders[0].mesh, dt)
			camera_follow_player(&cam, currplayer, dt)
		}
		rl.BeginDrawing()
		{
			rl.ClearBackground(rl.WHITE)
			rl.BeginMode3D(cam)
			{
				rl.DrawModelEx(skybox_model, cam.position, {1, 0, 0}, 90, {-1, -1, -1}, rl.WHITE)
				if sync.mutex_guard(&physics_lock) {
					for &player in players {
						player_render(&player, &player_model)
					}
				}
				for m in colliding_meshes {
					rl.DrawMesh(m.mesh, m.material, rl.Matrix(1))
				}
				for m in no_collision_meshes {
					rl.DrawMesh(m.mesh, m.material, rl.Matrix(1))
				}
				//draw_collider(StaticColliders[0])
			}
			rl.EndMode3D()
			rl.DrawRectangle(0, 0, 400, 180, rl.ColorAlpha(rl.BLACK, .5))
			rl.DrawText("Hello, world!", 20, 20, 20, rl.RED)
			rl.DrawText(
				rl.TextFormat("Physics time: %.3f us", physicsTime),
				20,
				80,
				20,
				rl.SKYBLUE,
			)
			rl.DrawFPS(20, 50)
		}
		rl.EndDrawing()
	}
	it.atomic_store(&running, false)
	th.join(physicsThread)
}

load_models :: proc() {
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
	targetPos := cam.target - player.forw * 3
	cam.position = lerp(cam.position, targetPos, 15 * dt)
}
