class_name Sfx
extends Node
## Sound effects synthesized at startup, so the game ships no audio files.
## Usage: sfx.play("jump")

const MIX_RATE := 22050
const VOLUME := 0.22
const VOICES := 8

## Each sound is a list of [start_hz, end_hz, seconds] notes.
const SOUNDS := {
	"jump": [[320.0, 720.0, 0.13]],
	"cog": [[990.0, 990.0, 0.05], [1320.0, 1320.0, 0.12]],
	"stomp": [[280.0, 90.0, 0.13]],
	"thud": [[150.0, 90.0, 0.08]],
	"crate": [[210.0, 60.0, 0.16]],
	"reveal": [[520.0, 780.0, 0.09], [780.0, 1040.0, 0.09]],
	"power": [[392.0, 392.0, 0.07], [523.0, 523.0, 0.07], [659.0, 659.0, 0.07], [784.0, 784.0, 0.16]],
	"hurt": [[520.0, 180.0, 0.25]],
	"die": [[600.0, 90.0, 0.55]],
	"life": [[659.0, 659.0, 0.08], [880.0, 880.0, 0.08], [1175.0, 1175.0, 0.18]],
	"spring": [[220.0, 1100.0, 0.22]],
	"checkpoint": [[660.0, 660.0, 0.08], [880.0, 880.0, 0.16]],
	"clear": [[523.0, 523.0, 0.12], [659.0, 659.0, 0.12], [784.0, 784.0, 0.12], [1047.0, 1047.0, 0.4]],
	"bolt_fire": [[900.0, 1500.0, 0.05], [1500.0, 700.0, 0.06]],
	"bolt_hit": [[1200.0, 400.0, 0.07]],
	"bolt_clink": [[2200.0, 1800.0, 0.04]],
	"blaster_get": [[523.0, 523.0, 0.06], [784.0, 784.0, 0.06], [1047.0, 1047.0, 0.06], [1319.0, 1319.0, 0.16]],
	"plane_fwip": [[700.0, 1300.0, 0.1], [1300.0, 500.0, 0.12]],
	"eraser_fall": [[600.0, 200.0, 0.25]],
	"eraser_boing": [[180.0, 320.0, 0.08], [320.0, 140.0, 0.1]],
	"duck_squeak": [[800.0, 1500.0, 0.45], [1500.0, 2100.0, 0.45]],
	"duck_raspberry": [[140.0, 90.0, 0.3], [90.0, 130.0, 0.2]],
	"bubble_pop": [[500.0, 1600.0, 0.05]],
	"teeth_chatter": [
		[1100.0, 1100.0, 0.03], [600.0, 600.0, 0.03], [1100.0, 1100.0, 0.03], [600.0, 600.0, 0.03],
		[1100.0, 1100.0, 0.03], [600.0, 600.0, 0.03], [1100.0, 1100.0, 0.03], [600.0, 600.0, 0.03],
	],
	"teeth_wind": [[200.0, 400.0, 0.1], [250.0, 450.0, 0.1], [300.0, 500.0, 0.1]],
	"armor_clang": [[1300.0, 700.0, 0.06], [1700.0, 500.0, 0.18]],
	"paint_sloop": [[500.0, 160.0, 0.22]],
	"band_boing": [[160.0, 520.0, 0.1], [520.0, 240.0, 0.18]],
	"wrench_clank": [[260.0, 180.0, 0.05], [340.0, 240.0, 0.08]],
	"boss_grumble": [[110.0, 80.0, 0.35], [80.0, 120.0, 0.35]],
	"boss_slam": [[130.0, 40.0, 0.4]],
	"boss_lob": [[400.0, 900.0, 0.2]],
	"boss_spit": [[300.0, 900.0, 0.1], [900.0, 300.0, 0.15]],
	"boss_ratchet": [
		[600.0, 600.0, 0.04], [300.0, 300.0, 0.06], [600.0, 600.0, 0.04],
		[300.0, 300.0, 0.06], [600.0, 600.0, 0.04], [300.0, 300.0, 0.06],
	],
	"boss_droop": [[400.0, 100.0, 0.7]],
	"boss_hit": [[900.0, 300.0, 0.12], [1200.0, 250.0, 0.16]],
	"boss_phase": [[200.0, 800.0, 0.3], [800.0, 300.0, 0.3]],
	"boss_down": [[800.0, 60.0, 1.4], [60.0, 900.0, 0.3]],
	"win": [[523.0, 523.0, 0.12], [659.0, 659.0, 0.12], [784.0, 784.0, 0.12], [1047.0, 1047.0, 0.12], [1319.0, 1319.0, 0.5]],
}

var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next_voice := 0


func _ready() -> void:
	for sound_name: String in SOUNDS:
		_streams[sound_name] = _synthesize(SOUNDS[sound_name])
	for _i in VOICES:
		var player := AudioStreamPlayer.new()
		add_child(player)
		_players.append(player)


## Plays a named sound on the next voice. An unknown name logs an error.
func play(sound_name: String) -> void:
	if not _streams.has(sound_name):
		push_error("Unknown sound: %s" % sound_name)
		return
	var player := _players[_next_voice]
	_next_voice = (_next_voice + 1) % VOICES
	player.stream = _streams[sound_name]
	player.play()


func _synthesize(notes: Array) -> AudioStreamWAV:
	var total_samples := 0
	for note: Array in notes:
		total_samples += int(float(note[2]) * MIX_RATE)
	var bytes := PackedByteArray()
	bytes.resize(total_samples * 2)
	var cursor := 0
	var phase := 0.0
	for note: Array in notes:
		var count := int(float(note[2]) * MIX_RATE)
		for i in count:
			var ratio := float(i) / float(count)
			phase = fmod(phase + lerpf(note[0], note[1], ratio) / MIX_RATE, 1.0)
			var square := 1.0 if phase < 0.5 else -1.0
			var triangle := 4.0 * absf(phase - 0.5) - 1.0
			var sample := (square * 0.4 + triangle * 0.6) * VOLUME * (1.0 - ratio * ratio)
			bytes.encode_s16(cursor, int(sample * 32767.0))
			cursor += 2
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.data = bytes
	return stream
