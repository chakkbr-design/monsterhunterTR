class_name WeatherAudio
extends Node
## Weather ambience made in code like the rest of the game's sound (audio/synth.gd), no files:
## - rain: a light layer (hiss and close droplet ticks) and a heavy roar, mixed by intensity;
## - indoors the same rain heard through a roof: a muffled low rumble with soft taps (the outdoor
##   layers fade out, so walking through a door muffles the rain);
## - wind: a slow whooshing loop that follows the storm wind and its gusts;
## - thunder: a close crack with a long rumble, or a distant roll, played by thunder(distance,
##   power) when the lightning's sound arrives (WeatherLightning.thunder), muffled indoors.
## The loops are 4-8 s, rendered once per session on a worker thread (headless: on demand, in
## place) with a crossfaded seam, so they loop without clicks. Volume follows the game's sound
## volume (Audio.sfx_vol).

const RATE := 22050
const BASE_DB := -7.0
const FADE := 0.6  ## gain units per second
const THUNDER_VOICES := 2

static var _streams := {}
static var _task := -1
static var _ready_flag := false
static var _mutex := Mutex.new()

var rain := 0.0  ## 0..1 falling rain
var wind := 0.0  ## extra wind (0 calm .. ~1.5 storm)
var gust := 0.0  ## 0..1
var indoor := false
var thunders := 0  ## thunder sounds played (tests)

var _loops := {}  ## name -> AudioStreamPlayer
var _gain := {}  ## name -> current gain 0..1
var _voices: Array[AudioStreamPlayer] = []
var _next_voice := 0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	for n in ["rain", "rain_heavy", "roof", "wind"]:
		var p := AudioStreamPlayer.new()
		p.name = n.capitalize().replace(" ", "")
		p.volume_db = -80.0
		add_child(p)
		_loops[n] = p
		_gain[n] = 0.0
	for i in THUNDER_VOICES:
		var p := AudioStreamPlayer.new()
		p.name = "Thunder%d" % i
		add_child(p)
		_voices.append(p)


func _exit_tree() -> void:
	if _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1


## True once the loops exist (rendered on first need).
static func streams_ready() -> bool:
	_mutex.lock()
	var r := _ready_flag
	_mutex.unlock()
	return r


static func _ensure_streams() -> void:
	if streams_ready() or _task >= 0:
		return
	if DisplayServer.get_name() == "headless":
		_render_all()
	else:
		_task = WorkerThreadPool.add_task(_render_all)


static func _render_all() -> void:
	var s := {
		"rain": _loop(_rain_light, 4.0),
		"rain_heavy": _loop(_rain_heavy, 4.0),
		"roof": _loop(_rain_roof, 4.0),
		"wind": _loop(_wind_loop, 8.0),
		"thunder_near": _wav(_thunder(true, 11), false),
		"thunder_far": _wav(_thunder(false, 23), false),
		"thunder_far2": _wav(_thunder(false, 37), false),
	}
	_mutex.lock()
	_streams = s
	_ready_flag = true
	_mutex.unlock()


func _vol() -> float:
	var a := get_node_or_null("/root/Audio")
	return float(a.get("sfx_vol")) if a and a.get("sfx_vol") != null else 1.0


func _process(delta: float) -> void:
	var want := {
		"rain":
		0.0 if indoor else smoothstep(0.0, 0.3, rain) * (1.0 - 0.45 * smoothstep(0.5, 1.0, rain)),
		"rain_heavy": 0.0 if indoor else smoothstep(0.4, 1.0, rain),
		"roof": smoothstep(0.0, 0.4, rain) * 0.85 if indoor else 0.0,
		"wind": smoothstep(0.15, 1.3, wind) * (0.55 + 0.45 * gust) * (0.35 if indoor else 1.0),
	}
	var any := false
	for n in want:
		any = any or float(want[n]) > 0.001 or float(_gain[n]) > 0.001
	if not any:
		return
	_ensure_streams()
	if not streams_ready():
		return
	var master := _vol()
	for n in want:
		var g := move_toward(float(_gain[n]), float(want[n]), delta * FADE)
		_gain[n] = g
		var p: AudioStreamPlayer = _loops[n]
		if g > 0.001 and master > 0.0:
			if p.stream == null:
				p.stream = _streams[n]
			p.volume_db = BASE_DB + linear_to_db(g * master)
			if not p.playing:
				p.play(_rng.randf() * 2.0)
		elif p.playing:
			p.stop()


## A thunder clap `distance` m away (power 0..1): close ones crack, far ones roll.
func thunder(distance: float, power: float) -> void:
	thunders += 1
	_ensure_streams()
	if not streams_ready():
		return
	var master := _vol()
	if master <= 0.0:
		return
	var key := (
		"thunder_near"
		if distance < 35.0
		else ("thunder_far" if _rng.randf() < 0.5 else "thunder_far2")
	)
	var p := _voices[_next_voice]
	_next_voice = (_next_voice + 1) % _voices.size()
	p.stream = _streams[key]
	p.pitch_scale = _rng.randf_range(0.85, 1.08) * (0.8 if indoor else 1.0)
	var db := BASE_DB + 4.0 + linear_to_db(clampf(power, 0.05, 1.0) * master)
	p.volume_db = db - (7.0 if indoor else 0.0)
	p.play()


func gain(n: String) -> float:
	return float(_gain.get(n, 0.0))


# --- Synthesis (mono float buffers at RATE) ---


static func _wav(buf: PackedFloat32Array, loop: bool) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(buf.size() * 2)
	for i in buf.size():
		data.encode_s16(i * 2, int(clampf(buf[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = buf.size()
	return w


## Renders `secs` (+ a crossfade tail folded onto the head) with `gen`, normalized, as a loop.
static func _loop(gen: Callable, secs: float) -> AudioStreamWAV:
	var n := int(secs * RATE)
	var fade := int(0.35 * RATE)
	var raw: PackedFloat32Array = gen.call(n + fade)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		out[i] = raw[i]
	for i in fade:
		var w := float(i) / fade
		out[i] = raw[i] * sin(w * PI * 0.5) + raw[n + i] * cos(w * PI * 0.5)
	_normalize(out, 0.8)
	return _wav(out, true)


static func _normalize(b: PackedFloat32Array, peak: float) -> void:
	var m := 0.0001
	for v in b:
		m = maxf(m, absf(v))
	var k := peak / m
	for i in b.size():
		b[i] *= k


static func _coef(fc: float) -> float:
	return 1.0 - exp(-TAU * fc / RATE)


## Droplet ticks: `rate` per second, each a short bright noise burst (`bright` Hz high-pass) or a
## tiny pitched plink, with random loudness.
static func _ticks(
	b: PackedFloat32Array, rng: RandomNumberGenerator, rate: float, amp: float, lp: float
) -> void:
	var n := b.size()
	var count := int(rate * n / RATE)
	var a := _coef(lp)
	for k in count:
		var at := rng.randi_range(0, n - 1)
		var len := rng.randi_range(int(0.002 * RATE), int(0.012 * RATE))
		var g := amp * pow(rng.randf(), 2.2)
		var tone := rng.randf() < 0.2
		var f := rng.randf_range(1400.0, 3800.0)
		var y := 0.0
		for i in len:
			if at + i >= n:
				break
			var e := exp(-float(i) / (len * 0.28))
			var x := rng.randf_range(-1.0, 1.0)
			if tone:
				x = sin(TAU * f * i / RATE)
			y += a * (x - y)
			b[at + i] += y * g * e


static func _rain_light(n: int) -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 101
	var b := PackedFloat32Array()
	b.resize(n)
	var lp := 0.0
	var lp2 := 0.0
	var a1 := _coef(5200.0)
	var a2 := _coef(600.0)
	for i in n:
		var x := rng.randf_range(-1.0, 1.0)
		lp += a1 * (x - lp)
		lp2 += a2 * (lp - lp2)
		b[i] = (lp - lp2) * 0.35
	_ticks(b, rng, 140.0, 0.9, 7000.0)
	return b


static func _rain_heavy(n: int) -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 202
	var b := PackedFloat32Array()
	b.resize(n)
	var l1 := 0.0
	var l2 := 0.0
	var h := 0.0
	var a1 := _coef(1400.0)
	var ah := _coef(4500.0)
	for i in n:
		var x := rng.randf_range(-1.0, 1.0)
		l1 += a1 * (x - l1)
		l2 += a1 * (l1 - l2)
		h += ah * (x - h)
		var swell := 0.85 + 0.15 * sin(TAU * 0.25 * i / RATE + 0.7 * sin(TAU * 0.09 * i / RATE))
		b[i] = (l2 * 1.6 + (h - l1) * 0.3) * swell
	_ticks(b, rng, 380.0, 0.6, 6000.0)
	return b


static func _rain_roof(n: int) -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 303
	var b := PackedFloat32Array()
	b.resize(n)
	var l1 := 0.0
	var l2 := 0.0
	var a := _coef(420.0)
	for i in n:
		var x := rng.randf_range(-1.0, 1.0)
		l1 += a * (x - l1)
		l2 += a * (l1 - l2)
		b[i] = l2 * 2.4
	_ticks(b, rng, 70.0, 1.6, 700.0)
	return b


static func _wind_loop(n: int) -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 404
	var b := PackedFloat32Array()
	b.resize(n)
	var l1 := 0.0
	var l2 := 0.0
	var secs := float(n) / RATE
	for i in n:
		var t := float(i) / RATE
		# Two slow, loop-friendly swells (whole cycles over the loop) move the filter and the level.
		var s := 0.5 + 0.3 * sin(TAU * t * 2.0 / secs) + 0.2 * sin(TAU * t * 5.0 / secs + 1.3)
		var a := _coef(180.0 + 520.0 * s)
		var x := rng.randf_range(-1.0, 1.0)
		l1 += a * (x - l1)
		l2 += a * (l1 - l2)
		b[i] = l2 * (0.35 + 0.65 * s)
	return b


## Thunder: a close one starts with a cracking burst; both roll on in random low bumps.
static func _thunder(near: bool, seed: int) -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var secs := 5.5 if near else 6.5
	var n := int(secs * RATE)
	var b := PackedFloat32Array()
	b.resize(n)
	var bumps: Array = []
	var t := 0.0 if near else rng.randf_range(0.1, 0.4)
	while t < secs - 1.0:
		bumps.append([t, rng.randf_range(0.4, 1.0) * (1.0 - t / secs), rng.randf_range(0.25, 0.9)])
		t += rng.randf_range(0.15, 0.7)
	var l1 := 0.0
	var l2 := 0.0
	var l3 := 0.0
	var a := _coef(150.0 if near else 95.0)
	var ac := _coef(3000.0)
	var c := 0.0
	var env := 0.0
	for i in n:
		var ts := float(i) / RATE
		if i % 32 == 0:  # the rolling envelope is slow: once per 32 samples is plenty
			env = 0.0
			for bp in bumps:
				var d := ts - float(bp[0])
				if d >= 0.0:
					env += float(bp[1]) * (1.0 - exp(-d / 0.04)) * exp(-d / float(bp[2]))
			env *= 1.0 - smoothstep(secs - 1.2, secs, ts)
		var x := rng.randf_range(-1.0, 1.0)
		l1 += a * (x - l1)
		l2 += a * (l1 - l2)
		l3 += a * (l2 - l3)
		var v := l3 * 6.0 * env
		if near and ts < 0.35:
			c += ac * (x - c)
			v += c * 0.9 * exp(-ts / 0.06) + (x - c) * 0.5 * exp(-ts / 0.02)
		b[i] = v
	_normalize(b, 0.9)
	return b
