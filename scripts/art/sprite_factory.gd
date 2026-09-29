class_name SpriteFactory
extends RefCounted

## Procedural unit and resource-node sprites (ImageTexture, faction-tinted).
## Generated at runtime so nothing depends on the import pipeline.

static var _cache := {}


static func unit_texture(kind: String, faction: String) -> ImageTexture:
	var key := "unit_%s_%s" % [kind, faction]
	if _cache.has(key):
		return _cache[key]
	var img := Image.create(40, 56, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var col: Color = FactionData.color_of(faction)
	var dark: Color = FactionData.FACTIONS[faction]["dark"]
	var light: Color = FactionData.FACTIONS[faction]["light"]
	var skin := Color(0.92, 0.76, 0.60)
	_ellipse(img, 20, 50, 14, 5, Color(0, 0, 0, 0.30))
	_rect(img, 14, 40, 5, 10, dark) # legs
	_rect(img, 21, 40, 5, 10, dark)
	var body := col if kind == "soldier" else light
	_rect(img, 11, 22, 18, 19, body) # torso
	_rect(img, 11, 22, 18, 4, dark) # shoulder shade
	_rect(img, 7, 24, 4, 12, dark) # arms
	_rect(img, 29, 24, 4, 12, dark)
	_circle(img, 20, 15, 8, skin) # head
	if kind == "worker":
		_rect(img, 11, 6, 18, 5, Color(0.95, 0.80, 0.20)) # hard hat
		_rect(img, 9, 10, 22, 3, Color(0.95, 0.80, 0.20))
	else:
		_rect(img, 11, 6, 18, 6, dark) # helmet
		_rect(img, 30, 26, 9, 3, Color(0.12, 0.12, 0.14)) # rifle hint
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex


static func node_texture(kind: String) -> ImageTexture:
	var key := "node_%s" % kind
	if _cache.has(key):
		return _cache[key]
	var img := Image.create(44, 44, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	_ellipse(img, 22, 38, 15, 5, Color(0, 0, 0, 0.30))
	if kind == "supply":
		_rect(img, 10, 14, 24, 22, Color(0.72, 0.53, 0.30)) # crate
		_rect(img, 10, 14, 24, 4, Color(0.55, 0.38, 0.20))
		_rect(img, 10, 32, 24, 4, Color(0.55, 0.38, 0.20))
		_rect(img, 19, 18, 6, 14, Color(0.95, 0.78, 0.25)) # amber stripe
		_rect(img, 14, 22, 16, 6, Color(0.95, 0.78, 0.25))
	else:
		_diamond(img, 22, 24, 14, Color(0.25, 0.75, 0.35)) # cash gem
		_diamond(img, 22, 24, 8, Color(0.55, 0.95, 0.60))
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex


static func _rect(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	for py in range(y, y + h):
		for px in range(x, x + w):
			if px >= 0 and py >= 0 and px < img.get_width() and py < img.get_height():
				img.set_pixel(px, py, c)


static func _circle(img: Image, cx: int, cy: int, r: int, c: Color) -> void:
	_ellipse(img, cx, cy, r, r, c)


static func _ellipse(img: Image, cx: int, cy: int, rx: int, ry: int, c: Color) -> void:
	for py in range(cy - ry, cy + ry + 1):
		for px in range(cx - rx, cx + rx + 1):
			var dx := float(px - cx) / float(maxi(1, rx))
			var dy := float(py - cy) / float(maxi(1, ry))
			if dx * dx + dy * dy <= 1.0:
				if px >= 0 and py >= 0 and px < img.get_width() and py < img.get_height():
					img.set_pixel(px, py, c)


static func _diamond(img: Image, cx: int, cy: int, r: int, c: Color) -> void:
	for py in range(cy - r, cy + r + 1):
		var half: int = r - abs(py - cy)
		for px in range(cx - half, cx + half + 1):
			if px >= 0 and py >= 0 and px < img.get_width() and py < img.get_height():
				img.set_pixel(px, py, c)
