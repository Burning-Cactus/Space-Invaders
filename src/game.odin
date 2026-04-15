package game

import "core:fmt"
import "vendor:raylib"

Vec2 :: [2]i32

shouldGameClose :: proc() -> bool {
	return raylib.WindowShouldClose()
}

width :: 448
height :: 512

Screen :: enum {
	MAIN_MENU,
	GAME,
	RESULTS,
}

screen := Screen.MAIN_MENU

init :: proc() {
	raylib.InitWindow(width, height, "Space Invaders")
	raylib.InitAudioDevice()
	raylib.SetTargetFPS(60)

	initRenderSystem(width, height)
	initAudioSystem()

	startGame()
}

shutdown :: proc() {
	raylib.CloseAudioDevice()
	raylib.CloseWindow()
}

update :: proc() {
	switch screen {
		case .MAIN_MENU: menuLoop()
		case .GAME: gameLoop()
		case .RESULTS:
	}
}

GameState :: struct {
	width, height: i32,
	tempo: u8,
	gameTick: u64,
	paused: bool,
	hordeDirection: i32,
	shouldTurn: bool,
	gameOver: bool,
	lives: i32,

	player: Entity,
	bullets: [dynamic]Entity,
	enemies: [dynamic]Entity,
}
game: GameState

startGame :: proc() {
	game = GameState{
		width = width,
		height = height,
		tempo = 60,
		hordeDirection = 1,
		player = createPlayer({100, height - 32}, {16,16}),
		lives = 3,
	}
	buildEnemyGroup(&(game.enemies))
}

gameLoop :: proc() {
	using game
	for !shouldGameClose() {
		if raylib.IsKeyPressed(.T) {
			paused = !paused
			fmt.printf("Paused! %t\n", paused)
		}

		if paused {
			raylib.BeginDrawing()
			drawScene()
			raylib.DrawText("Paused", 100, 100, 12, raylib.WHITE)
			raylib.EndDrawing()

			continue
		}
		handleInput()

		gameTick += 1

		length := len(enemies)
		if gameTick % u64(tempo) == 0 {
			if shouldTurn {
				for i := 0; i < length; i += 1 {
					enemies[i].position.y += 16
				}
				hordeDirection *= -1
				shouldTurn = false
			} else {
				for i := 0; i < length; i += 1 {
					enemy := enemies[i]
					enemy.position.x += 4 * hordeDirection
					enemies[i] = enemy

					if hordeDirection > 0 {
						if enemy.position.x >= width - 32 do shouldTurn = true
					} else {
						if enemy.position.x <= 32 do shouldTurn = true
					}
				}
			}
			if gameTick % 60 == 0 do enemyShootBullet(enemies[0])
		}

		bulletCount := len(bullets)
		for i := 0; i < bulletCount; i += 1 {
			bullet := bullets[i]
			bullet.position += bullet.velocity
			// Collisions
			checkBulletCollision(&bullet, &enemies)
			if bullet.position.y < -bullet.size.y do bullet.isAlive = false
			bullets[i] = bullet
		}

		// Remove dead entities
		for i := bulletCount - 1; i >= 0; i -= 1 {
			if !bullets[i].isAlive {
				unordered_remove(&bullets, i)
				bulletCount -= 1
			}
		}

		for i := length - 1; i >= 0; i -= 1 {
			if !enemies[i].isAlive {
				unordered_remove(&enemies, i)
				length -= 1
			}
		}
		raylib.BeginDrawing()
		drawScene()
		raylib.EndDrawing()
	}
}

Entity :: struct {
	position, size, velocity: Vec2,
	draw: proc(entity: Entity),
	isAlive: bool,

}

createEntity :: proc(pos, size, velocity: Vec2, drawProc: proc(entity: Entity)) -> Entity {
	return Entity{pos, size, velocity, drawProc, true}
}

createPlayer :: proc(pos, size: Vec2) -> Entity {
	return Entity{pos, size, {0, 0}, drawPlayer, true}
}

enemyShootBullet :: proc(enemy: Entity) {
	bullet := Entity{
		position = enemy.position + {0, 10},
		size = {4, 8},
		velocity = {0, 8},
		draw = drawBullet,
		isAlive = true,
	}
	append(&game.bullets, bullet)
}

handleInput :: proc() {
	using raylib
	using game
	if IsKeyDown(.A) do player.position.x -= 6
	if IsKeyDown(.D) do player.position.x += 6
	if player.position.x < 0 do player.position.x = 0
	if player.position.x + player.size.x > width do player.position.x = width - player.size.x

	if IsKeyPressed(.SPACE) {
		playerShootBullet(player)
	}
}

buildEnemyGroup :: proc(enemies: ^[dynamic]Entity, width: i32 = 11, height: i32 = 5) {
	total := width * height
	for i: i32 = 0; i < total; i += 1 {
		col := i % width
		row := i / width
		x: i32 = col * 32 + 16
		y: i32 = row * 32 + 32
		pos := Vec2{x, y}
		size := Vec2{16, 16}
		append(enemies, Entity{pos, size, {0, 0}, drawEnemy, true})
	}
}

checkBulletCollision :: proc(bullet: ^Entity, enemies: ^[dynamic]Entity) {
	length := len(enemies)
	minX := bullet.position.x
	maxX := minX + bullet.size.x
	minY := bullet.position.y
	maxY := minY + bullet.size.y
	for i := 0; i < length; i += 1 {
		if checkCollision(bullet^, enemies[i]) {
			enemies[i].isAlive = false
			bullet.isAlive = false
			return;
		}
	}

	if checkCollision(bullet^, game.player) {
		game.player.isAlive = false
		game.lives -= 1
		bullet.isAlive = false
	}
}

checkCollision :: proc(a: Entity, b: Entity) -> bool {
	isOverlapping := a.position.x < b.position.x + b.size.x
	isOverlapping &= a.position.x + a.size.x > b.position.x
	isOverlapping &= a.position.y < b.position.y + b.size.y
	isOverlapping &= a.position.y + b.size.y > b.position.y
	return isOverlapping
}


House :: struct {
	pos, size: Vec2,
	pixels: []bool,
}

createHouse :: proc(pos: [2]i32, size: [2]i32) -> House {
	house := House{
		pos = pos,
		size = size,
	}
	return house
}



//
// Rendering code
// Entities
playerSprite: raylib.Texture2D
alienSprite: raylib.Texture2D

// Gui
heartSprite: raylib.Texture2D

backgroundTexture : raylib.Texture2D

initRenderSystem:: proc(width, height: i32) {
	playerSprite = raylib.LoadTexture("assets/Tank.png")
	alienSprite = raylib.LoadTexture("assets/Invader.png")
	heartSprite = raylib.LoadTexture("assets/Heart.png")
	backgroundTexture = makeBackgroundSky(width, height)
}

makeBackgroundSky :: proc(width: i32, height: i32) -> raylib.Texture2D {
	using raylib


	skyline := height / 2
	ground := height - 16

	cellWidth :: 30
	cellHeight :: 30

	background := GenImageColor(width, height, raylib.BLACK)
	for i: i32 = 0; i < width; i += 1 {
		for j: i32 = 0; j < skyline; j += 1 {
			cellX: i32 = i % cellWidth - cellWidth / 2
			cellY: i32 = j % cellHeight - cellHeight / 2
			if abs(cellX) < 2 && abs(cellY) < 2 {
				ImageDrawPixel(&background, i, j, raylib.WHITE)
			}
		}
	}

	buildingColor :: raylib.Color{68,66,88,225}
	buildingBackgroundColor :: raylib.Color{40,38,57,225}

	ImageDrawRectangle(&background, 80, ground - 160, 80, 160, buildingColor)

	ImageDrawRectangle(&background, 0, ground, width, height, raylib.DARKGREEN)
	return LoadTextureFromImage(background)
}

// Draws the scene in raylib. BeginDrawing and EndDrawing must be called outside of this function.
drawScene :: proc() {
	using game
	raylib.ClearBackground(raylib.BLACK)
	drawBackground(width, height)
	player.draw(player)

	bulletCount := len(bullets)
	for i := 0; i < bulletCount; i += 1 {
		bullet := bullets[i]
		bullet.draw(bullet)
	}

	length := len(enemies)
	for i := 0; i < length; i += 1 {
		enemy := enemies[i]
		enemy.draw(enemy)
	}

	drawGui()
}

drawGui :: proc() {
	using game
	for i: i32 = 0; i < lives; i += 1 {
		raylib.DrawTexture(heartSprite, i * 20 + 8, 8, raylib.WHITE)
	}
}

drawPlayer :: proc(player: Entity) {
	raylib.DrawTexture(playerSprite, player.position.x, player.position.y, raylib.WHITE)
}

drawEnemy :: proc(enemy: Entity) {
	raylib.DrawTexture(alienSprite, enemy.position.x, enemy.position.y, raylib.GREEN)
}

drawBullet :: proc(bullet: Entity) {
	raylib.DrawRectangle(bullet.position.x, bullet.position.y, bullet.size.x, bullet.size.y, raylib.WHITE)
}


drawBackground :: proc(width: i32, height: i32) {
	using raylib
	DrawTexture(backgroundTexture, 0, 0, raylib.WHITE)
}

laserSound: raylib.Sound

// Audio code
initAudioSystem :: proc() {
	laserSound = raylib.LoadSound("assets/Laser.wav")
}

menuLoop :: proc() {
	for screen == .MAIN_MENU && !shouldGameClose() {
		using raylib
		BeginDrawing()
		drawBackground(width, height)
		DrawText("SPACE INVADERS", width / 2 - 140, height / 3, 36, raylib.GREEN)
		EndDrawing()

		if IsKeyPressed(.SPACE) {
			screen = .GAME
		}
	}
}
