extends Node
## 暫時的測試場景：播放 test_timeline.dtl，確認 Dialogic 正常運作。
## 之後做好 story_player（播放場景）就會刪掉。

## 要播放的時間軸檔案路徑
const TIMELINE_PATH: String = "res://example/test_timeline.dtl"


func _ready() -> void:
	# 時間軸播完時，Dialogic 會發出 timeline_ended 訊號
	Dialogic.timeline_ended.connect(_on_timeline_ended)
	Dialogic.start(TIMELINE_PATH)


func _on_timeline_ended() -> void:
	print("[測試] 時間軸播放結束")
