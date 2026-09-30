class_name HeliosValley
extends Node3D

## Helios Valley map: terrain, bases, resources, props, nav blocking.
## build(nav, fow=null) constructs everything. fow is optional so the valley can
## be built headless without the fog system; terrain then renders fully visible.
##
## Deviation from the task text: Building/Unit are instantiated via
## ResourceLoader.load("res://scripts/buildings/building.gd") /
## ("res://scripts/units/unit.gd") instead of `Building.new()` / `Unit.new()`.
## A direct class_name reference fails to PARSE when the other chunk's script
## is missing; script-path instantiation keeps the exact same runtime contract
## (`.new()` + `setup(data, pid)`) while degrading gracefully.

signal built

const MAP_HALF := 64.0
const SEED := 20260928

const WEST_BASE := Vector3(-44, 0, 0)
const EAST_BASE := Vector3(44, 0, 0)

const TREE_MODEL := "res://assets/models/environment/tree.glb"
const ROCK_MODEL := "res://assets/models/environment/rock.glb"
const FACILITY_MODEL := "res://assets/models/environment/abandoned_facility.glb"

var resource_nodes: Array[ResourceNode] = []

var _west_pid := 0
var _east_pid := 1
var _minimap_tex: ImageTexture
var _fow_default_tex: ImageTexture


func base_center(pid: int) -> Vector3:
	if pid == _west_pid:
		return WEST_BASE
	return EAST_BASE


func spawn_pos(pid: int) -> Vector3:
	return base_center(pid) + Vector3(0, 0, 12.0)


func get_minimap_image() -> ImageTexture:
	if _minimap_tex == null:
		_bake_minimap()
	return _minimap_tex


func build(nav: NavGrid, fow = null) -> void:
	_resolve_pids()
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	_build_terrain(nav, fow)
	_place_bases(nav)
	_place_resources(nav, rng)
	_place_expansions(nav, rng)
	_place_trees(nav, rng)
	_place_rocks(nav, rng)
	_place_landmark(nav)
	_bake_minimap()
	built.emit()


# ------------------------------------------------------------------ layout
func _resolve_pids() -> void:
	# US west, Japan east. If a match is running, use its player ids so the
	# human's faction sits on the correct side no matter which they picked.
	_west_pid = 0
	_east_pid = 1
	var players: Array = Game.players
	if players.size() >= 2:
		for p in players:
			if p == null or p.faction == null:
				continue
			if p.faction.id == "us":
				_west_pid = p.id
			elif p.faction.id == "japan":
				_east_pid = p.id


func _faction_of(pid: int) -> String:
	if pid == _west_pid:
		return "us"
	return "japan"


# ------------------------------------------------------------------ terrain
func _build_terrain(nav: NavGrid, fow) -> void:
	var n := 128
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	verts.resize((n + 1) * (n + 1))
	normals.resize((n + 1) * (n + 1))
	uvs.resize((n + 1) * (n + 1))
	colors.resize((n + 1) * (n + 1))
	var k := 0
	for j in range(n + 1):
		for i in range(n + 1):
			var x := -MAP_HALF + 128.0 * float(i) / float(n)
			var z := -MAP_HALF + 128.0 * float(j) / float(n)
			verts[k] = Vector3(x, 0.0, z)
			normals[k] = Vector3.UP
			uvs[k] = Vector2(float(i) / float(n), float(j) / float(n))
			colors[k] = _terrain_color(x, z)
			k += 1
	for j in range(n):
		for i in range(n):
			var a := j * (n + 1) + i
			var b := a + 1
			var c := a + (n + 1)
			var d := c + 1
			# Winding: counter-clockwise seen from +Y (above). [a,c,b] is
			# clockwise from above and gets back-face culled — the terrain
			# was invisible because of this (verified 2026-09-29).
			indices.append_array([a, b, c, b, d, c])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var shader_res := ResourceLoader.load("res://assets/shaders/fow.gdshader") as Shader
	var mat := ShaderMaterial.new()
	if shader_res != null:
		mat.shader = shader_res
	var fow_tex: Texture2D = null
	if fow != null and fow.has_method("get_texture"):
		fow_tex = fow.get_texture()
	if fow_tex == null:
		if _fow_default_tex == null:
			var img := Image.create(64, 64, false, Image.FORMAT_R8)
			img.fill(Color(1, 1, 1))
			_fow_default_tex = ImageTexture.create_from_image(img)
		fow_tex = _fow_default_tex
	mat.set_shader_parameter("fow_tex", fow_tex)
	var mi := MeshInstance3D.new()
	mi.name = "Terrain"
	mi.mesh = mesh
	mi.material_override = mat
	add_child(mi)


func _terrain_color(x: float, z: float) -> Color:
	var noise := _vnoise(x * 0.15, z * 0.15)
	var grass := Color(0.23, 0.38, 0.18) * (0.90 + 0.20 * noise)
	var col := grass
	# Dirt road: east-west through the center, connecting the two bases.
	var road := (1.0 - smoothstep(3.0, 5.0, absf(z))) * (1.0 - smoothstep(44.0, 48.0, absf(x)))
	col = col.lerp(Color(0.45, 0.34, 0.22), clampf(road, 0.0, 1.0))
	# Darker rock near map edges.
	var edge := smoothstep(52.0, 60.0, maxf(absf(x), absf(z)))
	col = col.lerp(Color(0.30, 0.29, 0.33), edge)
	# Subtle teal tint over the central helios field.
	var d := Vector2(x, z).length()
	var heli := 1.0 - smoothstep(8.0, 18.0, d)
	col = col.lerp(Color(0.30, 0.42, 0.40), heli * 0.35)
	return col


func _hash2(x: float, z: float) -> float:
	var h := sin(x * 12.9898 + z * 78.233) * 43758.5453
	return h - floor(h)


func _vnoise(x: float, z: float) -> float:
	var xi: float = floorf(x)
	var zi: float = floorf(z)
	var xf := x - xi
	var zf := z - zi
	var u := xf * xf * (3.0 - 2.0 * xf)
	var v := zf * zf * (3.0 - 2.0 * zf)
	var a := _hash2(xi, zi)
	var b := _hash2(xi + 1.0, zi)
	var c := _hash2(xi, zi + 1.0)
	var d := _hash2(xi + 1.0, zi + 1.0)
	return lerpf(lerpf(a, b, u), lerpf(c, d, u), v)


func _bake_minimap() -> void:
	var size := 128
	var img := Image.create(size, size, false, Image.FORMAT_RGB8)
	for py in range(size):
		for px in range(size):
			var x := -MAP_HALF + (float(px) + 0.5)
			var z := -MAP_HALF + (float(py) + 0.5)
			img.set_pixel(px, py, _terrain_color(x, z))
	_minimap_tex = ImageTexture.create_from_image(img)


# ------------------------------------------------------------------ bases
func _place_bases(nav: NavGrid) -> void:
	var bscript := ResourceLoader.load("res://scripts/buildings/building.gd") as GDScript
	# Starting units are always workers: spawn the Worker subclass so the
	# gather/build economy actually functions (base Unit._tick_gather just
	# idles — see bug report 2026-09-29).
	var wscript := ResourceLoader.load("res://scripts/units/worker.gd") as GDScript
	if bscript == null or wscript == null:
		push_warning("HeliosValley: Building/Worker scripts missing; skipping base unit placement.")
		return
	for pid in [_west_pid, _east_pid]:
		var fid := _faction_of(pid)
		var c := base_center(pid)
		var bdata: BuildingData = Data.building(fid, "command")
		if bdata == null:
			push_warning("HeliosValley: no command building data for faction " + fid)
			continue
		var b = bscript.new()
		b.setup(bdata, pid)
		add_child(b)
		if b.has_method("place_at"):
			b.place_at(c)
		else:
			b.global_position = c
		# Belt-and-suspenders: place_at blocks via Building.nav_grid when the
		# static is injected (real game); ensure it here too since the valley
		# owns the authoritative nav reference (idempotent).
		var fp: Vector2i = bdata.get("footprint")
		if fp == null:
			fp = Vector2i(5, 5)
		nav.set_blocked_rect(c, fp, true)
		if b.has_method("debug_complete"):
			b.debug_complete()
		Game.register_building(b)
		var udata: UnitData = Data.unit(fid, "worker")
		if udata == null:
			push_warning("HeliosValley: no worker unit data for faction " + fid)
			continue
		for i in range(5):
			var a := TAU * float(i) / 5.0
			var u = wscript.new()
			u.setup(udata, pid)
			add_child(u)
			u.global_position = c + Vector3(cos(a), 0.0, sin(a)) * 9.0
			Game.register_unit(u)


# ------------------------------------------------------------------ resources
func _add_resource(kind: String, pos: Vector3) -> ResourceNode:
	var node := ResourceNode.new()
	node.setup(kind)
	add_child(node)
	node.global_position = Vector3(pos.x, 0.0, pos.z)
	resource_nodes.append(node)
	return node


func _place_resources(nav: NavGrid, rng: RandomNumberGenerator) -> void:
	# Central helios field: 7 crystals scattered around (0,0), radius ~8-14m.
	for i in range(7):
		var a := TAU * float(i) / 7.0 + rng.randf_range(-0.2, 0.2)
		var r := rng.randf_range(8.0, 14.0)
		_add_resource("helios", Vector3(cos(a) * r, 0.0, sin(a) * r))
	# 5 supply deposits near each base (within 25m, spread out).
	for pid in [_west_pid, _east_pid]:
		var c := base_center(pid)
		for i in range(5):
			var a := TAU * float(i) / 5.0 + 0.35 + rng.randf_range(-0.15, 0.15)
			var r := rng.randf_range(12.0, 20.0)
			var pos := c + Vector3(cos(a) * r, 0.0, sin(a) * r)
			pos.x = clampf(pos.x, -58.0, 58.0)
			pos.z = clampf(pos.z, -58.0, 58.0)
			_add_resource("supply", pos)


func _place_expansions(nav: NavGrid, rng: RandomNumberGenerator) -> void:
	var sites := [
		Vector3(-20, 0, -35), Vector3(-20, 0, 35),
		Vector3(20, 0, -35), Vector3(20, 0, 35),
	]
	for site in sites:
		for i in range(3):
			var a := TAU * float(i) / 3.0 + rng.randf_range(-0.2, 0.2)
			var r := rng.randf_range(3.0, 5.5)
			_add_resource("supply", site + Vector3(cos(a) * r, 0.0, sin(a) * r))
		for i in range(2):
			var a := TAU * float(i) / 2.0 + 0.7 + rng.randf_range(-0.2, 0.2)
			var r := rng.randf_range(6.5, 8.5)
			_add_resource("helios", site + Vector3(cos(a) * r, 0.0, sin(a) * r))
		_add_expansion_ring(site)


func _add_expansion_ring(site: Vector3) -> void:
	var torus := TorusMesh.new()
	torus.inner_radius = 9.6
	torus.outer_radius = 10.4
	torus.rings = 48
	torus.ring_segments = 8
	var mi := MeshInstance3D.new()
	mi.mesh = torus
	mi.position = Vector3(site.x, 0.15, site.z)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.3, 0.9, 1.0, 0.45)
	mi.material_override = mat
	add_child(mi)


# ------------------------------------------------------------------ props
func _clear_of(pos: Vector3, spots: Array, dist: float) -> bool:
	for s in spots:
		if pos.distance_to(s) < dist:
			return false
	return true


func _expansion_sites() -> Array:
	return [
		Vector3(-20, 0, -35), Vector3(-20, 0, 35),
		Vector3(20, 0, -35), Vector3(20, 0, 35),
	]


func _place_trees(nav: NavGrid, rng: RandomNumberGenerator) -> void:
	var tree_scene := ResourceLoader.load(TREE_MODEL) as PackedScene
	var sites := _expansion_sites()
	var avoid: Array = [Vector3.ZERO, Vector3(0, 0, -25), WEST_BASE, EAST_BASE] + sites
	var placed := 0
	var tries := 0
	while placed < 50 and tries < 160:
		tries += 1
		var north := placed < 25
		var pos := Vector3(
			rng.randf_range(-56.0, 56.0), 0.0,
			rng.randf_range(-52.0, -34.0) if north else rng.randf_range(34.0, 52.0))
		if not _clear_of(pos, avoid, 14.0):
			continue
		if absf(pos.z) < 7.0 and absf(pos.x) < 50.0:
			continue  # keep the road clear
		var tree: Node3D
		if tree_scene != null:
			tree = tree_scene.instantiate()
		else:
			tree = _fallback_tree()
		add_child(tree)
		tree.global_position = pos
		tree.rotation.y = rng.randf_range(0.0, TAU)
		var s := rng.randf_range(0.85, 1.25)
		tree.scale = Vector3(s, s, s)
		nav.set_blocked_rect(pos, Vector2i(1, 1), true)
		placed += 1


func _fallback_tree() -> Node3D:
	var root := Node3D.new()
	root.name = "FallbackTree"
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.25
	trunk_mesh.bottom_radius = 0.35
	trunk_mesh.height = 2.0
	var trunk := MeshInstance3D.new()
	trunk.mesh = trunk_mesh
	trunk.position = Vector3(0, 1.0, 0)
	var bark := StandardMaterial3D.new()
	bark.albedo_color = Color(0.30, 0.20, 0.12)
	trunk.material_override = bark
	root.add_child(trunk)
	var cone_mesh := CylinderMesh.new()
	cone_mesh.top_radius = 0.1
	cone_mesh.bottom_radius = 1.7
	cone_mesh.height = 3.2
	cone_mesh.radial_segments = 8
	var cone := MeshInstance3D.new()
	cone.mesh = cone_mesh
	cone.position = Vector3(0, 3.2, 0)
	var leaf := StandardMaterial3D.new()
	leaf.albedo_color = Color(0.16, 0.34, 0.14)
	cone.material_override = leaf
	root.add_child(cone)
	return root


func _place_rocks(nav: NavGrid, rng: RandomNumberGenerator) -> void:
	var rock_scene := ResourceLoader.load(ROCK_MODEL) as PackedScene
	var sites := _expansion_sites()
	var avoid: Array = [Vector3.ZERO, Vector3(0, 0, -25), WEST_BASE, EAST_BASE] + sites
	var placed := 0
	var tries := 0
	while placed < 12 and tries < 80:
		tries += 1
		var pos := Vector3(rng.randf_range(-56.0, 56.0), 0.0, rng.randf_range(-56.0, 56.0))
		if absf(pos.z) < 8.0 and absf(pos.x) < 52.0:
			continue  # road
		if absf(pos.z) > 30.0:
			continue  # forests
		if not _clear_of(pos, avoid, 14.0):
			continue
		var rock: Node3D
		if rock_scene != null:
			rock = rock_scene.instantiate()
		else:
			rock = _fallback_rock()
		add_child(rock)
		rock.global_position = pos
		rock.rotation.y = rng.randf_range(0.0, TAU)
		nav.set_blocked_rect(pos, Vector2i(2, 2), true)
		placed += 1


func _fallback_rock() -> Node3D:
	var root := Node3D.new()
	root.name = "FallbackRock"
	var mesh := SphereMesh.new()
	mesh.radius = 1.2
	mesh.height = 2.0
	mesh.radial_segments = 7
	mesh.rings = 4
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = Vector3(0, 0.7, 0)
	mi.scale = Vector3(1.4, 0.9, 1.2)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.38, 0.37, 0.40)
	mat.roughness = 0.95
	mi.material_override = mat
	root.add_child(mi)
	return root


func _place_landmark(nav: NavGrid) -> void:
	var facility_scene := ResourceLoader.load(FACILITY_MODEL) as PackedScene
	var pos := Vector3(0, 0, -25)
	var landmark: Node3D
	if facility_scene != null:
		landmark = facility_scene.instantiate()
	else:
		landmark = _fallback_facility()
	add_child(landmark)
	landmark.global_position = pos
	nav.set_blocked_rect(pos, Vector2i(6, 4), true)


func _fallback_facility() -> Node3D:
	var root := Node3D.new()
	root.name = "FallbackFacility"
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.22, 0.22, 0.26)
	mat.metallic = 0.5
	mat.roughness = 0.6
	var specs := [
		[Vector3(0, 1.5, 0), Vector3(6, 3, 3), Vector3(0, 0.1, 0)],
		[Vector3(4.5, 1.0, 1.5), Vector3(3, 2, 2.5), Vector3(0, 0.5, 0.15)],
		[Vector3(-4.2, 0.8, -1.0), Vector3(2.5, 1.6, 2.0), Vector3(0.1, -0.4, -0.1)],
	]
	for spec in specs:
		var box := BoxMesh.new()
		box.size = spec[1]
		var mi := MeshInstance3D.new()
		mi.mesh = box
		mi.position = spec[0]
		mi.rotation = spec[2]
		mi.material_override = mat
		root.add_child(mi)
	return root
