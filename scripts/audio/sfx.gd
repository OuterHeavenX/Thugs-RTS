extends Node

## Procedural SFX autoload. All sounds are synthesized in code as 16-bit
## 22050Hz AudioStreamWAVs (sine/square/noise with envelopes), generated
## lazily on first play. 8-player round-robin pool. Headless-safe: the dummy
## audio driver makes play() a no-op, and generation never touches hardware.
##
## API: play(name), set_enabled(b), set_volume(v 0..1) via the Master bus.
## (set_volumes/music_enabled/sfx_enabled kept from the stub for callers.)

const SAMPLE_RATE := 22050

var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _cache: Dictionary = {}
var _enabled := true
var _music_on := true
var _sfx_on := true


func _ready() -> void:
	for i in 8:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_players.append(p)


func set_enabled(b: bool) -> void:
	_enabled = b


## Master-bus volume, 0..1 mapped to dB.
func set_volume(v: float) -> void:
	var bus := AudioServer.get_bus_index("Master")
	if bus >= 0:
		AudioServer.set_bus_volume_db(bus, linear_to_db(clampf(v, 0.001, 1.0)))


func set_volumes(music_on: bool, sfx_on: bool) -> void:
	_music_on = music_on
	_sfx_on = sfx_on
	var bus := AudioServer.get_bus_index("Master")
	if bus >= 0:
		# Music bus may not exist in the slice; guard it.
		var mbus := AudioServer.get_bus_index("Music")
		if mbus >= 0:
			AudioServer.set_bus_mute(mbus, not music_on)


func music_enabled() -> bool:
	return _music_on


func sfx_enabled() -> bool:
	return _sfx_on


func play(sfx_name: String, volume_db: float = 0.0) -> void:
	if not _enabled or not _sfx_on:
		return
	if _players.is_empty():
		return
	var stream: AudioStreamWAV = _cache.get(sfx_name, null)
	if stream == null:
		stream = _make(sfx_name)
		_cache[sfx_name] = stream
	if stream == null:
		return
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = stream
	p.volume_db = volume_db
	p.play()


# ------------------------------------------------------------ synthesis
## wave: 0 = sine, 1 = square, 2 = noise. freq sweeps f0 -> f1.
func _tone(f0: float, f1: float, dur: float, vol: float, wave: int = 0) -> PackedFloat32Array:
	var n := maxi(1, int(SAMPLE_RATE * dur))
	var out := PackedFloat32Array()
	out.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(f0 * 13.0 + f1 * 7.0 + n)
	var phase := 0.0
	for i in n:
		var f := lerpf(f0, f1, float(i) / float(maxi(1, n - 1)))
		phase += TAU * f / SAMPLE_RATE
		var s := 0.0
		match wave:
			0:
				s = sin(phase)
			1:
				s = 1.0 if sin(phase) >= 0.0 else -1.0
			2:
				s = rng.randf_range(-1.0, 1.0)
		var env := 1.0 - float(i) / float(n)
		out[i] = s * vol * env * env
	return out


## Concatenate [freq, dur] notes into one envelope-shaped buffer.
func _seq(notes: Array, vol: float, wave: int = 0) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for note in notes:
		var part := _tone(float(note[0]), float(note[0]), float(note[1]), vol, wave)
		out.append_array(part)
	return out


func _mix(a: PackedFloat32Array, b: PackedFloat32Array) -> PackedFloat32Array:
	var n := maxi(a.size(), b.size())
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var v := 0.0
		if i < a.size():
			v += a[i]
		if i < b.size():
			v += b[i]
		out[i] = v
	return out


func _wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SAMPLE_RATE
	wav.stereo = false
	wav.data = data
	return wav


func _make(sfx_name: String) -> AudioStreamWAV:
	match sfx_name:
		"shoot":
			return _wav(_mix(_tone(1600.0, 500.0, 0.10, 0.45, 2), _tone(2200.0, 900.0, 0.07, 0.25)))
		"cannon":
			return _wav(_mix(_tone(95.0, 32.0, 0.35, 0.85), _tone(0.0, 0.0, 0.22, 0.5, 2)))
		"explosion":
			return _wav(_mix(_tone(0.0, 0.0, 0.45, 0.9, 2), _tone(65.0, 24.0, 0.45, 0.7)))
		"build":
			return _wav(_tone(1300.0, 800.0, 0.22, 0.32, 1))
		"harvest":
			return _wav(_tone(1500.0, 2300.0, 0.12, 0.32))
		"select":
			return _wav(_tone(880.0, 880.0, 0.07, 0.3))
		"order":
			return _wav(_tone(660.0, 660.0, 0.09, 0.35))
		"error":
			return _wav(_tone(200.0, 140.0, 0.22, 0.4, 1))
		"research":
			return _wav(_seq([[520.0, 0.12], [660.0, 0.12], [880.0, 0.16]], 0.35))
		"train":
			return _wav(_seq([[440.0, 0.12], [560.0, 0.16]], 0.35))
		"warning":
			return _wav(_seq([[700.0, 0.14], [500.0, 0.14], [700.0, 0.16]], 0.4, 1))
		"victory":
			return _wav(_seq([[523.0, 0.10], [659.0, 0.10], [784.0, 0.10], [1046.0, 0.18]], 0.4))
		"defeat":
			return _wav(_seq([[392.0, 0.15], [330.0, 0.15], [262.0, 0.19]], 0.4))
		"ui":
			return _wav(_tone(1200.0, 1200.0, 0.04, 0.25))
		_:
			return _wav(_tone(500.0, 500.0, 0.08, 0.3))
