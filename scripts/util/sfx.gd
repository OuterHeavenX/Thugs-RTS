class_name Sfx
extends Node

## Tiny code-synthesized blips. Players are created lazily and every
## play() is guarded so this can never crash (including on web).

var _players: Array = []
var _next := 0
var _streams := {}


func _ready() -> void:
	for i in 4:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	_streams["select"] = _tone(660.0, 0.07)
	_streams["move"] = _tone(440.0, 0.07)
	_streams["attack"] = _tone(200.0, 0.10)
	_streams["coin"] = _tone(990.0, 0.12)
	_streams["build"] = _tone(523.0, 0.20)
	_streams["error"] = _tone(160.0, 0.15)


func play(sfx_name: String) -> void:
	if not is_inside_tree():
		return
	if _players.is_empty() or not _streams.has(sfx_name):
		return
	var p: AudioStreamPlayer = _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = _streams[sfx_name]
	p.play()


func _tone(freq: float, dur: float) -> AudioStreamWAV:
	var rate := 22050
	var frames := int(float(rate) * dur)
	var data := PackedByteArray()
	data.resize(frames)
	for i in frames:
		var t := float(i) / float(rate)
		var env := 1.0 - float(i) / float(maxi(1, frames))
		var v := 128.0 + 110.0 * env * sin(TAU * freq * t)
		data[i] = int(clampf(v, 0.0, 255.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_8_BITS
	s.mix_rate = rate
	s.stereo = false
	s.data = data
	return s
