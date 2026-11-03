extends CanvasLayer
## 變數面板：在畫面左上角顯示所有 Dialogic 變數目前的值，
## 方便確認「好感度」這類變數有沒有照預期改變。
## 在播放場景裡預設是隱藏的，要除錯時在檢查器把這個節點的 Visible 打開。
## 匯出給別人玩之前記得關掉。

@onready var _list_label: Label = %ListLabel


func _ready() -> void:
	# 時間軸裡的「設定變數」事件改了變數時，Dialogic 會發出 variable_changed
	Dialogic.VAR.variable_changed.connect(_on_variable_changed)
	# 重玩時播放場景會用 Dialogic.VAR.reset() 把變數重設回初始值，
	# reset() 不會發出 variable_changed，所以在時間軸開始時也刷新一次
	Dialogic.timeline_started.connect(_refresh)
	_refresh()


func _on_variable_changed(_info: Dictionary) -> void:
	_refresh()


## 重新列出所有變數和目前的值
func _refresh() -> void:
	var variable_names: Array = DialogicUtil.list_variables(Dialogic.VAR.var_storage)
	if variable_names.is_empty():
		_list_label.text = "（沒有變數）"
		return

	var lines: PackedStringArray = []
	for variable_name: String in variable_names:
		var value: Variant = Dialogic.VAR.get_variable(variable_name)
		lines.append("%s = %s" % [variable_name, _format_value(value)])
	_list_label.text = "\n".join(lines)


## 把 1.0 這種「其實是整數的小數」顯示成 1，比較好讀
func _format_value(value: Variant) -> String:
	if value is float and is_equal_approx(value, roundf(value)):
		return str(int(value))
	return str(value)
