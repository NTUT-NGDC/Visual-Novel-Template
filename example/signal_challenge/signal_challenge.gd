extends Node
## 進階挑戰：用 Dialogic 的 Signal 事件，從時間軸觸發遊戲裡的效果。
##
## 運作方式：
## 1. 在時間軸裡加一個 Signal 事件，參數填一段文字，例如 flash_red
##    （文字模式長這樣：[signal arg="flash_red"]）
## 2. 故事播到那裡時，Dialogic 會發出 signal_event 訊號，把這段文字傳過來
## 3. 這個腳本接到訊號，看文字是什麼，決定要做哪種效果
##
## 挑戰：試著自己加一種新效果！
## 例如在時間軸加 [signal arg="flash_blue"]，再到下面的 match 裡加一行。

## 要播放的時間軸
const TIMELINE_PATH: String = "res://example/signal_challenge/signal_challenge.dtl"

## 用來閃色的全畫面色塊（平常是透明的）
@onready var _flash_rect: ColorRect = %FlashRect


func _ready() -> void:
	# 時間軸播到 Signal 事件時，會呼叫 _on_dialogic_signal
	Dialogic.signal_event.connect(_on_dialogic_signal)
	Dialogic.start(TIMELINE_PATH)


## argument 就是 Signal 事件裡填的那段文字
func _on_dialogic_signal(argument: Variant) -> void:
	match argument:
		"flash_red":
			_flash(Color.RED)
		"flash_white":
			_flash(Color.WHITE)
		_:
			print("收到沒有對應效果的 Signal：", argument)


## 讓畫面閃一下指定的顏色，0.5 秒內淡掉
func _flash(color: Color) -> void:
	_flash_rect.color = color
	_flash_rect.modulate.a = 0.7
	var tween: Tween = create_tween()
	tween.tween_property(_flash_rect, "modulate:a", 0.0, 0.5)
