class_name MapRuntime
extends Node3D

const SettingsStore := preload("res://scripts/core/settings_store.gd")
## Match-world glue: builds NavGrid, HeliosValley, FogOfWar, injects shared
## references into the unit/building chunks (when present), owns the sun +
## sky, drives fog reveal (10Hz) and enemy hiding (4Hz).
##
## build(headless:=false): pass headless=true in unit tests to skip all
## rendering nodes. Every chunk lookup is defensive — missing chunks log a
## warning and the runtime keeps going.

var nav_grid = null        # NavGrid (world chunk)
var valley = null          # HeliosValley (world chunk)
var fog = null             # FogOfWar (world chunk)

var sun: DirectionalLight3D = null

var _fog_timer := 0.0
var _hide_timer := 0.0
var _built := false


func build(headless: bool = false) -> void:
	if _built:
		return
	_built = true
	nav_grid = _make("res://scripts/navigation/nav_grid.gd", "NavGrid")
	if nav_grid != null and nav_grid.has_method("setup"):
		nav_grid.call("setup")
		# NavGrid is a RefCounted (not a Node); nothing to add to the tree.
	fog = _make("res://scripts/core/fog_of_war.gd", "FogOfWar")
	if fog is Node:
		add_child(fog)
	if fog != null and fog.has_method("setup"):
		fog.call("setup", nav_grid)
	valley = _make("res://scripts/world/helios_valley.gd", "HeliosValley")
	# Inject shared refs BEFORE valley.build(): base placement blocks nav
	# through Building.place_at(), which needs Building.nav_grid set.
	_inject_static("res://scripts/units/unit.gd", "Unit",
		{"nav_grid": nav_grid, "fog": fog})
	_inject_static("res://scripts/buildings/building.gd", "Building",
		{"nav_grid": nav_grid})
	if valley != null:
		if valley is Node:
			add_child(valley)
		if valley.has_method("build"):
			valley.call("build", nav_grid, fog)
	else:
		_fallback_ground()
	if not headless:
		_build_sky()


func _make(path: String, label: String):
	if not ResourceLoader.exists(path):
		push_warning("MapRuntime: %s not present at %s — skipping." % [label, path])
		return null
	var scr: GDScript = ResourceLoader.load(path)
	if scr == null or not scr.can_instantiate():
		push_warning("MapRuntime: failed to load %s." % path)
		return null
	return scr.new()


func _inject_static(path: String, label: String, props: Dictionary) -> void:
	if not ResourceLoader.exists(path):
		return
	var scr: GDScript = ResourceLoader.load(path)
	if scr == null:
		return
	for k in props.keys():
		if props[k] == null:
			continue
		# Static vars are settable on the GDScript resource in Godot 4.
		scr.set(k, props[k])
		if scr.get(k) != props[k]:
			push_warning("MapRuntime: %s has no static '%s' — injection skipped." % [label, k])


func _fallback_ground() -> void:
	# Minimal playable ground when the world chunk is absent.
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(128, 128)
	mi.mesh = pm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.10, 0.13, 0.11)
	mat.roughness = 1.0
	mi.material_override = mat
	add_child(mi)


func _build_sky() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	var sky := Sky.new()
	var mat := ProceduralSkyMaterial.new()
	mat.sky_top_color = Color(0.05, 0.08, 0.16)
	mat.sky_horizon_color = Color(0.16, 0.14, 0.20)
	mat.ground_bottom_color = Color(0.02, 0.02, 0.03)
	mat.ground_horizon_color = Color(0.10, 0.09, 0.12)
	mat.sun_angle_max = 30.0
	sky.sky_material = mat
	e.background_mode = Environment.BG_SKY
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	e.ambient_light_energy = 0.55
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.fog_enabled = true
	e.fog_light_color = Color(0.12, 0.13, 0.18)
	e.fog_density = 0.012
	env.environment = e
	add_child(env)
	sun = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.add_to_group("sun_light")
	sun.rotation = Vector3(deg_to_rad(-52), deg_to_rad(-35), 0)
	sun.light_color = Color(0.75, 0.82, 1.0)
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 160.0
	add_child(sun)
	_apply_shadow_setting()


func _apply_shadow_setting() -> void:
	if sun == null:
		return
	var g := int(SettingsStore.get_setting("graphics", 1))
	sun.shadow_enabled = g >= 1


func _process(delta: float) -> void:
	if Game.phase != Game.Phase.PLAYING:
		return
	_fog_timer += delta
	if _fog_timer >= 0.1:
		_fog_timer = 0.0
		_reveal_fog()
	_hide_timer += delta
	if _hide_timer >= 0.25:
		_hide_timer = 0.0
		_hide_enemies()


func _reveal_fog() -> void:
	if fog == null or not fog.has_method("reveal"):
		return
	fog.call("reveal", Game.units_of(Game.human_id))


func _hide_enemies() -> void:
	# Contract: FogOfWar.is_visible_at (NOT is_visible — Node3D owns that name).
	if fog == null or not fog.has_method("is_visible_at"):
		return
	for e in Game.enemies_of(Game.human_id):
		if e is Node3D:
			e.visible = bool(fog.call("is_visible_at", e.global_position))
