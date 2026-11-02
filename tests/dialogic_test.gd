extends Node
## 暫時的測試場景：播放一條時間軸，確認 Dialogic 正常運作。
## 之後做好 story_player（播放場景）就會刪掉。

## 要播放的時間軸檔案，可以在檢查器裡換
@export_file("*.dtl") var timeline_path: String = "res://example/example_story.dtl"


func _ready() -> void:
	# 時間軸播完時，Dialogic 會發出 timeline_ended 訊號
	Dialogic.timeline_ended.connect(_on_timeline_ended)
	# 時間軸裡的 [signal arg="..."] 事件會發出 signal_event 訊號
	Dialogic.signal_event.connect(_on_signal_event)
	Dialogic.start(timeline_path)


func _on_signal_event(argument: Variant) -> void:
	print("[測試] 收到 Signal 事件：", argument)


func _on_timeline_ended() -> void:
	print("[測試] 時間軸播放結束，好感度 = ", Dialogic.VAR.get_variable("好感度"))
