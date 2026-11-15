extends RefCounted
## Sons gerados por código (sem arquivos de áudio): mar, respingo e sininho.

const RATE := 22050


static func _wav(samples: PackedFloat32Array, loop: bool) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = bytes
	if loop:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = samples.size()
	return wav


## Ondas quebrando: ruído filtrado com o volume subindo e descendo devagar.
static func ocean(seconds := 8.0) -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var n := int(seconds * RATE)
	var fade := RATE
	var raw := PackedFloat32Array()
	raw.resize(n + fade)
	var low := 0.0
	var lower := 0.0
	for i in n + fade:
		var white := rng.randf() * 2.0 - 1.0
		low += (white - low) * 0.12
		lower += (white - lower) * 0.02
		raw[i] = low * 0.55 + lower * 1.6
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var s := raw[i]
		if i < fade:
			var a := float(i) / fade
			s = s * a + raw[n + i] * (1.0 - a)
		var t := float(i) / n
		var swell := 0.45 + 0.4 * pow(0.5 + 0.5 * sin(t * TAU - 1.0), 2.0) + 0.15 * sin(t * TAU * 2.0 + 0.7)
		out[i] = s * swell * 0.9
	return _wav(out, true)


static func splash() -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	var n := int(0.7 * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var low := 0.0
	for i in n:
		var t := float(i) / n
		var white := rng.randf() * 2.0 - 1.0
		low += (white - low) * lerpf(0.5, 0.08, t)
		out[i] = low * pow(1.0 - t, 2.0) * minf(t * 60.0, 1.0) * 0.9
	return _wav(out, false)


## Passo na areia: um chiado curto e abafado.
static func step() -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var n := int(0.16 * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var low := 0.0
	for i in n:
		var t := float(i) / n
		low += (rng.randf() * 2.0 - 1.0 - low) * 0.3
		out[i] = low * pow(1.0 - t, 3.0) * minf(t * 25.0, 1.0)
	return _wav(out, false)


static func chime() -> AudioStreamWAV:
	var n := int(0.9 * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var notes := [880.0, 1318.5, 1760.0]
	for i in n:
		var t := float(i) / RATE
		var s := 0.0
		for k in notes.size():
			var start := k * 0.09
			if t >= start:
				var lt := t - start
				s += sin(lt * TAU * notes[k]) * exp(-lt * 6.0) * 0.28
		out[i] = s
	return _wav(out, false)
