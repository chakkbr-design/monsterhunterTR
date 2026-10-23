class_name MartShop
extends RefCounted
## Poké Mart rules (stock from data/shops.json, prices from Dex.item). Selling pays half price.
## Buying 10+ Poké Balls in one go adds a Premier Ball, like the original. `game` defaults to the
## Game autoload (tests pass a core/game.gd instance).

const BONUS_ITEM := "premier_ball"
const BONUS_FOR := "poke_ball"
const BONUS_AT := 10
const MAX_QTY := 99

static var _shops: Dictionary = {}


static func _game(game: Object) -> Object:
	if game:
		return game
	var ml := Engine.get_main_loop()
	return ml.root.get_node_or_null("Game") if ml is SceneTree else null


static func stock(shop_id: String) -> Array:
	if _shops.is_empty():
		var d = JSON.parse_string(FileAccess.get_file_as_string("res://data/shops.json"))
		if d is Dictionary:
			_shops = d
	var s = _shops.get(shop_id, [])
	return s.duplicate() if s is Array else []


static func price(id: String) -> int:
	return int(Dex.item(id).get("price", 0))


static func sell_price(id: String) -> int:
	return price(id) / 2


static func item_name(id: String) -> String:
	return String(Dex.item(id).get("name", id))


static func count(id: String, game: Object = null) -> int:
	var g := _game(game)
	return int(g.bag.get(id, 0)) if g else 0


## Items in the bag that can be sold (key items and price-0 items cannot).
static func sellable(game: Object = null) -> Array:
	var g := _game(game)
	var out: Array = []
	if g == null:
		return out
	for id in g.bag:
		if sell_price(String(id)) > 0 and int(g.bag[id]) > 0 and String(Dex.item(String(id)).get("category", "")) != "key":
			out.append(String(id))
	out.sort()
	return out


static func max_buy(id: String, game: Object = null) -> int:
	var g := _game(game)
	var unit := price(id)
	if g == null or unit <= 0:
		return 0
	return mini(MAX_QTY, int(g.money) / unit)


static func max_sell(id: String, game: Object = null) -> int:
	return mini(MAX_QTY, count(id, game)) if sell_price(id) > 0 else 0


## Debits money and adds the items (plus the Premier Ball bonus). False if it can't afford it.
static func buy(id: String, n: int, game: Object = null) -> bool:
	var g := _game(game)
	var unit := price(id)
	if g == null or unit <= 0 or n <= 0 or int(g.money) < unit * n:
		return false
	g.money -= unit * n
	g.add_item(id, n)
	if id == BONUS_FOR and n >= BONUS_AT:
		g.add_item(BONUS_ITEM, 1)
	return true


## Removes the items and pays half price each. False if there aren't enough or it can't be sold.
static func sell(id: String, n: int, game: Object = null) -> bool:
	var g := _game(game)
	if g == null or n <= 0 or sell_price(id) <= 0 or String(Dex.item(id).get("category", "")) == "key":
		return false
	if not g.take_item(id, n):
		return false
	g.money += sell_price(id) * n
	return true
