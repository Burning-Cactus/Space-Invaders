package main

import "base:runtime"
import "core:c"
import "core:mem"
import game ".."

web_context: runtime.Context

@export
main_start :: proc "c" () {
	context = runtime.default_context()

	context.allocator = emscripten_allocator()
	runtime.init_global_temporary_allocator(1*mem.Megabyte)

	web_context = context

	game.init()
}

@export
main_update :: proc "c" () -> bool {
	context = web_context
	game.update()
	return true
}

@export
main_end :: proc "c" () {
	context = web_context
	game.shutdown()
}

@export
web_window_size_changed :: proc "c" (w: c.int, h: c.int) {
	context = web_context
	//game.parent_window_size_changed(int(w), int(h))
}
