package game

import "core:fmt"
import rl "vendor:raylib"

Vec2 :: [2]i32

shouldGameClose :: proc() -> bool {
	return rl.WindowShouldClose()
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
	rl.InitWindow(width, height, "Space Invaders")
	rl.InitAudioDevice()
	rl.SetTargetFPS(60)

	initRenderSystem(width, height)
	initAudioSystem()

	startGame()
}

shutdown :: proc() {
	rl.CloseAudioDevice()
	rl.CloseWindow()
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
	for !shouldGameClose() {
		if rl.IsKeyPressed(.T) {
			game.paused = !game.paused
			fmt.printf("Paused! %t\n", game.paused)
		}

		if game.paused {
			rl.BeginDrawing()
			drawScene()
			rl.DrawText("Paused", 100, 100, 12, rl.WHITE)
			rl.EndDrawing()

			continue
		}
		handleInput()

		game.gameTick += 1

		length := len(game.enemies)
		if game.gameTick % u64(game.tempo) == 0 {
			if game.shouldTurn {
				for i := 0; i < length; i += 1 {
					game.enemies[i].position.y += 16
				}
				game.hordeDirection *= -1
				game.shouldTurn = false
			} else {
				for i := 0; i < length; i += 1 {
					enemy := game.enemies[i]
					enemy.position.x += 4 * game.hordeDirection
					game.enemies[i] = enemy

					if game.hordeDirection > 0 {
						if enemy.position.x >= width - 32 do game.shouldTurn = true
					} else {
						if enemy.position.x <= 32 do game.shouldTurn = true
					}
				}
			}
			if game.gameTick % 60 == 0 do enemyShootBullet(game.enemies[0])
		}

		bulletCount := len(game.bullets)
		for i := 0; i < bulletCount; i += 1 {
			bullet := game.bullets[i]
			bullet.position += bullet.velocity
			// Collisions
			checkBulletCollision(&bullet, &(game.enemies))
			if bullet.position.y < -bullet.size.y do bullet.isAlive = false
			game.bullets[i] = bullet
		}

		// Remove dead entities
		for i := bulletCount - 1; i >= 0; i -= 1 {
			if !game.bullets[i].isAlive {
				unordered_remove(&(game.bullets), i)
				bulletCount -= 1
			}
		}

		for i := length - 1; i >= 0; i -= 1 {
			if !game.enemies[i].isAlive {
				unordered_remove(&(game.enemies), i)
				length -= 1
			}
		}
		rl.BeginDrawing()
		drawScene()
		rl.EndDrawing()
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
	player := game.player
	if rl.IsKeyDown(.A) do player.position.x -= 6
	if rl.IsKeyDown(.D) do player.position.x += 6
	if player.position.x < 0 do player.position.x = 0
	if player.position.x + player.size.x > width do player.position.x = width - player.size.x
	
	if rl.IsKeyPressed(.SPACE) {
		playerShootBullet(player)
	}
	game.player = player
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
playerSprite: rl.Texture2D
alienSprite: rl.Texture2D

// Gui
heartSprite: rl.Texture2D

backgroundTexture : rl.Texture2D

initRenderSystem:: proc(width, height: i32) {
	playerSprite = rl.LoadTexture("assets/Tank.png")
	alienSprite = rl.LoadTexture("assets/Invader.png")
	heartSprite = rl.LoadTexture("assets/Heart.png")
	backgroundTexture = makeBackgroundSky(width, height)
}

makeBackgroundSky :: proc(width: i32, height: i32) -> rl.Texture2D {

	skyline := height / 2
	ground := height - 16

	cellWidth :: 30
	cellHeight :: 30

	background := rl.GenImageColor(width, height, rl.BLACK)
	for i: i32 = 0; i < width; i += 1 {
		for j: i32 = 0; j < skyline; j += 1 {
			cellX: i32 = i % cellWidth - cellWidth / 2
			cellY: i32 = j % cellHeight - cellHeight / 2
			if abs(cellX) < 2 && abs(cellY) < 2 {
				rl.ImageDrawPixel(&background, i, j, rl.WHITE)
			}
		}
	}

	buildingColor :: rl.Color{68,66,88,225}
	buildingBackgroundColor :: rl.Color{40,38,57,225}

	rl.ImageDrawRectangle(&background, 80, ground - 160, 80, 160, buildingColor)
	rl.ImageDrawRectangle(&background, 0, ground, width, height, rl.DARKGREEN)
	return rl.LoadTextureFromImage(background)
}

// Draws the scene in raylib. BeginDrawing and EndDrawing must be called outside of this function.
drawScene :: proc() {
	player := game.player
	rl.ClearBackground(rl.BLACK)
	drawBackground(width, height)
	player.draw(player)

	bulletCount := len(game.bullets)
	for i := 0; i < bulletCount; i += 1 {
		bullet := game.bullets[i]
		bullet.draw(bullet)
	}

	length := len(game.enemies)
	for i := 0; i < length; i += 1 {
		enemy := game.enemies[i]
		enemy.draw(enemy)
	}

	drawGui()
}

drawGui :: proc() {
	for i: i32 = 0; i < game.lives; i += 1 {
		rl.DrawTexture(heartSprite, i * 20 + 8, 8, rl.WHITE)
	}
}

drawPlayer :: proc(player: Entity) {
	rl.DrawTexture(playerSprite, player.position.x, player.position.y, rl.WHITE)
}

drawEnemy :: proc(enemy: Entity) {
	rl.DrawTexture(alienSprite, enemy.position.x, enemy.position.y, rl.GREEN)
}

drawBullet :: proc(bullet: Entity) {
	rl.DrawRectangle(bullet.position.x, bullet.position.y, bullet.size.x, bullet.size.y, rl.WHITE)
}


drawBackground :: proc(width: i32, height: i32) {
	rl.DrawTexture(backgroundTexture, 0, 0, rl.WHITE)
}

laserSound: rl.Sound

// Audio code
initAudioSystem :: proc() {
	laserSound = rl.LoadSound("assets/Laser.wav")
}

menuLoop :: proc() {
	for screen == .MAIN_MENU && !shouldGameClose() {
		rl.BeginDrawing()
		drawBackground(width, height)
		rl.DrawText("SPACE INVADERS", width / 2 - 140, height / 3, 36, rl.GREEN)
		rl.EndDrawing()

		if rl.IsKeyPressed(.SPACE) {
			screen = .GAME
		}
	}
}
