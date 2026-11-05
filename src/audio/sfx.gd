class_name Sfx
extends Node
## Sound effects synthesized at startup, so the game ships no audio files.
## Usage: sfx.play("jump")

const MIX_RATE := 22050
const VOLUME := 0.22
const VOICES := 6

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
