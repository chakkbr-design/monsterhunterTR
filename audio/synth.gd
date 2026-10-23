extends RefCounted
## Síntese chiptune em código (tudo original): osciladores, efeitos (SFX) e um pequeno sequenciador de música.
## Só funções estáticas e dados; o autoload Audio (audio.gd) usa isto. Testável sem árvore de cena.

const RATE := 22050

const SFX_NAMES := ["ui_move", "ui_confirm", "ui_back", "hit", "hit_super", "hit_weak", "crit", "faint",
	"ball_throw", "ball_shake", "catch_ok", "catch_fail", "level_up", "heal", "door", "step_grass",
	"encounter", "item_get", "evolution", "run_away"]

const NOTE_SEMI := {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}


# --- Utilidades ---

static func midi_hz(m: float) -> float:
	return 440.0 * pow(2.0, (m - 69.0) / 12.0)


## "C5", "F#4", "Bb3" -> número MIDI. -1 se inválido.
static func note_midi(s: String) -> int:
	if s.length() < 2 or not NOTE_SEMI.has(s[0]):
		return -1
	var semi: int = NOTE_SEMI[s[0]]
	var i := 1
	if s[i] == "#":
		semi += 1
		i += 1
	elif s[i] == "b":
		semi -= 1
		i += 1
	var oct := s.substr(i)
	if not oct.is_valid_int():
		return -1
	return 12 * (int(oct) + 1) + semi


## "Am" -> [raiz MIDI na oitava 0..11, intervalos].
static func chord(s: String) -> Array:
	var root: int = NOTE_SEMI.get(s[0], 0)
	var rest := s.substr(1)
	if rest.begins_with("#"):
		root += 1
		rest = rest.substr(1)
	elif rest.begins_with("b"):
		root -= 1
		rest = rest.substr(1)
	var iv := [0, 3, 7] if rest.begins_with("m") else [0, 4, 7]
	return [posmod(root, 12), iv]


static func to_wav(buf: PackedFloat32Array, loop: bool) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(buf.size() * 2)
	for i in buf.size():
		bytes.encode_s16(i * 2, int(clampf(buf[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = bytes
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = buf.size()
	return w


## Soma uma nota no buffer. o: {wave: "square"|"triangle"|"noise"|"saw", f0, f1 (glissando), duty, vol,
## a, d, s, r (envelope ADSR em segundos / nível), vib (Hz), vib_depth (semitons), seed}.
static func voice(buf: PackedFloat32Array, start: float, dur: float, o: Dictionary) -> void:
	var wave: int = ["square", "triangle", "noise", "saw"].find(String(o.get("wave", "square")))
	var f0: float = o.get("f0", 440.0)
	var f1: float = o.get("f1", f0)
	var duty: float = o.get("duty", 0.5)
	var vol: float = o.get("vol", 0.3)
	var a: float = maxf(o.get("a", 0.004), 0.0005)
	var d: float = o.get("d", 0.05)
	var s: float = o.get("s", 0.7)
	var r: float = maxf(o.get("r", 0.03), 0.001)
	var vib: float = o.get("vib", 0.0)
	var vib_depth: float = o.get("vib_depth", 0.0)
	var i0 := int(start * RATE)
	var n := int(dur * RATE)
	var rn := int(r * RATE)
	var total := n + rn
	if i0 >= buf.size():
		return
	total = mini(total, buf.size() - i0)
	var phase := 0.0
	var lfsr: int = int(o.get("seed", 1)) | 1
	var held := 0.0
	var inv := 1.0 / RATE
	var ratio := f1 / f0
	for k in total:
		var t := k * inv
		var p := minf(float(k) / float(maxi(n, 1)), 1.0)
		var f := f0 * pow(ratio, p) if ratio != 1.0 else f0
		if vib > 0.0:
			f *= pow(2.0, vib_depth * sin(TAU * vib * t) / 12.0)
		var env: float
		if t < a:
			env = t / a
		elif t < a + d:
			env = 1.0 - (1.0 - s) * (t - a) / d
		else:
			env = s
		if k >= n:
			env *= 1.0 - float(k - n) / float(rn)
		var old := phase
		phase += f * inv
		var x: float
		if wave == 1:
			x = 4.0 * absf(fmod(phase, 1.0) - 0.5) - 1.0
		elif wave == 2:
			# Ruído "período" estilo console: troca de valor numa taxa f (mais alta = mais claro).
			if int(phase) != int(old):
				lfsr = (lfsr * 1103515245 + 12345) & 0x7fffffff
				held = float((lfsr >> 16) & 0x7fff) / 16383.5 - 1.0
			x = held
		elif wave == 3:
			x = 2.0 * fmod(phase, 1.0) - 1.0
		else:
			x = 1.0 if fmod(phase, 1.0) < duty else -1.0
		buf[i0 + k] += x * env * vol


static func _buf(secs: float) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(secs * RATE))
	return b


## Sequência de notas curtas (arpejo) a partir de `at`, cada uma com `step` segundos.
static func _arp(b: PackedFloat32Array, at: float, notes: Array, step: float, o: Dictionary, hold_last := 0.0) -> void:
	for i in notes.size():
		var oo := o.duplicate()
		oo.f0 = midi_hz(note_midi(notes[i]))
		oo.erase("f1")
		var dur := step + (hold_last if i == notes.size() - 1 else 0.0)
		voice(b, at + i * step, dur, oo)


# --- Efeitos ---

static func make_sfx(sfx_name: String) -> AudioStreamWAV:
	var b: PackedFloat32Array
	match sfx_name:
		"ui_move":
			b = _buf(0.06)
			voice(b, 0, 0.025, {"f0": 1320.0, "duty": 0.25, "vol": 0.18, "r": 0.015})
		"ui_confirm":
			b = _buf(0.14)
			_arp(b, 0, ["E6", "B6"], 0.045, {"duty": 0.25, "vol": 0.2, "r": 0.03})
		"ui_back":
			b = _buf(0.14)
			_arp(b, 0, ["G5", "D5"], 0.045, {"duty": 0.5, "vol": 0.18, "r": 0.03})
		"hit":
			b = _buf(0.2)
			voice(b, 0, 0.09, {"wave": "noise", "f0": 6000.0, "f1": 1500.0, "vol": 0.4, "d": 0.08, "s": 0.2, "r": 0.06})
			voice(b, 0, 0.08, {"f0": 320.0, "f1": 90.0, "duty": 0.5, "vol": 0.25, "r": 0.03})
		"hit_super":
			b = _buf(0.34)
			voice(b, 0, 0.14, {"wave": "noise", "f0": 9000.0, "f1": 1200.0, "vol": 0.5, "d": 0.12, "s": 0.3, "r": 0.08})
			voice(b, 0, 0.12, {"f0": 700.0, "f1": 110.0, "duty": 0.5, "vol": 0.3, "r": 0.04})
			voice(b, 0.12, 0.1, {"wave": "noise", "f0": 3000.0, "f1": 800.0, "vol": 0.35, "r": 0.08})
		"hit_weak":
			b = _buf(0.14)
			voice(b, 0, 0.06, {"wave": "noise", "f0": 2000.0, "vol": 0.2, "d": 0.05, "s": 0.2, "r": 0.04})
			voice(b, 0, 0.07, {"wave": "triangle", "f0": 220.0, "f1": 140.0, "vol": 0.35, "r": 0.03})
		"crit":
			b = _buf(0.32)
			voice(b, 0, 0.08, {"f0": 1800.0, "f1": 500.0, "duty": 0.25, "vol": 0.25, "r": 0.02})
			voice(b, 0.06, 0.14, {"wave": "noise", "f0": 10000.0, "f1": 2000.0, "vol": 0.45, "d": 0.1, "s": 0.3, "r": 0.08})
			voice(b, 0.06, 0.12, {"f0": 400.0, "f1": 70.0, "duty": 0.5, "vol": 0.25, "r": 0.04})
		"faint":
			b = _buf(0.95)
			voice(b, 0, 0.8, {"f0": 620.0, "f1": 55.0, "duty": 0.5, "vol": 0.25, "vib": 9.0, "vib_depth": 0.6, "s": 0.9, "r": 0.1})
		"ball_throw":
			b = _buf(0.36)
			voice(b, 0, 0.3, {"wave": "noise", "f0": 1500.0, "f1": 7000.0, "vol": 0.18, "a": 0.15, "d": 0.1, "s": 0.4, "r": 0.05})
			voice(b, 0, 0.25, {"f0": 300.0, "f1": 1100.0, "duty": 0.125, "vol": 0.12, "r": 0.04})
		"ball_shake":
			b = _buf(0.2)
			for k in 2:
				voice(b, k * 0.08, 0.025, {"wave": "noise", "f0": 4000.0, "vol": 0.3, "r": 0.02, "seed": 7 + k})
				voice(b, k * 0.08, 0.04, {"wave": "triangle", "f0": 190.0, "f1": 150.0, "vol": 0.4, "r": 0.02})
		"catch_ok":
			b = _buf(1.0)
			_arp(b, 0, ["C6", "G5", "C6", "E6", "G6"], 0.08, {"duty": 0.5, "vol": 0.2, "r": 0.04}, 0.4)
			_arp(b, 0, ["C4", "C4", "E4", "G4", "C5"], 0.08, {"wave": "triangle", "vol": 0.3, "r": 0.04}, 0.4)
		"catch_fail":
			b = _buf(0.45)
			voice(b, 0, 0.05, {"wave": "noise", "f0": 8000.0, "vol": 0.4, "r": 0.04})
			voice(b, 0.05, 0.3, {"f0": 880.0, "f1": 180.0, "duty": 0.25, "vol": 0.2, "r": 0.06})
		"level_up":
			b = _buf(0.8)
			_arp(b, 0, ["D5", "A5", "D6", "F#6", "A6"], 0.06, {"duty": 0.25, "vol": 0.2, "r": 0.04}, 0.3)
			_arp(b, 0.03, ["D5", "A5", "D6", "F#6", "A6"], 0.06, {"duty": 0.5, "vol": 0.08, "r": 0.04}, 0.3)
		"heal":
			b = _buf(1.3)
			_arp(b, 0, ["E5", "G#5", "B5", "E6", "G#6", "B6"], 0.12, {"wave": "triangle", "vol": 0.35, "r": 0.15}, 0.4)
			_arp(b, 0.06, ["E5", "G#5", "B5", "E6", "G#6", "B6"], 0.12, {"duty": 0.125, "vol": 0.08, "r": 0.15}, 0.4)
		"door":
			b = _buf(0.3)
			voice(b, 0, 0.12, {"wave": "noise", "f0": 900.0, "f1": 300.0, "vol": 0.25, "d": 0.1, "s": 0.3, "r": 0.08})
			voice(b, 0, 0.15, {"wave": "triangle", "f0": 130.0, "f1": 70.0, "vol": 0.4, "r": 0.06})
		"step_grass":
			b = _buf(0.1)
			voice(b, 0, 0.04, {"wave": "noise", "f0": 5000.0, "f1": 2500.0, "vol": 0.12, "d": 0.03, "s": 0.3, "r": 0.04})
		"encounter":
			b = _buf(0.9)
			for k in 12:
				var hz := 1400.0 - k * 70.0 if k % 2 == 0 else 900.0 - k * 45.0
				voice(b, k * 0.06, 0.05, {"f0": hz, "duty": 0.25, "vol": 0.18, "r": 0.01})
			voice(b, 0.72, 0.1, {"wave": "noise", "f0": 3000.0, "f1": 500.0, "vol": 0.25, "r": 0.06})
		"item_get":
			b = _buf(1.1)
			_arp(b, 0, ["G5", "G5", "G5", "C6"], 0.11, {"duty": 0.5, "vol": 0.18, "r": 0.04}, 0.45)
			_arp(b, 0, ["E5", "E5", "F5", "E5"], 0.11, {"duty": 0.25, "vol": 0.1, "r": 0.04}, 0.45)
			_arp(b, 0, ["C4", "C4", "D4", "C4"], 0.11, {"wave": "triangle", "vol": 0.3, "r": 0.04}, 0.45)
		"evolution":
			b = _buf(2.2)
			voice(b, 0, 1.4, {"f0": 180.0, "f1": 1600.0, "duty": 0.25, "vol": 0.15, "vib": 7.0, "vib_depth": 0.8, "s": 1.0, "r": 0.05})
			voice(b, 0, 1.4, {"wave": "triangle", "f0": 90.0, "f1": 400.0, "vol": 0.25, "s": 1.0, "r": 0.05})
			for nt in ["C5", "E5", "G5", "C6"]:
				voice(b, 1.45, 0.5, {"f0": midi_hz(note_midi(nt)), "duty": 0.5, "vol": 0.1, "s": 0.8, "r": 0.2})
		"run_away":
			b = _buf(0.5)
			_arp(b, 0, ["A5", "F5", "D5", "A4"], 0.06, {"duty": 0.25, "vol": 0.18, "r": 0.02})
			voice(b, 0.15, 0.25, {"wave": "noise", "f0": 6000.0, "f1": 1000.0, "vol": 0.15, "a": 0.05, "r": 0.06})
		_:
			return null
	return to_wav(b, false)


# --- Música ---
## Cada faixa: bpm, acordes (um por compasso), melodia (16 passos de semicolcheia por compasso, separados por |;
## "." segura a nota anterior, "-" pausa), e padrões de 16 passos para baixo (x raiz, o quinta, 8 oitava),
## arpejo (a = próxima nota do acorde) e bateria (k bumbo, s caixa, h chimbal). Composições originais.

const TRACKS := {
	"title": {"bpm": 116, "lead_duty": 0.5, "chords": ["C", "G", "Am", "F", "C", "G", "F", "G"],
		"melody": "C5 . . . E5 . G5 . C6 . . . B5 . G5 . | D5 . . . G5 . B5 . D6 . . . C6 . B5 . | A5 . . . E5 . A5 . C6 . . . B5 . A5 . | F5 . . . A5 . C6 . A5 . G5 . F5 . E5 . | E5 . G5 . C6 . . . E6 . D6 . C6 . G5 . | B5 . . . D6 . . . G5 . . . - . G5 . | A5 . C6 . F6 . . . E6 . D6 . C6 . A5 . | B5 . . . . . . . D6 . . . . . - .",
		"bass": "x...x.o.x...o.x.", "arp": "a.a.a.a.a.a.a.a.", "drums": "k...h...s...h.k."},
	"town": {"bpm": 96, "lead_duty": 0.25, "chords": ["F", "C", "Dm", "Bb", "F", "C", "Bb", "C"],
		"melody": "A4 . C5 . F5 . . . E5 . F5 . G5 . . . | E5 . . . C5 . . . G4 . . . - . C5 . | D5 . F5 . A5 . . . G5 . F5 . D5 . . . | F5 . . . . . D5 . Bb4 . . . - . . . | C5 . F5 . A5 . . . C6 . A5 . F5 . . . | G5 . . . E5 . C5 . E5 . G5 . C6 . . . | Bb5 . . . A5 . . . G5 . . . F5 . D5 . | E5 . . . . . . . C5 . . . - . . .",
		"bass": "x...o...x...o...", "arp": "a.a.a.a.a.a.a.a.", "drums": "k...h...s...h..."},
	"route": {"bpm": 136, "lead_duty": 0.5, "chords": ["D", "G", "A", "D", "Bm", "G", "A", "A"],
		"melody": "F#5 . A5 . D6 . A5 . F#5 . A5 . B5 . A5 . | G5 . B5 . D6 . B5 . G5 . . . E5 . . . | E5 . A5 . C#6 . . . E6 . C#6 . A5 . . . | D6 . . . A5 . F#5 . D5 . . . - . A4 . | B4 . D5 . F#5 . . . B5 . A5 . F#5 . D5 . | G5 . . . B5 . . . D6 . . . B5 . G5 . | A5 . . . C#6 . E6 . A6 . . . G6 . E6 . | C#6 . . . . . . . A5 . . . - . . .",
		"bass": "x.x.o.o.x.x.o.8.", "arp": "a.a.a.a.a.a.a.a.", "drums": "k.h.s.h.k.k.s.h."},
	"forest": {"bpm": 92, "lead_duty": 0.125, "chords": ["Am", "F", "Em", "Am", "Dm", "F", "E", "E"],
		"melody": "A4 . . . . . C5 . E5 . . . D5 . C5 . | C5 . . . A4 . . . F4 . . . - . . . | G4 . . . B4 . . . E5 . . . D5 . B4 . | A4 . . . . . . . - . . . E4 . A4 . | D5 . . . F5 . . . A5 . . . G5 . F5 . | E5 . . . C5 . . . A4 . . . C5 . . . | B4 . . . G#4 . . . E4 . . . G#4 . B4 . | E5 . . . . . . . . . . . - . . .",
		"bass": "x.......o.......", "arp": "a.a.a.a.a.a.a.a.", "drums": "....h.......h..."},
	"battle_wild": {"bpm": 156, "lead_duty": 0.5, "chords": ["Em", "C", "D", "B", "Em", "C", "Am", "B"],
		"melody": "E5 . G5 . B5 . E6 . D6 . B5 . G5 . B5 . | C6 . . . G5 . E5 . C6 . D6 . E6 . . . | D6 . . . A5 . F#5 . D6 . E6 . F#6 . . . | D#6 . . . B5 . . . F#5 . . . B5 . D#6 . | E6 . . . B5 . G5 . E5 . G5 . B5 . E6 . | G6 . . . E6 . C6 . G5 . . . C6 . E6 . | A6 . . . E6 . C6 . A5 . C6 . E6 . A6 . | F#6 . . . D#6 . . . B5 . . . F#5 . . .",
		"bass": "x.x.x.o.x.x.8.o.", "arp": "aaaaaaaaaaaaaaaa", "drums": "k.hhs.hhk.hhs.hs"},
	"battle_trainer": {"bpm": 168, "lead_duty": 0.25, "chords": ["Am", "Dm", "E", "Am", "F", "G", "E", "E"],
		"melody": "A5 . . . C6 . E6 . A6 . G6 . E6 . C6 . | D6 . . . F6 . . . A6 . F6 . D6 . . . | B5 . . . E6 . G#6 . B6 . . . G#6 . E6 . | A6 . . . E6 . C6 . A5 . . . - . E5 . | F5 . A5 . C6 . F6 . E6 . C6 . A5 . C6 . | D6 . . . B5 . G5 . D6 . E6 . F6 . G6 . | G#6 . . . . . E6 . B5 . . . E6 . G#6 . | B6 . . . . . . . E6 . . . - . . .",
		"bass": "x.x.8.x.x.x.8.o.", "arp": "aaaaaaaaaaaaaaaa", "drums": "k.hsk.hsk.hsk.ss"},
	"victory": {"bpm": 132, "lead_duty": 0.5, "chords": ["C", "F", "G", "C"],
		"melody": "C5 . E5 . G5 . C6 . . . G5 . C6 . E6 . | F6 . . . C6 . A5 . F5 . A5 . C6 . . . | D6 . . . B5 . G5 . D6 . E6 . F6 . D6 . | E6 . . . . . C6 . . . . . - . . .",
		"bass": "x...x.o.x...o.x.", "arp": "a.a.a.a.a.a.a.a.", "drums": "k.h.s.h.k.h.s.h."},
	"center": {"bpm": 104, "lead_duty": 0.25, "chords": ["G", "Em", "C", "D", "G", "Em", "Am", "D"],
		"melody": "B4 . D5 . G5 . . . F#5 . G5 . A5 . . . | G5 . . . E5 . . . B4 . . . - . . . | C5 . E5 . G5 . . . A5 . G5 . E5 . . . | F#5 . . . . . A5 . D5 . . . - . . . | D5 . G5 . B5 . . . D6 . B5 . G5 . . . | E5 . G5 . B5 . . . G5 . . . E5 . . . | C5 . E5 . A5 . . . C6 . A5 . E5 . . . | D5 . F#5 . A5 . . . F#5 . . . - . . .",
		"bass": "x...o...x...o...", "arp": "a.a.a.a.a.a.a.a.", "drums": "k...h...s...h.h."},
	"lab": {"bpm": 112, "lead_duty": 0.5, "chords": ["Bb", "Gm", "Eb", "F", "Bb", "Gm", "Cm", "F"],
		"melody": "D5 . F5 . Bb5 . . . A5 . Bb5 . C6 . . . | D6 . . . Bb5 . G5 . D5 . . . G5 . . . | G5 . . . Eb5 . . . Bb4 . Eb5 . G5 . Bb5 . | A5 . . . . . F5 . C5 . . . - . . . | F5 . Bb5 . D6 . . . C6 . Bb5 . A5 . Bb5 . | G5 . . . D5 . . . Bb4 . D5 . G5 . . . | Eb5 . G5 . C6 . . . Bb5 . G5 . Eb5 . C5 . | F5 . . . . . A5 . C6 . . . - . . .",
		"bass": "x.....o.x.....o.", "arp": "a.a.a.a.a.a.a.a.", "drums": "k...h.h.s...h..."},
	"gym": {"bpm": 124, "lead_duty": 0.25, "chords": ["Dm", "Bb", "C", "A", "Dm", "Bb", "Gm", "A"],
		"melody": "D5 . . . F5 . A5 . D6 . . . C6 . A5 . | Bb5 . . . F5 . D5 . Bb4 . . . D5 . F5 . | E5 . . . G5 . C6 . E6 . . . D6 . C6 . | C#6 . . . A5 . . . E5 . . . A5 . C#6 . | D6 . . . A5 . F5 . D5 . F5 . A5 . D6 . | F6 . . . D6 . Bb5 . F5 . . . Bb5 . D6 . | G6 . . . D6 . Bb5 . G5 . Bb5 . D6 . G6 . | E6 . . . C#6 . . . A5 . . . - . . .",
		"bass": "x.x.o.x.x.x.o.x.", "arp": "a.a.a.a.a.a.a.a.", "drums": "k.h.s.h.k.k.s.h."},
}


static func step_secs(spec: Dictionary) -> float:
	return 60.0 / float(spec.bpm) / 4.0


static func track_steps(spec: Dictionary) -> int:
	return spec.chords.size() * 16


static func track_secs(spec: Dictionary) -> float:
	return track_steps(spec) * step_secs(spec)


## Tokens da melodia (sem as barras de compasso).
static func melody_tokens(spec: Dictionary) -> PackedStringArray:
	var out := PackedStringArray()
	for t in String(spec.melody).replace("|", " ").split(" ", false):
		out.append(t)
	return out


static func render_track(track_name: String) -> AudioStreamWAV:
	var spec: Dictionary = TRACKS.get(track_name, {})
	if spec.is_empty():
		return null
	var st := step_secs(spec)
	var steps := track_steps(spec)
	var b := PackedFloat32Array()
	b.resize(int(round(steps * st * RATE)))
	# Melodia
	var toks := melody_tokens(spec)
	var i := 0
	while i < mini(toks.size(), steps):
		var m := note_midi(toks[i])
		var j := i + 1
		while j < toks.size() and toks[j] == ".":
			j += 1
		if m >= 0:
			var nl := (j - i) * st
			voice(b, i * st, nl - 0.02, {"f0": midi_hz(m), "duty": spec.get("lead_duty", 0.5), "vol": 0.13,
				"d": 0.08, "s": 0.65, "r": 0.02, "vib": 5.5 if nl > 0.3 else 0.0, "vib_depth": 0.15})
		i = j
	# Acompanhamento por compasso
	var bass: String = spec.bass
	var arp: String = spec.arp
	var drums: String = spec.drums
	for bar in spec.chords.size():
		var c := chord(spec.chords[bar])
		var root: int = c[0]
		var iv: Array = c[1]
		var bass_root := 36 + root if root < 8 else 24 + root
		var t0: float = bar * 16 * st
		var ai := 0
		for k in 16:
			var bc := bass[k]
			if bc in "xo8":
				var bm := bass_root + (7 if bc == "o" else (12 if bc == "8" else 0))
				var bl := 1
				while k + bl < 16 and bass[k + bl] == ".":
					bl += 1
				voice(b, t0 + k * st, bl * st - 0.01, {"wave": "triangle", "f0": midi_hz(bm), "vol": 0.32, "d": 0.05, "s": 0.8, "r": 0.01})
			if arp[k] == "a":
				var tones := [iv[0], iv[1], iv[2], 12 + iv[0], iv[2], iv[1]]
				var am: int = 60 + root + int(tones[ai % tones.size()])
				ai += 1
				voice(b, t0 + k * st, st * 0.8, {"f0": midi_hz(am), "duty": 0.125, "vol": 0.05, "d": 0.03, "s": 0.5, "r": 0.01})
			match drums[k]:
				"k":
					voice(b, t0 + k * st, 0.05, {"wave": "triangle", "f0": 150.0, "f1": 45.0, "vol": 0.4, "s": 0.6, "r": 0.02})
				"s":
					voice(b, t0 + k * st, 0.06, {"wave": "noise", "f0": 6000.0, "vol": 0.16, "d": 0.05, "s": 0.2, "r": 0.03, "seed": bar * 16 + k})
				"h":
					voice(b, t0 + k * st, 0.015, {"wave": "noise", "f0": 11000.0, "vol": 0.06, "r": 0.01, "seed": bar * 16 + k + 3})
	return to_wav(b, true)
