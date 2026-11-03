extends Control
## 標題畫面：開始遊戲／設定（音量）／離開遊戲。這是專案的主場景，按 F5 會先看到它。
##
## 想改文字、字的大小、顏色、字型、背景圖：直接點場景裡的節點，在右邊的檢查器改，程式不會蓋掉。
##   ・遊戲名稱：GameName 的 Text
##   ・小字：Hook 的 Text
##   ・按鈕文字：StartButton、SettingsButton、QuitButton 的 Text
##   ・設定面板：SettingsPanel 底下的節點（標題、「音樂」「音效」、返回按鈕）
##   ・字的大小、顏色、字型：各節點的 Theme Overrides
##   ・背景圖：把圖片拖進 BackgroundImage 的 Texture
##
## 點最上層的 TitleScreen 節點，在檢查器設定：
##   ・Story Scene：把自己的故事場景（.tscn）從檔案系統拖進來
##   ・Title Music：把標題畫面的背景音樂拖進來（空著就沒有音樂）

## 按「開始遊戲」後要換到的故事場景（.tscn）
@export_file("*.tscn") var story_scene: String = "res://example/story_scene/story_scene.tscn"
## 標題畫面的背景音樂（.mp3、.ogg、.wav），空著就沒有音樂。
## 音量跟著設定裡的「音樂」滑桿，播完會從頭再播
@export var title_music: AudioStream

@onready var _start_button: Button = %StartButton
@onready var _settings_button: Button = %SettingsButton
@onready var _quit_button: Button = %QuitButton
@onready var _message_label: Label = %MessageLabel
@onready var _settings_panel: Control = %SettingsPanel
@onready var _back_button: Button = %BackButton


func _ready() -> void:
	_message_label.hide()
	_settings_panel.hide()
	# Web 版沒辦法用程式關掉瀏覽器分頁，按了不會有反應，所以藏起來
	_quit_button.visible = not OS.has_feature("web")

	_start_button.pressed.connect(_on_start_pressed)
	_settings_button.pressed.connect(_settings_panel.show)
	_back_button.pressed.connect(_settings_panel.hide)
	_quit_button.pressed.connect(get_tree().quit)
	_play_title_music()


## 有設定標題音樂就播放：建立一個播放器，接到 Music 匯流排（設定裡的「音樂」滑桿管得到）
func _play_title_music() -> void:
	if title_music == null:
		return
	var player := AudioStreamPlayer.new()
	player.name = "TitleMusicPlayer"
	player.stream = title_music
	player.bus = &"Music"
	# 播完就從頭再播（MP3 匯入後預設不會循環）
	player.finished.connect(player.play)
	add_child(player)
	player.play()


func _unhandled_input(event: InputEvent) -> void:
	# 設定面板打開時，按 Esc 也可以關掉
	if _settings_panel.visible and event.is_action_pressed("ui_cancel"):
		_settings_panel.hide()
		get_viewport().set_input_as_handled()


func _on_start_pressed() -> void:
	var problem: String = _check_story_scene()
	if problem != "":
		_message_label.text = problem
		_message_label.show()
		return
	get_tree().change_scene_to_file(story_scene)


## 回傳空字串代表故事場景沒問題，否則回傳要顯示給社員看的說明
func _check_story_scene() -> String:
	if story_scene == "":
		return "還沒有設定故事場景。\n請點選 TitleScreen 節點，把你的故事場景（.tscn）拖進檢查器的「Story Scene」。"

	# 拖檔案進欄位時，路徑可能會存成 uid://… 的格式，這裡轉回一般路徑方便閱讀
	var readable_path: String = story_scene
	if story_scene.begins_with("uid://"):
		readable_path = ResourceUID.ensure_path(story_scene)

	if not ResourceLoader.exists(story_scene):
		return "找不到故事場景：%s\n請重新把你的故事場景拖進 TitleScreen 的「Story Scene」。" % readable_path
	if not load(story_scene) is PackedScene:
		return "這個檔案不是場景：%s\n「Story Scene」要選 .tscn 結尾的場景檔。" % readable_path
	return ""
