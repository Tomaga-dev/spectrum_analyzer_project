extends AudioStreamPlayer

@export var camera: Camera3D
@export var peak_indicator_scene: PackedScene
@export var bar_scene: PackedScene
@export var timer: Timer
@export var info: Label

var detail: int = 2 # Recomended values are 1 or 2. This will affect the number of bars in the display.
var bus_name: String
var bus_index: int
var effect_index: int
var spectrum: AudioEffectSpectrumAnalyzerInstance
var max_frequency: float = 16500
var bar_count: int = 20
var x_max: int
var bar_width: float = 1.1
var bar_max: float = 10 # Max height of the bar.
var peak: Array[Node3D]
var bar: Array[Node3D]
var args: Array[float]
var min_value: float
var db_range: float = 60
var speed: float = 2 # m/s


func _ready() -> void:
	info.visible = false
	timer.stop()
	var window: Window = get_viewport()
	if window:
		var _status: int
		_status = window.files_dropped.connect(on_files_dropped)
	if stream:
		var _status: int
		_status = finished.connect(on_song_finished)
	else:
		info.visible = true
		timer.start(6.5)
	camera.size = detail * 12.5
	camera.transform.origin.y = detail * 6
	speed = detail * 2
	bar_max = detail * 10
	bus_name = bus
	bus_index = AudioServer.get_bus_index(bus_name)
	effect_index = 0
	spectrum = AudioServer.get_bus_effect_instance(bus_index, effect_index)
	min_value = db_to_linear(-db_range)
	var q: float = 1.36
	var factor: float = max_frequency / pow(q, bar_count - 1)
	for i: int in range(bar_count + 1):
		var e: float = i as float
		var arg: float
		var detail_f: float = detail as float
		var e_start: float = 1 / detail_f
		for j: int in range(detail):
			e += e_start * j
			arg = factor * pow(q, e)
			args.append(arg)
	x_max = bar_count * detail
	var x_offset: float = - 0.5 * bar_width * x_max + 0.5 * bar_width
	var left: float = x_offset
	for i: int in range(x_max):
		var node: Node3D = peak_indicator_scene.instantiate()
		node.transform.origin.x = left
		node.transform.origin.y = bar_max
		left += bar_width
		peak.append(node)
		add_child(node)
	left = x_offset
	for i: int in range(x_max):
		var node: Node3D = bar_scene.instantiate()
		node.transform.origin.x = left
		left += bar_width
		bar.append(node)
		add_child(node)

func _process(delta: float) -> void:
	for i: int in range(x_max):
		var f1: float = args[i]
		var f2: float = args[i + 1]
		var value: Vector2 = spectrum.get_magnitude_for_frequency_range(f1, f2)
		var magnitude: float = value.length()
		var clamped: float = clampf(magnitude, min_value, 1)
		var db: float = linear_to_db(clamped)
		var normalized: float = (db_range + db) / db_range
		var height: float = normalized * bar_max
		bar[i].transform.origin.y = height
		var distance: float = speed * delta
		var peak_height: float = peak[i].transform.origin.y
		if peak_height > height:
			peak_height -= distance
		else:
			peak_height = height
		peak[i].transform.origin.y = peak_height

func on_files_dropped(files: PackedStringArray) -> void:
	var path: String = files[0]
	var window: Window = get_viewport()
	window.title = path
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	var file_length: int =  file.get_length()
	info.visible = false
	timer.stop()
	path = path.to_lower()
	if path.ends_with(".mp3"):
		var sound: AudioStreamMP3 = AudioStreamMP3.new()
		sound.data = file.get_buffer(file_length)
		stream = sound
	if path.ends_with(".wav"):
		var sound: AudioStreamWAV = AudioStreamWAV.new()
		if file_length > 44:
			var header: PackedByteArray = file.get_buffer(44)
			file.seek(44)
			file_length -= 44
			var num_chanels: int = header[22] + header[23] * 256
			var sample_rate: int = header[24] + header[25] * 256
			var bytes_per_block: int = header[32] + header[33] * 256
			if bytes_per_block > num_chanels:
				sound.format = AudioStreamWAV.FORMAT_16_BITS
			if bytes_per_block:
				var result: float = file_length as float / bytes_per_block as float
				sound.loop_end = result as int
			if num_chanels > 1:
				sound.stereo = true
			sound.mix_rate = sample_rate
			sound.data = file.get_buffer(file_length)
			sound.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream = sound
	if !finished.is_connected(on_song_finished):
		var _status: int
		_status = finished.connect(on_song_finished)
	play()
	set_process(true) # now we need the GPU to update the graphics continously

func on_song_finished() -> void:
	timer.start(6.5)

func _on_timer_timeout() -> void:
	info.visible = true
	set_process(false) # let the GPU idle
