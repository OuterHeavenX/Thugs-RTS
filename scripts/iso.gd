class_name Iso
extends RefCounted

## Isometric 2:1 projection helpers. TILE_W=64, TILE_H=32.

const TILE_W := 64.0
const TILE_H := 32.0


static func tile_to_screen(t: Vector2) -> Vector2:
	return Vector2((t.x - t.y) * TILE_W * 0.5, (t.x + t.y) * TILE_H * 0.5)


static func screen_to_tile(p: Vector2) -> Vector2:
	# Exact inverse of tile_to_screen.
	return Vector2(p.x / TILE_W + p.y / TILE_H, p.y / TILE_H - p.x / TILE_W)


static func tile_center_i(t: Vector2i) -> Vector2:
	return tile_to_screen(Vector2(t))
