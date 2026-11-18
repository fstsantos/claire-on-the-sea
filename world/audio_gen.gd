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


## Canto da sereia: glissando de harpa subindo, uma voz sem palavras com
## vibrato ("aaa-aa-aaah") e brilhinhos agudos, com um eco suave por cima.
static func mermaid_song() -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 17
	var seconds := 4.6
	var n := int(seconds * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	# Harpa: pentatônica de dó subindo duas oitavas.
	var harp := [523.25, 587.33, 659.25, 783.99, 880.0, 1046.5, 1174.66, 1318.51, 1567.98, 1760.0, 2093.0]
	for k in harp.size():
		var start := int(k * 0.065 * RATE)
		var f: float = harp[k]
		for i in range(start, mini(start + int(1.8 * RATE), n)):
			var t := float(i - start) / RATE
			var s := sin(TAU * f * t) + 0.35 * sin(TAU * f * 2.0 * t) * exp(-t * 4.0) + 0.12 * sin(TAU * f * 3.0 * t) * exp(-t * 7.0)
			out[i] += s * exp(-t * 2.6) * minf(t * 400.0, 1.0) * 0.16
	# Voz: notas (freq, duração) com deslize entre elas.
	var melody := [[880.0, 0.45], [1046.5, 0.35], [1318.51, 0.5], [1174.66, 0.3], [1318.51, 1.4]]
	var voice_start := 0.75
	var total := 0.0
	for m in melody:
		total += m[1]
	var phase := 0.0
	var freq: float = melody[0][0]
	for i in range(int(voice_start * RATE), mini(int((voice_start + total) * RATE), n)):
		var t := float(i) / RATE - voice_start
		var acc := 0.0
		var target: float = melody[melody.size() - 1][0]
		for m in melody:
			if t < acc + m[1]:
				target = m[0]
				break
			acc += m[1]
		freq += (target - freq) * 0.0025
		var vib := 1.0 + 0.008 * sin(TAU * 5.5 * t) * smoothstep(0.1, 0.6, t)
		phase += TAU * freq * vib / RATE
		var env := smoothstep(0.0, 0.15, t) * (1.0 - smoothstep(total - 0.6, total, t))
		var s := sin(phase) + 0.28 * sin(phase * 2.0) + 0.1 * sin(phase * 3.0) + 0.04 * sin(phase * 4.0)
		out[i] += s * env * 0.2
	# Brilhinhos.
	for k in 26:
		var start := int(rng.randf_range(0.1, 3.6) * RATE)
		var f := rng.randf_range(2600.0, 4800.0)
		for i in range(start, mini(start + int(0.25 * RATE), n)):
			var t := float(i - start) / RATE
			out[i] += sin(TAU * f * t) * exp(-t * 18.0) * 0.05
	# Eco.
	for d in [[0.13, 0.32], [0.29, 0.18], [0.47, 0.1]]:
		var lag := int(d[0] * RATE)
		for i in range(n - 1, lag - 1, -1):
			out[i] += out[i - lag] * d[1]
	var peak := 0.0
	for i in n:
		peak = maxf(peak, absf(out[i]))
	var fade := int(0.3 * RATE)
	for i in n:
		var g := 0.9 / maxf(peak, 0.001)
		if i > n - fade:
			g *= float(n - i) / fade
		out[i] *= g
	return _wav(out, false)
