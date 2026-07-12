extends Control

@onready var money_label: Label = find_child("MoneyLabel", true, false)

func _ready() -> void:
	EventBus.stats_changed.connect(_on_stats_changed)
	_on_stats_changed(GameState.money, GameState.reputation)

func _on_stats_changed(money: int, _reputation: int) -> void:
	money_label.text = _format_money(money)

func _format_money(value: int) -> String:
	var raw := str(value)
	var result := ""
	var count := 0
	for index in range(raw.length() - 1, -1, -1):
		if count > 0 and count % 3 == 0:
			result = "." + result
		result = raw[index] + result
		count += 1
	return "%s €" % result
