extends Node
## 故事場景範例：一打開就播放時間軸，播完回到標題畫面。
##
## 做自己的故事場景（不用改程式）：
## 1. 複製 story_scene.tscn，改名成 my_story_scene.tscn，搬到 my_story 資料夾
## 2. 點最上層的節點，在檢查器的「Timeline Path」選自己的時間軸（.dtl）
## 3. 把你的場景拖進標題畫面（TitleScreen）的「Story Scene」
## 暫停選單（PauseMenu）已經放好了，複製場景時會一起帶過去。

## 故事播完後要回去的標題畫面
const TITLE_SCENE: String = "res://game/title_screen/title_screen.tscn"

## 要播放的時間軸（.dtl）。複製這個場景後，改成自己的時間軸
@export_file("*.dtl") var timeline_path: String = "res://example/timelines/example_story.dtl"


func _ready() -> void:
	# 找不到時間軸就不播放，並在下方的輸出面板顯示原因
	if not Dialogic.timeline_exists(timeline_path):
		push_error("找不到時間軸：%s。請到檢查器的「Timeline Path」重新選擇。" % timeline_path)
		return
	# 時間軸播完時，Dialogic 會發出 timeline_ended 訊號，收到就執行下面的 _on_timeline_ended
	Dialogic.timeline_ended.connect(_on_timeline_ended)
	# 把變數（例如好感度）重設回初始值，不然第二次玩會接著上一次的數字
	Dialogic.VAR.reset()
	# 開始播放檢查器裡選的時間軸
	Dialogic.start(timeline_path)


func _on_timeline_ended() -> void:
	# 回到標題畫面
	get_tree().change_scene_to_file(TITLE_SCENE)
