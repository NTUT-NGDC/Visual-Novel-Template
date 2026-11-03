extends Control
## 抽卡場景：隨機給「角色＋地點＋麻煩」三張靈感卡。
##
## 點某一張卡：只重抽那一張。按下方的「全部重抽」：三張一起重抽。
## 重抽時不會抽到跟目前同一張。
##
## 卡牌內容不寫在這裡，要改請打開 lesson/card_draw/data/card_deck.tres。

## 某一類沒有任何卡牌時，卡片上顯示的文字
const EMPTY_POOL_TEXT: String = "（這一類沒有卡牌）"

## 卡牌內容。預設是 lesson/card_draw/data/card_deck.tres
@export var deck: CardDeck

## 三張卡的按鈕和顯示內容的文字，順序都是：角色、地點、麻煩
@onready var _card_buttons: Array[Button] = [%CharacterCard, %PlaceCard, %TroubleCard]
@onready var _card_labels: Array[Label] = [%CharacterText, %PlaceText, %TroubleText]
@onready var _redraw_all_button: Button = %RedrawAllButton

## 三類卡牌的清單，順序跟上面一樣
var _pools: Array[PackedStringArray] = []


func _ready() -> void:
	if deck == null:
		push_warning("抽卡場景沒有設定卡牌資料（deck），三張卡都會是空的。")
		deck = CardDeck.new()
	_pools = [
		CardDeck.split_cards(deck.characters),
		CardDeck.split_cards(deck.places),
		CardDeck.split_cards(deck.troubles),
	]

	for index: int in _card_buttons.size():
		_card_buttons[index].pressed.connect(redraw_card.bind(index))
	_redraw_all_button.pressed.connect(redraw_all)
	redraw_all()


## 重抽第 index 張卡（0 = 角色、1 = 地點、2 = 麻煩）
func redraw_card(index: int) -> void:
	_card_labels[index].text = pick_different(_pools[index], _card_labels[index].text)


## 三張卡全部重抽
func redraw_all() -> void:
	for index: int in _card_buttons.size():
		redraw_card(index)


## 從 pool 裡隨機挑一張「跟 current 不一樣」的卡。
## 只有一種卡可以選時就給那張；完全沒有卡時給 EMPTY_POOL_TEXT。
static func pick_different(pool: PackedStringArray, current: String) -> String:
	if pool.is_empty():
		return EMPTY_POOL_TEXT

	var candidates: PackedStringArray = []
	for card: String in pool:
		if card != current:
			candidates.append(card)
	if candidates.is_empty():
		return pool[0]
	return candidates[randi() % candidates.size()]
