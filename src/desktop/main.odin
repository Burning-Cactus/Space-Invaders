package main

import "core:fmt"
import "core:time"
import rl "vendor:raylib"

import game ".."

width :: 512
height :: 448


main :: proc() {
	game.init()
	for !rl.WindowShouldClose() {
		game.update()
	}
	game.shutdown()
}


