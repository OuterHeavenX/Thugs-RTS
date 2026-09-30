class_name NavGrid
extends RefCounted

## 2m cells over a 128x128m map => 64x64 grid.
## A* pathfinding, 8-directional, y=0 waypoints. No rendering, headless-safe.

const CELL_SIZE := 2.0
const GRID_W := 64
const GRID_H := 64
const CELL_COUNT := 4096
const MAP_HALF := 64.0
const INF := 1.0e30
const SQRT2 := 1.41421356

var _blocked := PackedByteArray()


func setup() -> void:
	_blocked.resize(CELL_COUNT)
	_blocked.fill(0)


func in_bounds(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < GRID_W and c.y < GRID_H


func is_cell_walkable(c: Vector2i) -> bool:
	return in_bounds(c) and _blocked[c.y * GRID_W + c.x] == 0


func world_to_cell(pos: Vector3) -> Vector2i:
	var cx := int(floor((pos.x + MAP_HALF) / CELL_SIZE))
	var cz := int(floor((pos.z + MAP_HALF) / CELL_SIZE))
	return Vector2i(clampi(cx, 0, GRID_W - 1), clampi(cz, 0, GRID_H - 1))


func cell_to_world(c: Vector2i) -> Vector3:
	return Vector3(
		float(c.x) * CELL_SIZE + CELL_SIZE * 0.5 - MAP_HALF,
		0.0,
		float(c.y) * CELL_SIZE + CELL_SIZE * 0.5 - MAP_HALF)


func clamp_to_map(pos: Vector3) -> Vector3:
	var m := MAP_HALF - 0.5
	return Vector3(clampf(pos.x, -m, m), 0.0, clampf(pos.z, -m, m))


func set_blocked_rect(center: Vector3, size_cells: Vector2i, blocked: bool) -> void:
	var cc := world_to_cell(center)
	var sx := maxi(size_cells.x, 1)
	var sz := maxi(size_cells.y, 1)
	var ox := cc.x - sx / 2
	var oz := cc.y - sz / 2
	var v: int = 1 if blocked else 0
	for dz in range(sz):
		for dx in range(sx):
			var c := Vector2i(ox + dx, oz + dz)
			if in_bounds(c):
				_blocked[c.y * GRID_W + c.x] = v


## Nearest walkable cell to c, searching outward rings up to max_radius.
## Returns Vector2i(-1, -1) when nothing walkable is found.
func nearest_walkable(c: Vector2i, max_radius: int) -> Vector2i:
	if is_cell_walkable(c):
		return c
	for r in range(1, max_radius + 1):
		for dz in range(-r, r + 1):
			for dx in [-r, r]:
				var t := Vector2i(c.x + dx, c.y + dz)
				if is_cell_walkable(t):
					return t
		for dx in range(-r + 1, r):
			for dz in [-r, r]:
				var t := Vector2i(c.x + dx, c.y + dz)
				if is_cell_walkable(t):
					return t
	return Vector2i(-1, -1)


func find_path(from: Vector3, to: Vector3) -> PackedVector3Array:
	var out := PackedVector3Array()
	if _blocked.size() != CELL_COUNT:
		return out
	var start := nearest_walkable(world_to_cell(clamp_to_map(from)), 6)
	var goal := nearest_walkable(world_to_cell(clamp_to_map(to)), 16)
	if start.x < 0 or goal.x < 0:
		return out
	if start == goal:
		return out
	var cells: Array = _astar(start, goal)
	if cells.is_empty():
		return out
	cells = _smooth_path(cells)
	for c in cells:
		out.append(cell_to_world(c))
	return out


# ------------------------------------------------------------------ internals
func _heuristic(a: Vector2i, b: Vector2i) -> float:
	var dx := absf(float(a.x - b.x))
	var dz := absf(float(a.y - b.y))
	return (maxf(dx, dz) + 0.41421356 * minf(dx, dz)) * CELL_SIZE


func _astar(start: Vector2i, goal: Vector2i) -> Array:
	var g := PackedFloat32Array()
	g.resize(CELL_COUNT)
	g.fill(INF)
	var came := PackedInt32Array()
	came.resize(CELL_COUNT)
	came.fill(-1)
	var closed := PackedByteArray()
	closed.resize(CELL_COUNT)
	var heap: Array = []
	var heap_f: Array = []
	var si := start.y * GRID_W + start.x
	var gi := goal.y * GRID_W + goal.x
	g[si] = 0.0
	_heap_push(heap, heap_f, si, _heuristic(start, goal))
	var found := false
	var guard := 0
	var dirs := [
		Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
		Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1),
	]
	while not heap.is_empty() and guard < CELL_COUNT * 4:
		guard += 1
		var cur: int = _heap_pop(heap, heap_f)
		if closed[cur] == 1:
			continue
		closed[cur] = 1
		if cur == gi:
			found = true
			break
		var cx := cur % GRID_W
		var cy := cur / GRID_W
		for d in dirs:
			var nx = cx + d.x
			var ny = cy + d.y
			if nx < 0 or ny < 0 or nx >= GRID_W or ny >= GRID_H:
				continue
			var ni = ny * GRID_W + nx
			if closed[ni] == 1 or _blocked[ni] == 1:
				continue
			var diag = d.x != 0 and d.y != 0
			if diag:
				# No corner cutting through blocked orthogonal neighbours.
				if _blocked[cy * GRID_W + nx] == 1 or _blocked[ny * GRID_W + cx] == 1:
					continue
			var step := (SQRT2 if diag else 1.0) * CELL_SIZE
			var ng := g[cur] + step
			if ng < g[ni] - 0.0001:
				g[ni] = ng
				came[ni] = cur
				_heap_push(heap, heap_f, ni, ng + _heuristic(Vector2i(nx, ny), goal))
	var path: Array = []
	if found:
		var cur := gi
		while cur != -1:
			path.push_front(Vector2i(cur % GRID_W, cur / GRID_W))
			cur = came[cur]
	return path


func _heap_push(heap: Array, f: Array, idx: int, score: float) -> void:
	heap.append(idx)
	f.append(score)
	var i := heap.size() - 1
	while i > 0:
		var p := (i - 1) / 2
		if float(f[i]) < float(f[p]):
			var ti = heap[i]
			heap[i] = heap[p]
			heap[p] = ti
			var tf = f[i]
			f[i] = f[p]
			f[p] = tf
			i = p
		else:
			break


func _heap_pop(heap: Array, f: Array) -> int:
	var top: int = heap[0]
	var last := heap.size() - 1
	heap[0] = heap[last]
	f[0] = f[last]
	heap.remove_at(last)
	f.remove_at(last)
	var i := 0
	while true:
		var l := i * 2 + 1
		var r := l + 1
		var m := i
		if l < heap.size() and float(f[l]) < float(f[m]):
			m = l
		if r < heap.size() and float(f[r]) < float(f[m]):
			m = r
		if m == i:
			break
		var ti = heap[i]
		heap[i] = heap[m]
		heap[m] = ti
		var tf = f[i]
		f[i] = f[m]
		f[m] = tf
		i = m
	return top


## Greedy line-of-sight smoothing. cells[0] is the start cell (excluded from
## output); output holds walkable waypoints ending at the goal cell.
func _smooth_path(cells: Array) -> Array:
	if cells.size() <= 2:
		return cells.slice(1) if cells.size() == 2 else []
	var out: Array = []
	var i := 0
	while i < cells.size() - 1:
		var j := cells.size() - 1
		while j > i + 1 and not _line_walkable(cells[i], cells[j]):
			j -= 1
		out.append(cells[j])
		i = j
	return out


func _line_walkable(a: Vector2i, b: Vector2i) -> bool:
	var pa := cell_to_world(a)
	var pb := cell_to_world(b)
	var dist := pa.distance_to(pb)
	var steps := maxi(int(ceil(dist / 1.0)), 1)
	for s in range(steps + 1):
		var p := pa.lerp(pb, float(s) / float(steps))
		if not is_cell_walkable(world_to_cell(p)):
			return false
	return true
