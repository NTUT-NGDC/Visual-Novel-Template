extends CanvasLayer
## 暫停選單：故事播放中按 Esc 或右上角的「選單」按鈕打開，可以調音量、回到標題。
##
## 用法：把 pause_menu.tscn 從檔案系統拖進自己的故事場景（放在最上層節點底下）就好。
##
## 想改文字、字的大小、顏色：直接點場景裡的節點，在右邊的檢查器改，程式不會蓋掉。
##   ・右上角的按鈕：MenuButton　・選單裡的標題、按鈕、「音樂」「音效」：MenuPanel 底下的節點

## 按「回到標題」後要換到的標題畫面
@export_file("*.tscn") var title_scene: String = "res://game/title_screen/title_screen.tscn"

@onready var _menu_button: Button = %MenuButton
@onready var _menu_panel: Control = %MenuPanel
@onready var _resume_button: Button = %ResumeButton
@onready var _title_button: Button = %TitleButton


func _ready() -> void:
	_menu_panel.hide()
	_menu_button.pressed.connect(open_menu)
	_resume_button.pressed.connect(close_menu)
	_title_button.pressed.connect(_on_title_pressed)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if _menu_panel.visible:
			close_menu()
		else:
			open_menu()
		get_viewport().set_input_as_handled()


## 打開選單，並暫停 Dialogic（暫停時點畫面不會跳到下一句，音樂也會停）
func open_menu() -> void:
	_menu_panel.show()
	_menu_button.hide()
	Dialogic.paused = true


## 關掉選單，繼續播放
func close_menu() -> void:
	_menu_panel.hide()
	_menu_button.show()
	Dialogic.paused = false


func _on_title_pressed() -> void:
	Dialogic.paused = false
	# 停掉正在播的時間軸（true：不播 Dialogic 收尾的淡出），要等它真的停完。
	# 停完時 Dialogic 會發出 timeline_ended，故事場景通常會自己回到標題（像範例那樣）。
	# 不等的話，故事場景收到訊號時已經被換掉了，會出現錯誤
	await Dialogic.end_timeline(true)
	# 故事場景沒有自己換場景的話（還在畫面上），就由選單換回標題
	if is_inside_tree():
		get_tree().change_scene_to_file(title_scene)


func _exit_tree() -> void:
	# 選單開著就離開這個場景時，記得解除暫停，不然下次播放會卡住
	if _menu_panel.visible:
		Dialogic.paused = false
