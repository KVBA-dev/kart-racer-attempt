package main

import rl "vendor:raylib"

WINDOW_WIDTH :: 1024
WINDOW_HEIGHT :: 768

main :: proc() {
    rl.InitWindow(WINDOW_WIDTH, WINDOW_HEIGHT, "kart-racer-attempt")
    defer rl.CloseWindow()

    for !rl.WindowShouldClose() {
        rl.BeginDrawing()
        {
            rl.ClearBackground(rl.WHITE)
			rl.DrawText("Hello, world!", 20, 20, 20, rl.RED)
        }
        rl.EndDrawing()
    }
}
