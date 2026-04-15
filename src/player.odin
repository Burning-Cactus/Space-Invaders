package game

import rl "vendor:raylib"

Player :: struct {

}

playerShootBullet :: proc(player: Entity) {
	bullet := Entity{
		position = player.position + {0, -10},
		size = {4, 8},
		velocity = {0, -8},
		draw = drawBullet,
		isAlive = true,
	}
	append(&game.bullets, bullet)
	rl.PlaySound(laserSound)
}


