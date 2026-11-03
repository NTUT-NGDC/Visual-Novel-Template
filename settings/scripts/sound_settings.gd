extends Node
## 記住音量的全域腳本（autoload，名稱是 SoundSettings，在「專案設定 → 全域」裡）。
## 遊戲一開始就讀取上次存的音量並套用；音量滑桿調整時會呼叫 set_volume()，稍後自動存檔。
## 音量存在 user://sound_settings.cfg（Web 版存在瀏覽器裡，重新整理網頁也會記得）。
##
## 音訊匯流排（Music、SFX）在 default_bus_layout.tres，Godot 下方的「音訊」面板看得到。

const SAVE_PATH: String = "user://sound_settings.cfg"
const SECTION: String = "volume"
## 調整後等多久才存檔（拖滑桿時不用每動一下就存一次）
const SAVE_DELAY: float = 0.3

var _save_scheduled: bool = false


func _ready() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK or not config.has_section(SECTION):
		return
	for bus_name: String in config.get_section_keys(SECTION):
		var value: Variant = config.get_value(SECTION, bus_name)
		if value is float or value is int:
			_apply(bus_name, clampf(float(value), 0.0, 1.0))


## 某條匯流排目前的音量，0（靜音）～1（最大聲）
func get_volume(bus_name: String) -> float:
	var index: int = AudioServer.get_bus_index(bus_name)
	if index < 0:
		return 1.0
	if AudioServer.is_bus_mute(index):
		return 0.0
	return db_to_linear(AudioServer.get_bus_volume_db(index))


## 設定某條匯流排的音量（0～1），稍後自動存檔
func set_volume(bus_name: String, volume: float) -> void:
	if not _apply(bus_name, clampf(volume, 0.0, 1.0)):
		return
	if not _save_scheduled:
		_save_scheduled = true
		get_tree().create_timer(SAVE_DELAY).timeout.connect(_save)


## 套用音量；找不到匯流排時回傳 false
func _apply(bus_name: String, volume: float) -> bool:
	var index: int = AudioServer.get_bus_index(bus_name)
	if index < 0:
		push_warning("找不到音訊匯流排「%s」，請到 Godot 下方的「音訊」面板確認名稱。" % bus_name)
		return false
	# 拉到 0 時直接靜音（音量換算成分貝時，0 會變成負無限大）
	AudioServer.set_bus_mute(index, volume <= 0.0)
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(volume, 0.0001)))
	return true


func _save() -> void:
	_save_scheduled = false
	var config := ConfigFile.new()
	for index: int in AudioServer.bus_count:
		var bus_name: String = AudioServer.get_bus_name(index)
		config.set_value(SECTION, bus_name, get_volume(bus_name))
	config.save(SAVE_PATH)
