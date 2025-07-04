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

when !ODIN_DEBUG {
	PHYSICS_DT :: .001
	PHYSICS_NS :: 1 * time.Millisecond
} else {
	PHYSICS_DT :: .005
	PHYSICS_NS :: 5 * time.Millisecond
}

player_model: rl.Model
skybox_model: rl.Model

normal_preview: rl.Shader
uv_preview: rl.Shader
unlit: rl.Shader
skybox: rl.Shader

physics_lock := sync.Mutex{}
running := true
physicsTime: f64

NUM_PLAYERS :: 12
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
			for &player, idx in players {
				player_update(&player, PHYSICS_DT, idx)
				player_physics_update(&player, PHYSICS_DT, idx)
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

	//playersRenderBuffer[0] = player

	rl.DisableCursor()
	defer rl.EnableCursor()

	level, ok := open_level("level1.klv")
	if !ok {
		fmt.println("couldn't open level")
		return
	}
	defer delete_level(level)

	for &m in level.colliding_meshes {
		add_mesh_collider(level.meshes[m[0]], &StaticColliders)
	}

	for i in 0 ..< NUM_PLAYERS {
		players[i] = create_player()
	}

	start_forw := la.quaternion_mul_vector3(
		level.finish_line.transform.rotation,
		rl.Vector3{0, 0, 1},
	)
	start_right := la.quaternion_mul_vector3(
		level.finish_line.transform.rotation,
		rl.Vector3{1, 0, 0},
	)
	startPos: for z in 0 ..< 3 {
		for x in 0 ..< 4 {
			p_idx := z * 4 + x
			if p_idx >= NUM_PLAYERS do break startPos
			if players[p_idx] == {} {
				continue
			}
			players[p_idx].position = level.finish_line.transform.translation
			players[p_idx].position -= start_forw * f32(z + 1) * level.finish_line.spreadZ
			players[p_idx].position += start_right * (f32(x) - 1.5) * level.finish_line.spreadX
			players[p_idx].startPos.translation = players[p_idx].position
			players[p_idx].rotation = level.finish_line.transform.rotation
			players[p_idx].startPos.rotation = players[p_idx].rotation
		}
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
			if rl.IsKeyPressed(.R) {
				for &p in players {
					p.position = p.startPos.translation
					p.rotation = p.startPos.rotation
					p.rb.linVel = {}
					p.rb.linAccel = {}
				}
			}

			for &bot in players[1:] {
				bot.axisV = 1
			}
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
				for m in level.colliding_meshes {
					rl.DrawMesh(level.meshes[m[0]], level.materials[m[1]], rl.Matrix(1))
				}
				for m in level.non_colliding_meshes {
					rl.DrawMesh(level.meshes[m[0]], level.materials[m[1]], rl.Matrix(1))
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
	th.destroy(physicsThread)
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
