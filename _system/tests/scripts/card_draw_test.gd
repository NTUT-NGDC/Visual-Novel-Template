extends Node
## 抽卡場景的自動測試：
## 1. 卡牌資料：三類各 15 張；空白行、前後空白會被略過
## 2. 單格重抽：只換那一張，另外兩張不變，而且不會抽到同一張
## 3. 全部重抽：三張都換，而且都不會抽到同一張
## 4. 卡池只有 1 張、0 張、或全部重複時不會當掉
##
## 在命令列執行：
##   godot --headless --path . res://_system/tests/card_draw_test.tscn

const CARD_DRAW_SCENE: PackedScene = preload("res://lesson/card_draw/card_draw.tscn")
const CARD_DRAW_SCRIPT: GDScript = preload("res://lesson/card_draw/scripts/card_draw.gd")
## 每種重抽要連續試幾次
const REPEAT_COUNT: int = 200

var _failures: int = 0


func _ready() -> void:
	_test_deck_data()
	_test_split_cards()
	await _test_redraw_single()
	await _test_redraw_all()
	_test_small_pools()
	await _test_missing_deck()

	if _failures == 0:
		print("[抽卡測試] 全部 PASS")
		get_tree().quit(0)
	else:
		print("[抽卡測試] FAIL：%d 項失敗" % _failures)
		get_tree().quit(1)


func _test_deck_data() -> void:
	print("--- 卡牌資料 ---")
	var deck: CardDeck = load("res://lesson/card_draw/data/card_deck.tres")
	_expect(deck != null, "card_deck.tres 讀得到")
	if deck == null:
		return
	_expect(CardDeck.split_cards(deck.characters).size() == 15, "角色卡 15 張")
	_expect(CardDeck.split_cards(deck.places).size() == 15, "地點卡 15 張")
	_expect(CardDeck.split_cards(deck.troubles).size() == 15, "麻煩卡 15 張")


func _test_split_cards() -> void:
	print("--- 一行一張的拆法 ---")
	var cards: PackedStringArray = CardDeck.split_cards("  外送員 \n\n魔王\n   \n")
	_expect(cards == PackedStringArray(["外送員", "魔王"]), "略過空白行、去掉前後空白")
	_expect(CardDeck.split_cards("").is_empty(), "空字串 → 沒有卡")


func _test_redraw_single() -> void:
	print("--- 單格重抽（各 %d 次） ---" % REPEAT_COUNT)
	var card_draw: Control = await _spawn(null)
	var labels: Array[Label] = _get_labels(card_draw)
	var buttons: Array[Button] = [card_draw.get_node("%CharacterCard"), card_draw.get_node("%PlaceCard"), card_draw.get_node("%TroubleCard")]

	for index: int in buttons.size():
		var same_count: int = 0
		var others_changed: int = 0
		for i: int in REPEAT_COUNT:
			var before: PackedStringArray = _texts(labels)
			buttons[index].pressed.emit()
			var after: PackedStringArray = _texts(labels)
			if after[index] == before[index]:
				same_count += 1
			for other: int in labels.size():
				if other != index and after[other] != before[other]:
					others_changed += 1
		_expect(same_count == 0, "點第 %d 張：不會抽到同一張" % (index + 1))
		_expect(others_changed == 0, "點第 %d 張：另外兩張不變" % (index + 1))

	card_draw.queue_free()
	await get_tree().process_frame


func _test_redraw_all() -> void:
	print("--- 全部重抽（%d 次） ---" % REPEAT_COUNT)
	var card_draw: Control = await _spawn(null)
	var labels: Array[Label] = _get_labels(card_draw)
	var redraw_all_button: Button = card_draw.get_node("%RedrawAllButton")

	var same_count: int = 0
	var seen: Dictionary[String, bool] = {}
	for i: int in REPEAT_COUNT:
		var before: PackedStringArray = _texts(labels)
		redraw_all_button.pressed.emit()
		var after: PackedStringArray = _texts(labels)
		for index: int in labels.size():
			if after[index] == before[index]:
				same_count += 1
			seen[after[index]] = true
	_expect(same_count == 0, "三張都不會抽到同一張")
	# 45 張卡抽 200 次，幾乎一定每張都會出現；這裡只確認不是一直在抽少數幾張
	_expect(seen.size() >= 40, "抽得到大部分的卡（出現過 %d 種）" % seen.size())

	card_draw.queue_free()
	await get_tree().process_frame


func _test_small_pools() -> void:
	print("--- 卡池很小的情況 ---")
	_expect(CARD_DRAW_SCRIPT.pick_different(PackedStringArray(), "") == CARD_DRAW_SCRIPT.EMPTY_POOL_TEXT, "0 張 → 顯示「沒有卡牌」")
	_expect(CARD_DRAW_SCRIPT.pick_different(PackedStringArray(["魔王"]), "魔王") == "魔王", "只有 1 張 → 重抽還是那張")
	_expect(CARD_DRAW_SCRIPT.pick_different(PackedStringArray(["魔王", "魔王"]), "魔王") == "魔王", "全部重複 → 重抽還是那張")
	var two_cards: PackedStringArray = ["魔王", "勇者"]
	_expect(CARD_DRAW_SCRIPT.pick_different(two_cards, "魔王") == "勇者", "2 張 → 一定換成另一張")


func _test_missing_deck() -> void:
	print("--- 卡牌資料是空的 ---")
	var empty_deck: CardDeck = CardDeck.new()
	var card_draw: Control = await _spawn(empty_deck)
	var labels: Array[Label] = _get_labels(card_draw)
	_expect(_texts(labels) == PackedStringArray([CARD_DRAW_SCRIPT.EMPTY_POOL_TEXT, CARD_DRAW_SCRIPT.EMPTY_POOL_TEXT, CARD_DRAW_SCRIPT.EMPTY_POOL_TEXT]), "三張都顯示「沒有卡牌」")
	(card_draw.get_node("%RedrawAllButton") as Button).pressed.emit()
	_expect(true, "按全部重抽不會當掉")
	card_draw.queue_free()
	await get_tree().process_frame


## 建立抽卡場景。deck 給 null 就用場景裡設定好的 card_deck.tres
func _spawn(deck: CardDeck) -> Control:
	var card_draw: Control = CARD_DRAW_SCENE.instantiate()
	if deck != null:
		card_draw.set("deck", deck)
	add_child(card_draw)
	await get_tree().process_frame
	return card_draw


func _get_labels(card_draw: Control) -> Array[Label]:
	return [card_draw.get_node("%CharacterText"), card_draw.get_node("%PlaceText"), card_draw.get_node("%TroubleText")]


func _texts(labels: Array[Label]) -> PackedStringArray:
	var texts: PackedStringArray = []
	for label: Label in labels:
		texts.append(label.text)
	return texts


func _expect(ok: bool, description: String) -> void:
	print("  %s %s" % ["PASS" if ok else "FAIL", description])
	if not ok:
		_failures += 1
