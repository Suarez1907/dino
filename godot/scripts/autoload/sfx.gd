extends Node

var sounds := {}
var _players: Array[AudioStreamPlayer] = []
var music: AudioStreamPlayer

func _ready() -> void:
	sounds = {
		"ui": _tone(520, 0.08, "sine"),
		"dig": _noise(0.18, 0.5),
		"brush": _noise(0.16, 0.18),
		"spray": _tone(880, 0.18, "noise"),
		"pick": _tone(140, 0.12, "square"),
		"chisel": _tone(320, 0.09, "square"),
		"wrong": _tone(180, 0.16, "sine"),
		"crack": _noise(0.22, 0.9),
		"collect": _arpeggio([523, 659, 784], 0.09),
		"snap": _tone(740, 0.07, "sine"),
		"ping": _arpeggio([660, 880], 0.08),
		"star": _arpeggio([523, 659, 784, 1046], 0.1),
		"roar_low": _roar(90, 0.7),
		"roar_mid": _roar(150, 0.55),
		"roar_high": _roar(280, 0.4),
		"step": _noise(0.05, 0.25),
		"tool_upgrade": _arpeggio([392, 523, 659, 880], 0.09),
		"research_unlock": _arpeggio([440, 554, 659, 880, 1108], 0.08),
		"photo_shutter": _noise(0.06, 0.85),
		"fossil_snap": _tone(620, 0.1, "square"),
		"layer_break_0": _noise(0.14, 0.35),
		"layer_break_1": _noise(0.18, 0.55),
		"layer_break_2": _noise(0.22, 0.75),
		"layer_break_3": _noise(0.28, 1.0),
	}
	_setup_buses()
	for i in 6:
		var player := AudioStreamPlayer.new()
		add_child(player)
		_players.append(player)
	music = AudioStreamPlayer.new()
	music.stream = _loop_bed()
	add_child(music)
	apply_volumes()
	music.play()

func _setup_buses() -> void:
	var wanted: Array[String] = ["Master", "Tools", "Ambient", "UI", "Voice"]
	for name in wanted:
		if AudioServer.get_bus_index(name) != -1:
			continue
		AudioServer.add_bus()
		var idx := AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, name)
		AudioServer.set_bus_send(idx, "Master")

func layer_break(index: int) -> void:
	play("layer_break_%d" % clampi(index, 0, 3), 1.0)

func apply_volumes() -> void:
	if music:
		var m := float(GameState.settings.music)
		music.volume_db = linear_to_db(max(m, 0.0001))
		music.stream_paused = m <= 0.01

func play(name: String, pitch := 1.0) -> void:
	var gain := float(GameState.settings.sfx)
	if gain <= 0.01 or not sounds.has(name):
		return
	var player: AudioStreamPlayer = _players[_next]
	_next = (_next + 1) % _players.size()
	player.stream = sounds[name]
	player.pitch_scale = pitch
	player.volume_db = linear_to_db(max(gain, 0.0001))
	player.play()

var _next := 0

func _pcm(samples: PackedFloat32Array, rate := 22050) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		var v := int(clamp(samples[i], -1.0, 1.0) * 32000.0)
		data[i * 2] = v & 255
		data[i * 2 + 1] = (v >> 8) & 255
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.stereo = false
	stream.data = data
	return stream

func _tone(freq: float, dur: float, kind: String) -> AudioStreamWAV:
	var rate := 22050
	var count := int(rate * dur)
	var samples := PackedFloat32Array()
	samples.resize(count)
	for i in count:
		var t := float(i) / float(rate)
		var env := pow(1.0 - t / dur, 0.6)
		var s := 0.0
		if kind == "noise":
			s = randf_range(-1.0, 1.0)
		elif kind == "square":
			s = 1.0 if sin(TAU * freq * t) > 0.0 else -1.0
			s *= 0.35
		else:
			s = sin(TAU * freq * t)
		samples[i] = s * env * 0.45
	return _pcm(samples, rate)

func _noise(dur: float, tone: float) -> AudioStreamWAV:
	var rate := 22050
	var count := int(rate * dur)
	var samples := PackedFloat32Array()
	samples.resize(count)
	var hold := 0.0
	for i in count:
		var t := float(i) / float(rate)
		var env := pow(1.0 - t / dur, 1.2)
		hold = lerpf(hold, randf_range(-1.0, 1.0), 0.35)
		var s := hold * (1.0 - tone) + sin(TAU * (90.0 + tone * 400.0) * t) * tone * 0.25
		samples[i] = s * env * 0.5
	return _pcm(samples, rate)

func _arpeggio(freqs: Array, step: float) -> AudioStreamWAV:
	var rate := 22050
	var count := int(rate * step * freqs.size())
	var samples := PackedFloat32Array()
	samples.resize(count)
	for i in count:
		var t := float(i) / float(rate)
		var idx := mini(int(t / step), freqs.size() - 1)
		var local := t - float(idx) * step
		var env := pow(1.0 - local / step, 0.5)
		samples[i] = sin(TAU * float(freqs[idx]) * t) * env * 0.4
	return _pcm(samples, rate)

func _roar(base: float, dur: float) -> AudioStreamWAV:
	var rate := 22050
	var count := int(rate * dur)
	var samples := PackedFloat32Array()
	samples.resize(count)
	for i in count:
		var t := float(i) / float(rate)
		var env := sin(PI * t / dur)
		var f := base * (1.0 + 0.35 * sin(TAU * 4.0 * t)) * (1.0 - 0.25 * t / dur)
		var s := sin(TAU * f * t) * 0.7 + sin(TAU * f * 2.0 * t) * 0.2
		s += randf_range(-0.15, 0.15)
		samples[i] = s * env * 0.55
	return _pcm(samples, rate)

func _loop_bed() -> AudioStreamWAV:
	var rate := 22050
	var dur := 4.0
	var count := int(rate * dur)
	var notes: Array[float] = [262.0, 330.0, 392.0, 494.0]
	var samples := PackedFloat32Array()
	samples.resize(count)
	for i in count:
		var t := float(i) / float(rate)
		var idx := int(t) % notes.size()
		var f: float = notes[idx]
		var env := 0.5 + 0.5 * sin(TAU * t * 0.5)
		var s := sin(TAU * f * t) * 0.22 + sin(TAU * f * 2.0 * t) * 0.05
		samples[i] = s * (0.35 + env * 0.15)
	var stream := _pcm(samples, rate)
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = count
	return stream
