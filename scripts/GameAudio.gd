extends Node
## Small synthesized sound bank. No external downloads or audio dependencies.
var bank: Dictionary = {}
var voices: Array[AudioStreamPlayer] = []
var last_play: Dictionary = {}
var volume := 0.65
var muted := false

func _ready() -> void:
	for kind in ["stretch", "launch", "wood", "glass", "stone", "pig", "boom", "win", "click", "chicken"]:
		bank[kind] = _synthesize(kind)
	for i in 12:
		var voice := AudioStreamPlayer.new()
		add_child(voice)
		voices.append(voice)

func play(kind: String, strength := 1.0) -> void:
	if muted or volume <= 0.0 or not bank.has(kind): return
	var now := Time.get_ticks_msec()
	if now - int(last_play.get(kind, -1000)) < 65: return
	last_play[kind] = now
	for voice in voices:
		if not voice.playing:
			voice.stream = bank[kind]
			voice.pitch_scale = randf_range(0.93, 1.07)
			voice.volume_db = linear_to_db(volume * clampf(strength, 0.15, 1.0)) - 7.0
			voice.play()
			return

func _synthesize(kind: String) -> AudioStreamWAV:
	var duration: float = {"stretch":0.18, "launch":0.32, "wood":0.22, "glass":0.48, "stone":0.26, "pig":0.22, "boom":0.75, "win":0.8, "click":0.06, "chicken":0.28}[kind]
	var rate := 22050
	var bytes := PackedByteArray()
	bytes.resize(int(rate * duration) * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7921
	var low := 0.0
	for i in bytes.size() / 2:
		var t := float(i) / rate
		var u := t / duration
		var noise := rng.randf_range(-1.0, 1.0)
		low = lerpf(low, noise, 0.12)
		var sample := 0.0
		match kind:
			"stretch": sample = sin(TAU * (170.0 * t + 160.0 * t * t)) * 0.5
			"launch": sample = sin(TAU * (800.0 * t - 1000.0 * t * t)) * 0.35 + noise * 0.12
			"wood": sample = (sin(TAU * 180.0 * t) * 0.5 + noise * 0.5) * exp(-t * 18.0)
			"glass": sample = (sin(TAU * 2300.0 * t) + sin(TAU * 3171.0 * t) * 0.6 + noise * 0.6) * 0.35 * exp(-t * 9.0)
			"stone": sample = (low * 2.0 + sin(TAU * 85.0 * t) * 0.5) * exp(-t * 16.0)
			"pig": sample = sin(TAU * (480.0 * t - 600.0 * t * t)) * 0.65
			"boom": sample = (low * 2.4 + sin(TAU * (65.0 * t - 25.0 * t * t)) * 0.5) * exp(-t * 6.0)
			"win":
				var note: float = [523.25, 659.25, 783.99, 1046.5][mini(3, int(t / 0.2))]
				sample = sin(TAU * note * t) * 0.45 * sin(PI * fmod(t, 0.2) / 0.2)
			"chicken": sample = sin(TAU * (520.0*t + 12.0*sin(t*35.0))) * 0.45 * maxf(0.0,sin(t*55.0))
			"click": sample = sin(TAU * 850.0 * t) * 0.3
		sample *= minf(1.0, t * 600.0) * pow(1.0 - u, 1.4)
		bytes.encode_s16(i * 2, int(clampf(sample, -1.0, 1.0) * 26000.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.data = bytes
	return stream
