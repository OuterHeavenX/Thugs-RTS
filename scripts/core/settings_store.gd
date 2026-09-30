extends RefCounted
## Persistent settings store (no class_name by chunk convention).
## Loaded via preload("res://scripts/core/settings_store.gd") wherever needed.
## Keys: graphics (0=Low,1=Med,2=High), music (bool), sfx (bool), edge_pan (bool).

const PATH := "user://settings.cfg"

static var _cache: Dictionary = {}
static var _loaded := false


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	_cache = {
		"graphics": 1,
		"music": true,
		"sfx": true,
		"edge_pan": true,
	}
	var cfg := ConfigFile.new()
	if cfg.load(PATH) == OK:
		for k in _cache.keys():
			_cache[k] = cfg.get_value("settings", k, _cache[k])


static func get_setting(key: String, default = null):
	_ensure_loaded()
	return _cache.get(key, default)


static func set_setting(key: String, value) -> void:
	_ensure_loaded()
	_cache[key] = value
	save()


static func save() -> void:
	_ensure_loaded()
	var cfg := ConfigFile.new()
	for k in _cache.keys():
		cfg.set_value("settings", k, _cache[k])
	cfg.save(PATH)
