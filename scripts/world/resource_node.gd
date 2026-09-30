class_name ResourceNode
extends Node3D

## Harvestable resource deposit on the map.
## kind: "supply" (1500) or "helios" (800). Emits depleted and frees at 0.

signal depleted(node: ResourceNode)

const SUPPLY_AMOUNT := 1500.0
const HELIOS_AMOUNT := 800.0
const SUPPLY_MODEL := "res://assets/models/environment/supply_deposit.glb"
const HELIOS_MODEL := "res://assets/models/environment/helios_crystal.glb"

var kind: String = "supply"
var amount: float = 0.0
var max_amount: float = 0.0


func _ready() -> void:
	# Workers locate harvest targets through this group.
	add_to_group("resource_nodes")


func setup(p_kind: String) -> void:
	if p_kind == "helios":
		kind = "helios"
		amount = HELIOS_AMOUNT
	else:
		kind = "supply"
		amount = SUPPLY_AMOUNT
	max_amount = amount
	_build_visual()


## Deducts up to requested from the node. Emits depleted and queue_frees
## itself when emptied. Returns the actual amount harvested.
func harvest(requested: float) -> float:
	if amount <= 0.0:
		return 0.0
	var actual: float = minf(amount, maxf(requested, 0.0))
	amount -= actual
	if amount <= 0.0:
		amount = 0.0
		depleted.emit(self)
		queue_free()
	else:
		_update_visual()
	return actual


func fraction_left() -> float:
	if max_amount <= 0.0:
		return 0.0
	return amount / max_amount


func _build_visual() -> void:
	var path := HELIOS_MODEL if kind == "helios" else SUPPLY_MODEL
	var packed := ResourceLoader.load(path) as PackedScene
	if packed != null:
		var inst := packed.instantiate()
		add_child(inst)
	else:
		add_child(_fallback_visual())


func _fallback_visual() -> Node3D:
	# Primitive stand-ins so the game never breaks when the .glb is missing.
	var root := Node3D.new()
	root.name = "FallbackModel"
	if kind == "helios":
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.25
		mesh.bottom_radius = 0.9
		mesh.height = 2.4
		mesh.radial_segments = 6
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.position = Vector3(0, 1.2, 0)
		mi.rotation.y = 0.5
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.05, 0.25, 0.3)
		mat.emission_enabled = true
		mat.emission = Color(0.2, 0.9, 1.0)
		mat.emission_energy_multiplier = 2.0
		mi.material_override = mat
		root.add_child(mi)
		var mi2 := MeshInstance3D.new()
		mi2.mesh = mesh
		mi2.position = Vector3(0.7, 0.8, 0.4)
		mi2.rotation = Vector3(0.2, 1.2, -0.25)
		mi2.scale = Vector3(0.6, 0.7, 0.6)
		mi2.material_override = mat
		root.add_child(mi2)
	else:
		var mesh := CylinderMesh.new()
		mesh.top_radius = 1.4
		mesh.bottom_radius = 1.7
		mesh.height = 1.2
		mesh.radial_segments = 6
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.position = Vector3(0, 0.6, 0)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.32, 0.27, 0.16)
		mat.metallic = 0.4
		mat.roughness = 0.7
		mi.material_override = mat
		root.add_child(mi)
	return root


func _update_visual() -> void:
	# Subtle shrink as the node depletes; never below 40% scale.
	var s := 0.4 + 0.6 * fraction_left()
	scale = Vector3(s, s, s)
