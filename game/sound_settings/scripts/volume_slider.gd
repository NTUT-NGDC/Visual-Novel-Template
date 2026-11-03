extends HSlider
## 音量滑桿：拖動就調整一條音訊匯流排的音量，並自動記住。
##
## 用法：新增一個 HSlider 節點，把這個腳本拖上去，在檢查器的「Bus Name」選要調哪一條。
## 旁邊的文字（例如「音樂」）用另一個 Label 節點，想改字直接改那個 Label。

## 要調整的音訊匯流排：Music 是背景音樂，SFX 是音效（包括打字聲），Master 是全部
@export_enum("Music", "SFX", "Master") var bus_name: String = "Music"


func _ready() -> void:
	min_value = 0.0
	max_value = 1.0
	step = 0.05
	value = SoundSettings.get_volume(bus_name)
	value_changed.connect(_on_value_changed)


func _on_value_changed(new_value: float) -> void:
	SoundSettings.set_volume(bus_name, new_value)
