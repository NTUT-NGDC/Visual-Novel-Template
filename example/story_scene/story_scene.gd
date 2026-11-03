extends Node
## 故事場景範例：一打開就播放時間軸，播完回到標題畫面。
##
## 做自己的故事場景：在 my_story 資料夾新建一個場景，加上跟這個一樣的腳本，
## 把下面的 "example_story" 改成自己時間軸的名字（檔名，不含 .dtl）。
## 想要暫停選單：把 game/pause_menu/pause_menu.tscn 拖進場景裡（這個範例已經放好了）。
## 最後把你的場景拖進標題畫面（TitleScreen）的「Story Scene」。

## 故事播完後要回去的標題畫面
const TITLE_SCENE: String = "res://game/title_screen/title_screen.tscn"


func _ready() -> void:
	# 時間軸播完時，Dialogic 會發出 timeline_ended 訊號，收到就執行下面的 _on_timeline_ended
	Dialogic.timeline_ended.connect(_on_timeline_ended)
	# 把變數（例如好感度）重設回初始值，不然第二次玩會接著上一次的數字
	Dialogic.VAR.reset()
	# 開始播放時間軸，"example_story" 是時間軸的名字
	Dialogic.start("example_story")


func _on_timeline_ended() -> void:
	# 回到標題畫面
	get_tree().change_scene_to_file(TITLE_SCENE)
