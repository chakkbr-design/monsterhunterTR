class_name BattleHUD
extends CanvasLayer
## HUD da batalha no visual do original (ui/battle_hud.gd + fx_popups.gd + battle_intro.gd):
## cartões de lutador (retrato, nome, Lv, tipos, status, HP com rastro, PP/stamina, EXP), cartão do aliado,
## golpes em losango, banner em pílula, faixas de introdução + "Lutem!", popups de dano em tela e menu rápido.
## API usada pela arena: banner(text, secs), refresh(player, enemy, dt, ally, info), add_popup(...), intro_bars(on), fight_flash().

const CARD_W := 506.0
const CARD_H := 92.0
const CARD_MARGIN := 14.0
const CARD_TOP := 12.0
const ALLY_W := 340.0
const ALLY_H := 40.0
const MOVE_R := 42.0
const MOVE_DX := 92.0
const MOVE_DY := 68.0
const DIAMOND_AT := Vector2(-182.0, -134.0)
const BAR_H := 72.0
const HELP := "WASD anda  Shift corre  Espaço pula  1-4 golpes  E bolsa  Tab troca  F aliado  Q bola  Z/C câmera  Esc pausa"
const PAUSE_W := 300.0

var _root: Control
var _player_card: FighterCard
var _foe_card: FighterCard
var _ally_card: AllyCard
var _moves: Array = []
var _banner: BannerPill
var _intro: IntroLayer
var _pops: Control
var _menu: Label
var _menu_bg: PanelContainer
var _help: Label
var _log: BattleLogLine
var _pause_bg: PanelContainer
var _pause: Label


func _init() -> void:
	layer = 5
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_intro = IntroLayer.new()
	_root.add_child(_intro)
	_intro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pops = Control.new()
	_pops.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_pops)
	_pops.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_foe_card = FighterCard.new()
	_foe_card.foe = true
	_place(
		_foe_card,
		Vector2(1, 0),
		Vector2(CARD_W, CARD_H),
		Vector2(-CARD_MARGIN - CARD_W * 0.5, CARD_TOP + CARD_H * 0.5)
	)
	_player_card = FighterCard.new()
	_place(
		_player_card,
		Vector2(0, 0),
		Vector2(CARD_W, CARD_H),
		Vector2(CARD_MARGIN + CARD_W * 0.5, CARD_TOP + CARD_H * 0.5)
	)
	_ally_card = AllyCard.new()
	_place(
		_ally_card,
		Vector2(0, 0),
		Vector2(ALLY_W, ALLY_H),
		Vector2(CARD_MARGIN + ALLY_W * 0.5, CARD_TOP + CARD_H + 6.0 + ALLY_H * 0.5)
	)
	var offs := [
		Vector2(0, MOVE_DY), Vector2(MOVE_DX, 0), Vector2(-MOVE_DX, 0), Vector2(0, -MOVE_DY)
	]
	for i in 4:
		var b := MoveButton.new()
		b.index = i
		_place(b, Vector2(1, 1), Vector2(MOVE_R, MOVE_R) * 2.0, DIAMOND_AT + offs[i])
		_moves.append(b)
	_banner = BannerPill.new()
	_place(_banner, Vector2(0.5, 0), Vector2(900, 64), Vector2(0, CARD_TOP + CARD_H + 52))
	_help = Label.new()
	_help.anchor_top = 1.0
	_help.anchor_bottom = 1.0
	_help.offset_left = 16
	_help.offset_top = -30
	_help.offset_right = 760
	_help.add_theme_font_override("font", UiDraw.font())
	_help.add_theme_font_size_override("font_size", 14)
	_help.add_theme_constant_override("outline_size", 4)
	_help.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_help.modulate = Color(1, 1, 1, 0.8)
	_help.text = HELP
	_root.add_child(_help)
	_menu_bg = PanelContainer.new()
	_menu_bg.offset_left = CARD_MARGIN
	_menu_bg.offset_top = CARD_TOP + CARD_H + ALLY_H + 20
	var msb := UiDraw.glass_box(0.86, 12)
	msb.set_content_margin_all(12)
	_menu_bg.add_theme_stylebox_override("panel", msb)
	_menu = Label.new()
	_menu.add_theme_font_override("font", UiDraw.font())
	_menu.add_theme_font_size_override("font_size", 16)
	_menu_bg.add_child(_menu)
	_menu_bg.visible = false
	_root.add_child(_menu_bg)
	_log = BattleLogLine.new()
	_place(
		_log,
		Vector2(0.5, 0),
		Vector2(BattleLogLine.MAX_W + 220.0, BattleLogLine.H),
		Vector2(0, BattleLogLine.TOP + BattleLogLine.H * 0.5)
	)
	# Pausa da batalha no canto de cima à direita, como a janela do pause_menu.gd do original.
	_pause_bg = PanelContainer.new()
	_pause_bg.anchor_left = 1.0
	_pause_bg.anchor_right = 1.0
	_pause_bg.offset_left = -PAUSE_W - 24.0
	_pause_bg.offset_right = -24.0
	_pause_bg.offset_top = 24.0
	var psb := UiDraw.glass_box(0.92, 12)
	psb.set_content_margin_all(16)
	_pause_bg.add_theme_stylebox_override("panel", psb)
	_pause = Label.new()
	_pause.add_theme_font_override("font", UiDraw.title_font())
	_pause.add_theme_font_size_override("font_size", 20)
	_pause.add_theme_constant_override("line_spacing", 6)
	_pause_bg.add_child(_pause)
	_pause_bg.visible = false
	_root.add_child(_pause_bg)


func _place(c: Control, anchor: Vector2, size_px: Vector2, center: Vector2) -> void:
	_root.add_child(c)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.anchor_left = anchor.x
	c.anchor_right = anchor.x
	c.anchor_top = anchor.y
	c.anchor_bottom = anchor.y
	c.offset_left = center.x - size_px.x * 0.5
	c.offset_right = center.x + size_px.x * 0.5
	c.offset_top = center.y - size_px.y * 0.5
	c.offset_bottom = center.y + size_px.y * 0.5


func banner(text: String, secs := 1.6) -> void:
	_banner.show_text(text, secs)


func banner_text() -> String:
	return _banner.text if _banner.t > 0.0 else ""


## Faixa de log da batalha (porte do battle_log.gd): última linha, com marca de cor por tipo.
func log_push(text: String, kind := "info") -> void:
	_log.push(text, kind)


func log_text() -> String:
	return _log.last_text()


## Dica de tecla na faixa de log ("E continuar" no resultado); text "" limpa.
func log_hint(glyph: String, text := "") -> void:
	_log.hint_glyph = glyph if text != "" else ""
	_log.hint_text = text


func pause_text() -> String:
	return _pause.text if _pause_bg.visible else ""


## Faixas pretas de cinema (introdução da batalha).
func intro_bars(on: bool) -> void:
	_intro.want = 1.0 if on else 0.0


## "Lutem!" grande no centro (fim da introdução).
func fight_flash(text := "Lutem!") -> void:
	_intro.flash(text)


## Popup de batalha em tela, ancorado num ponto do mundo (estilo do fx_popups.gd do original).
func add_popup(world: Vector3, text: String, col: Color, scale_k := 1.0, style := "") -> void:
	if style == "":
		style = guess_style(text)
	var p := Pop.new()
	p.world = world
	p.text = text
	p.col = col
	p.scale_k = scale_k
	p.style = style
	p.life = float(Pop.LIFE.get(style, 0.8))
	if style == "damage":
		p.jitter = randf_range(-16.0, 16.0)
	var cam := _pops.get_viewport().get_camera_3d() if _pops.is_inside_tree() else null
	if cam and not cam.is_position_behind(world):
		var sp := cam.unproject_position(world)
		for o in _pops.get_children():
			if o.age >= 0.35 or o.screen.distance_to(sp) >= 40.0:
				continue
			p.stack = minf(p.stack, o.stack - o.text_height() - 4.0)
	_pops.add_child(p)


static func guess_style(text: String) -> String:
	if text.is_valid_int():
		return "damage"
	match text:
		"CRÍTICO!":
			return "crit"
		"SUPEREFETIVO!":
			return "super"
		"Pouco efetivo":
			return "weak"
		"Errou!":
			return "miss"
		"DESVIOU!":
			return "dodge"
		"Interrompido!":
			return "interrupted"
	if text.begins_with("+") and text.ends_with("HP"):
		return "heal"
	if text.begins_with("Vai, ") or text.begins_with("Subiu") or text.begins_with("Aprendeu"):
		return "callout"
	return "info"


## info: {ally_mode, item_cd, menu, foe_tag, foe_balls: Array[bool]}.
func refresh(
	player: BattleFighter, enemy: BattleFighter, dt: float, ally: BattleFighter = null, info := {}
) -> void:
	_banner.step(dt)
	_intro.step(dt)
	# A faixa de log some enquanto a pílula de banner (abertura, troca do treinador) está no mesmo lugar.
	_log.hidden_by_banner = _banner.t > 0.0
	_log.step(dt)
	var pt := String(info.get("pause", ""))
	_pause_bg.visible = pt != ""
	_pause.text = pt
	for p in _pops.get_children():
		p.step(dt)
	_player_card.body = player if is_instance_valid(player) else null
	_foe_card.body = enemy if is_instance_valid(enemy) else null
	_foe_card.tag = String(info.get("foe_tag", "SELVAGEM"))
	_foe_card.balls = info.get("foe_balls", [])
	var has_ally := is_instance_valid(ally) and ally.active()
	_ally_card.body = ally if has_ally else null
	_ally_card.mode = String(info.get("ally_mode", ""))
	_ally_card.visible = has_ally
	# Resultado do fim: a barra de EXP do cartão enche sob o controle da arena (begin_scripted/fill_to).
	var xs: Dictionary = info.get("exp_script", {})
	for c in [_player_card, _foe_card]:
		c.script_xp = -1.0
		if not xs.is_empty() and c.body != null and c.body.mon == xs.get("mon"):
			c.script_xp = float(xs.xp)
			c.script_level = int(xs.level)
		c.visible = c.body != null
		c.step(dt)
	_ally_card.queue_redraw()
	var icd := float(info.get("item_cd", 0.0))
	_help.text = HELP + ("   item %.1fs" % icd if icd > 0.0 else "")
	var mt := String(info.get("menu", ""))
	_menu_bg.visible = mt != ""
	_menu.text = mt
	for b in _moves:
		b.body = player if is_instance_valid(player) else null
		b.visible = b.body != null
		b.queue_redraw()


## Para testes: o que os cartões mostram.
func card_text(which := "player") -> String:
	var c: FighterCard = _foe_card if which == "foe" else _player_card
	return c.body.mon.display_name if c.body != null and c.visible else ""


## Retângulos em tela para o holofote do tutorial (battle_hud.gd do original).
func card_rect(which: String) -> Rect2:
	var c: Control = _foe_card if which == "foe" else _player_card
	if which == "ally":
		c = _ally_card
	return Rect2(c.position, c.size) if c else Rect2()


func moves_rect() -> Rect2:
	if _moves.is_empty():
		return Rect2()
	var r := Rect2(_moves[0].position, _moves[0].size)
	for b in _moves:
		r = r.merge(Rect2(b.position, b.size))
	return r


func move_rect(i: int) -> Rect2:
	if i < 0 or i >= _moves.size():
		return Rect2()
	return Rect2(_moves[i].position, _moves[i].size)


func foe_chips_rect() -> Rect2:
	var c: Rect2 = _foe_card.chips
	return Rect2(_foe_card.position + c.position, c.size) if c.size.x > 0.0 else Rect2()


# ---------------------------------------------------------------------------


class FighterCard:
	extends Control
	const PORTRAIT_R := 37.0
	const HP_W := 392.0
	const HP_H := 12.0
	const PP_W := 300.0
	const EXP_W := 86.0
	const NAME_Y := 30.0
	const CHIP_Y := 42.0
	const HP_ROW_Y := 64.0
	const PP_ROW_Y := 79.0

	var foe := false
	var body: BattleFighter
	var tag := "SELVAGEM"
	var balls: Array = []
	var drawn_name := ""
	## Onde os chips de estágio (▲▼) foram desenhados, local ao cartão (holofote do tutorial).
	var chips := Rect2()
	## >= 0: XP mostrado pela sequência de resultado (barra enchendo) e o nível que ela anuncia.
	var script_xp := -1.0
	var script_level := 0
	var _mon: Mon
	var _hp_ratio := 1.0
	var _ghost := 1.0
	var _ghost_hold := 0.0

	func _ready() -> void:
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	func step(dt: float) -> void:
		if body == null:
			return
		var r := float(body.hp) / maxf(body.max_hp, 1)
		if body.mon != _mon:
			_mon = body.mon
			_hp_ratio = r
			_ghost = r
		if r < _hp_ratio:
			_ghost_hold = 0.45
		_hp_ratio = r
		if _ghost < _hp_ratio:
			_ghost = _hp_ratio
		elif _ghost_hold > 0.0:
			_ghost_hold -= dt
		else:
			_ghost = move_toward(_ghost, _hp_ratio, dt * 0.8)
		queue_redraw()

	func _exp_ratio() -> float:
		var m := body.mon
		var xp := float(m.xp)
		var lvl := m.level
		if script_xp >= 0.0:
			xp = script_xp
			lvl = Growth.level_for_exp(m.growth, int(xp))
		if lvl >= Growth.MAX_LEVEL:
			return 1.0
		var lo := float(Growth.exp_for_level(m.growth, lvl))
		var hi := float(Growth.exp_for_level(m.growth, lvl + 1))
		return clampf((xp - lo) / maxf(hi - lo, 1.0), 0.0, 1.0)

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		if body == null:
			return
		var types: Array = body.types
		var accent: Color = Dex.type_color(String(types[0]) if not types.is_empty() else "normal")
		UiDraw.rounded(self, Rect2(r.position + Vector2(0, 4), r.size), Color(0, 0, 0, 0.35), 14)
		UiDraw.glass(self, r, 0.72, 14)
		var edge_x := size.x - 6.0 if foe else 0.0
		UiDraw.rounded(self, Rect2(edge_x, 10, 6, size.y - 20), accent, 3)
		var pc := Vector2(size.x - 46.0, size.y * 0.5) if foe else Vector2(46.0, size.y * 0.5)
		draw_circle(pc, PORTRAIT_R, accent.darkened(0.55))
		draw_arc(pc, PORTRAIT_R, 0.0, TAU, 40, accent.lightened(0.2), 2.0, true)
		var sp := body.mon.species
		var icon := PokemonSprites.disc_icon(sp, int(PORTRAIT_R * 2.0))
		if icon:
			var t := PokemonSprites.tint(sp)
			if not body.alive():
				t = Color(0.35, 0.35, 0.35)
			draw_texture_rect(
				icon,
				Rect2(pc - Vector2(PORTRAIT_R, PORTRAIT_R), Vector2(PORTRAIT_R, PORTRAIT_R) * 2.0),
				false,
				t
			)
		var x0 := 16.0 if foe else 98.0
		var x1 := size.x - 98.0 if foe else size.x - 16.0
		var tf := UiDraw.title_font()
		drawn_name = body.mon.display_name
		var lv := "Lv %d" % (script_level if script_xp >= 0.0 and script_level > 0 else body.level)
		var lvw := UiDraw.text_width(lv, 18, tf)
		if foe:
			UiDraw.text(
				self,
				Vector2(x0, NAME_Y),
				drawn_name,
				24,
				UiDraw.COL_WHITE,
				4,
				HORIZONTAL_ALIGNMENT_RIGHT,
				x1 - x0,
				tf
			)
			UiDraw.text(
				self,
				Vector2(x0, NAME_Y),
				lv,
				18,
				UiDraw.AMBER,
				4,
				HORIZONTAL_ALIGNMENT_LEFT,
				-1.0,
				tf
			)
		else:
			UiDraw.text(
				self,
				Vector2(x0, NAME_Y),
				drawn_name,
				24,
				UiDraw.COL_WHITE,
				4,
				HORIZONTAL_ALIGNMENT_LEFT,
				-1.0,
				tf
			)
			UiDraw.text(
				self,
				Vector2(x1 - lvw, NAME_Y),
				lv,
				18,
				UiDraw.AMBER,
				4,
				HORIZONTAL_ALIGNMENT_LEFT,
				-1.0,
				tf
			)
		_draw_chips(x0, x1, types)
		UiDraw.bar(
			self,
			Rect2(x0, HP_ROW_Y, HP_W, HP_H),
			_hp_ratio,
			UiDraw.hp_color(_hp_ratio),
			_ghost,
			Color(1, 1, 1, 0.75),
			foe
		)
		if foe:
			return
		var hp_s := "%d / %d" % [body.hp, body.max_hp]
		UiDraw.text(
			self,
			Vector2(x1 - UiDraw.text_width(hp_s, 13), CHIP_Y + 14.0),
			hp_s,
			13,
			Color(1, 1, 1, 0.85),
			3
		)
		var base := maxf(body.pp_base, 1.0)
		UiDraw.bar(
			self,
			Rect2(x0, PP_ROW_Y, PP_W, 6),
			maxf(body.stamina, 0.0) / base,
			UiDraw.PP_BLUE if body.stagger_t <= 0.0 else Color(1.0, 0.6, 0.2),
			body.pp_max / base,
			Color(0.2, 0.3, 0.55)
		)
		UiDraw.bar(
			self,
			Rect2(x0 + PP_W + 6.0, PP_ROW_Y, EXP_W, 6),
			_exp_ratio(),
			UiDraw.AMBER,
			-1.0,
			Color(1, 1, 1, 0.75),
			false,
			UiDraw.EXP_TRACK
		)

	func _draw_chips(x0: float, x1: float, types: Array) -> void:
		var gap := 5.0
		var st := String(body.status)
		var tx := x0
		if foe:
			var w := 0.0
			for t in types:
				w += UiDraw.type_pill_width(String(t), 10) + gap
			w += UiDraw.status_pill_width(st, 10) + gap
			tx = maxf(x1 - w - 60.0, x0 + UiDraw.text_width(tag, 10) + 8.0)
		for t in types:
			tx += (
				UiDraw.type_pill(
					self, Vector2(tx, CHIP_Y), String(t), Dex.type_color(String(t)), 10
				)
				+ gap
			)
		var sw := UiDraw.status_pill(self, Vector2(tx, CHIP_Y), st, 10)
		if sw > 0.0:
			tx += sw + gap
		if body.confusion_t > 0.0:
			tx += UiDraw.status_pill(self, Vector2(tx, CHIP_Y), "confusion", 10) + gap
		var cw := UiDraw.mod_chips(
			self,
			Vector2(tx, CHIP_Y),
			body.stages,
			body.evasion_t > 0.0,
			10,
			x1 if foe else x1 - 60.0
		)
		chips = Rect2(tx, CHIP_Y, cw, 16.0) if cw > 0.0 else Rect2()
		tx += cw
		if body.stagger_t > 0.0:
			UiDraw.text(
				self, Vector2(tx + 2, CHIP_Y + 14.0), "EXAUSTO", 11, Color(1, 0.55, 0.35), 3
			)
		if foe:
			UiDraw.text(self, Vector2(x0, CHIP_Y + 13.0), tag, 10, Color(1, 1, 1, 0.45), 0)
			var bx := x0 + UiDraw.text_width(tag, 10) + 8.0
			for i in balls.size():
				UiDraw.ball(
					self,
					Vector2(bx + 5 + i * 13.0, CHIP_Y + 8.0),
					5.0,
					Color(0.89, 0.21, 0.17),
					not bool(balls[i])
				)


class AllyCard:
	extends Control
	var body: BattleFighter
	var mode := ""

	func _draw() -> void:
		if body == null:
			return
		var r := Rect2(Vector2.ZERO, size)
		UiDraw.rounded(self, Rect2(r.position + Vector2(0, 3), r.size), Color(0, 0, 0, 0.3), 12)
		UiDraw.glass(self, r, 0.7, 12)
		var icon := PokemonSprites.icon_fitted(body.mon.species, 32)
		if icon:
			draw_texture_rect(icon, Rect2(6, 4, 32, 32), false)
		var tf := UiDraw.title_font()
		UiDraw.text(
			self,
			Vector2(44, 18),
			body.mon.display_name,
			16,
			UiDraw.COL_WHITE,
			3,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1.0,
			tf
		)
		UiDraw.text(
			self,
			Vector2(size.x - 12 - UiDraw.text_width("Lv %d" % body.level, 13, tf), 18),
			"Lv %d" % body.level,
			13,
			UiDraw.AMBER,
			3,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1.0,
			tf
		)
		if mode != "":
			UiDraw.text(self, Vector2(160, 18), mode, 11, Color(1, 1, 1, 0.6), 2)
		var ratio := float(body.hp) / maxf(body.max_hp, 1)
		UiDraw.bar(self, Rect2(44, 26, size.x - 58, 7), ratio, UiDraw.hp_color(ratio))


class MoveButton:
	extends Control
	const NAME_W := 62.0
	var index := 0
	var body: BattleFighter
	var _fits := {}  # nome -> [linhas, tamanho] (o botão redesenha todo quadro)

	func _wrap(nm: String, fs: int) -> Array:
		var lines: Array = []
		var cur := ""
		for w in nm.split(" ", false):
			var cand := String(w) if cur == "" else cur + " " + String(w)
			if cur != "" and UiDraw.text_width(cand, fs, UiDraw.title_font()) > NAME_W:
				lines.append(cur)
				cur = String(w)
			else:
				cur = cand
		if cur != "":
			lines.append(cur)
		return lines

	func _fit(nm: String) -> Array:
		if not _fits.has(nm):
			_fits[nm] = _fit_now(nm)
		return _fits[nm]

	func _fit_now(nm: String) -> Array:
		var fs := 16
		while fs > 10:
			var lines := _wrap(nm, fs)
			var ok := lines.size() <= 2
			for l in lines:
				if UiDraw.text_width(String(l), fs, UiDraw.title_font()) > NAME_W:
					ok = false
			if ok:
				return [lines, fs]
			fs -= 1
		return [_wrap(nm, 10), 10]

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.5
		draw_circle(c + Vector2(0, 3), r, Color(0, 0, 0, 0.35))
		var has := body != null and index < body.moves.size()
		if not has:
			draw_circle(c, r, Color(UiDraw.INK, 0.55))
			draw_arc(c, r - 2.0, 0.0, TAU, 48, Color(UiDraw.PAPER, 0.25), 2.0, true)
			UiDraw.key_pill(self, c + Vector2(-r + 6.0, -r + 6.0), str(index + 1), 22, true)
			UiDraw.text_center(self, Vector2(c.x, c.y + 6.0), "—", 16, Color(1, 1, 1, 0.3), 0)
			return
		var id := String(body.moves[index])
		var mv := Dex.move(id)
		var tcol := Dex.type_color(String(mv.get("type", "normal")))
		var cost := Dex.pp_cost(mv)
		var afford := body.pp_max >= cost
		var tired := body.stamina < Dex.fatigue(mv)
		draw_circle(c, r, Color(UiDraw.INK, 0.88) if afford else Color(0.1, 0.1, 0.12, 0.92))
		draw_arc(c, r - 2.0, 0.0, TAU, 48, tcol, 3.5, true)
		var cd := float(body.move_cd.get(id, 0.0))
		var use_gcd := body.gcd_t > cd
		if use_gcd:
			cd = body.gcd_t
		var nm := String(mv.get("name", id))
		var name_col := (
			Color(1, 1, 1, 0.35) if cd > 0.0 else (Color.WHITE if afford else Color(1, 1, 1, 0.4))
		)
		var tf := UiDraw.title_font()
		if cd > 0.0:
			var s := nm
			while s.length() > 1 and UiDraw.text_width(s + "…", 11, tf) > r * 1.32:
				s = s.substr(0, s.length() - 1)
			if s != nm:
				s += "…"
			UiDraw.text_center(self, Vector2(c.x, c.y - 18.0), s, 11, name_col, 3, tf)
		else:
			var fit := _fit(nm)
			var lines: Array = fit[0]
			var fs: int = fit[1]
			var lh := float(fs) * 1.05
			var y := c.y - 8.0 - (lines.size() - 1) * lh * 0.5 + fs * 0.35
			for l in lines:
				UiDraw.text_center(self, Vector2(c.x, y), String(l), fs, name_col, 3, tf)
				y += lh
		var cost_col := UiDraw.PP_BLUE
		if not afford:
			cost_col = Color(1, 0.4, 0.35)
		elif tired:
			cost_col = Color(1, 0.7, 0.3)
		UiDraw.text_center(
			self, Vector2(c.x, c.y + r - 14.0), "%d PP" % int(round(cost)), 12, cost_col, 3
		)
		UiDraw.key_pill(self, c + Vector2(-r + 6.0, -r + 6.0), str(index + 1), 22, not afford)
		if cd > 0.0:
			var total := (
				(Dex.GLOBAL_COOLDOWN if use_gcd else Dex.cooldown(mv))
				/ maxf(body.speed_factor(), 0.01)
			)
			draw_circle(c, r - 2.0, Color(0, 0, 0, 0.55 * clampf(cd / maxf(total, 0.01), 0.0, 1.0)))
			UiDraw.text_center(
				self, Vector2(c.x, c.y + 6.0), "%.1f" % cd, 20, Color(1, 1, 1, 0.95), 4
			)
		if body.prepare_id == id and body.prepare_t > 0.0:
			var pf := 1.0 - clampf(body.prepare_t / maxf(Dex.prepare_time(mv), 0.01), 0.0, 1.0)
			draw_circle(c, r - 2.0, Color(1, 1, 1, 0.2 * pf))


class BannerPill:
	extends Control
	var text := ""
	var t := 0.0
	var _a := 0.0

	func show_text(s: String, secs: float) -> void:
		text = s
		t = secs
		_a = 0.0

	func step(dt: float) -> void:
		if t > 0.0:
			t -= dt
			_a = minf(_a + dt / 0.2, 1.0)
		queue_redraw()

	func _draw() -> void:
		if t <= 0.0 or text == "":
			return
		var a := _a * clampf(t / 0.3, 0.0, 1.0)
		var tf := UiDraw.title_font()
		var fs := 30
		var w := minf(UiDraw.text_width(text, fs, tf) + 56.0, size.x)
		var r := Rect2(Vector2(size.x * 0.5 - w * 0.5, size.y * 0.5 - 24.0), Vector2(w, 48.0))
		UiDraw.rounded(
			self, Rect2(r.position + Vector2(0, 3), r.size), Color(0, 0, 0, 0.35 * a), 16
		)
		UiDraw.rounded(self, r, Color(UiDraw.INK, 0.82 * a), 16)
		UiDraw.text_center(
			self,
			Vector2(size.x * 0.5, size.y * 0.5 + fs * 0.34),
			text,
			fs,
			Color(UiDraw.PAPER, a),
			4,
			tf
		)


class IntroLayer:
	extends Control
	const BAR_H := 72.0
	var want := 0.0
	var h := 0.0
	var _flash_text := ""
	var _flash_t := -1.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func flash(s: String) -> void:
		_flash_text = s
		_flash_t = 0.0

	func step(dt: float) -> void:
		h = move_toward(h, want, dt / 0.35)
		if _flash_t >= 0.0:
			_flash_t += dt
			if _flash_t > 1.1:
				_flash_t = -1.0
		queue_redraw()

	func _draw() -> void:
		var bh := BAR_H * ease(h, 0.4)
		if bh > 0.5:
			draw_rect(Rect2(0, 0, size.x, bh), Color(0.02, 0.02, 0.03, 0.92))
			draw_rect(Rect2(0, size.y - bh, size.x, bh), Color(0.02, 0.02, 0.03, 0.92))
		if _flash_t < 0.0:
			return
		var t := _flash_t
		var sc := lerpf(1.8, 1.0, clampf(t / 0.22, 0.0, 1.0))
		var a := clampf(t / 0.12, 0.0, 1.0) * clampf((1.1 - t) / 0.3, 0.0, 1.0)
		var tf := UiDraw.title_font()
		var fs := 110
		var w := UiDraw.text_width(_flash_text, fs, tf)
		draw_set_transform(size * 0.5, 0.0, Vector2(sc, sc))
		draw_string_outline(
			tf,
			Vector2(-w * 0.5, fs * 0.35),
			_flash_text,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			fs,
			18,
			Color(0, 0, 0, 0.9 * a)
		)
		draw_string(
			tf,
			Vector2(-w * 0.5, fs * 0.35),
			_flash_text,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			fs,
			Color(1.0, 0.82, 0.25, a)
		)
		draw_set_transform(Vector2.ZERO)


## Popup de batalha (porte do Pop do fx_popups.gd): número de dano creme, CRÍTICO/SUPEREFETIVO,
## estágios com setas, "Errou!" com riscos de velocidade, chamadas com pílula.
class Pop:
	extends Control
	const LIFE := {
		"damage": 0.75,
		"crit": 0.8,
		"super": 0.8,
		"weak": 0.7,
		"stat_up": 0.85,
		"stat_down": 0.85,
		"status": 0.85,
		"move": 0.6,
		"callout": 1.0,
		"miss": 0.65,
		"dodge": 0.8,
		"interrupted": 0.8,
		"heal": 0.75,
		"info": 0.8
	}
	const SKEW := -0.2
	const CREAM := Color(0.957, 0.922, 0.765)
	const CRIT_TXT := Color(1.0, 0.95, 0.65)

	var world := Vector3.ZERO
	var text := ""
	var col := Color.WHITE
	var scale_k := 1.0
	var style := "info"
	var life := 0.8
	var age := 0.0
	var jitter := 0.0
	var stack := 0.0
	var screen := Vector2.ZERO

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_place()

	func step(dt: float) -> void:
		age += dt
		if age >= life:
			queue_free()
			return
		_place()
		modulate.a = clampf((life - age) / 0.16, 0.0, 1.0)
		queue_redraw()

	func _place() -> void:
		var cam := get_viewport().get_camera_3d()
		if cam == null or cam.is_position_behind(world):
			visible = false
			return
		visible = true
		screen = cam.unproject_position(world)
		var rise := (30.0 if style == "damage" else 18.0) * ease(clampf(age / life, 0.0, 1.0), 0.4)
		var side := Vector2(46.0, 0.0) if style == "callout" else Vector2.ZERO
		position = screen + Vector2(jitter, stack - rise) + side
		position.y = maxf(position.y, 116.0)

	func _fs() -> int:
		match style:
			"damage":
				return 50 if scale_k > 1.45 else 40
			"weak":
				return 20
			"callout":
				return 26
		return 24

	func text_height() -> float:
		return (
			UiDraw.heavy_font().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, _fs()).y
			* minf(scale_k, 1.5)
		)

	func _scale() -> float:
		if age < 0.07:
			return lerpf(0.3, 1.25, age / 0.07)
		if age < 0.14:
			return lerpf(1.25, 1.0, (age - 0.07) / 0.07)
		return 1.0

	func _draw() -> void:
		var s := _scale() * (1.0 if style == "damage" else minf(scale_k, 1.3))
		var origin := Vector2.ZERO
		if style != "callout" and style != "move":
			origin.y = -6.0 - s * (_fs() * 0.36 + UiDraw.heavy_font().get_descent(_fs()))
		draw_set_transform_matrix(Transform2D(Vector2(s, 0), Vector2(SKEW * s, s), origin))
		match style:
			"damage":
				var crit := scale_k > 1.45
				_text(text, 50 if crit else 40, CRIT_TXT if crit else CREAM, 12)
			"crit":
				_text(text, 24, Color(1.0, 0.85, 0.2))
			"super":
				_text(text, 24, Color(1.0, 0.78, 0.15))
			"weak":
				_text(text, 20, Color(0.72, 0.74, 0.8))
			"stat_up":
				_stat(UiDraw.COL_BUFF, true)
			"stat_down":
				_stat(UiDraw.COL_DEBUFF, false)
			"miss", "dodge":
				_speed(text)
			"move", "callout":
				_pill(text, col)
			_:
				_text(text, 24, col)

	func _line(pos: Vector2, t: String, fs: int, c: Color, outline := 8) -> void:
		var f := UiDraw.heavy_font()
		draw_string_outline(
			f,
			pos + Vector2(0, 4),
			t,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			fs,
			outline,
			Color(0, 0, 0, 0.85)
		)
		draw_string(
			f, pos + Vector2(0, 4), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0, 0, 0, 0.85)
		)
		draw_string_outline(
			f, pos, t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, outline, Color(0, 0, 0, 0.92)
		)
		draw_string(f, pos, t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, c)

	func _text(t: String, fs: int, c: Color, outline := 8) -> void:
		var w := UiDraw.heavy_font().get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		_line(Vector2(-w * 0.5, fs * 0.36), t, fs, c, outline)

	func _stat(c: Color, up: bool) -> void:
		var fs := 22
		var tw := UiDraw.heavy_font().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var tri := fs * 0.62
		var x := -(tw + tri + 6.0) * 0.5
		_line(Vector2(x, fs * 0.36), text, fs, c)
		var p := Vector2(x + tw + 6.0, 0)
		var pts := (
			PackedVector2Array(
				[
					p + Vector2(0, tri * 0.45),
					p + Vector2(tri, tri * 0.45),
					p + Vector2(tri * 0.5, -tri * 0.45)
				]
			)
			if up
			else PackedVector2Array(
				[
					p + Vector2(0, -tri * 0.45),
					p + Vector2(tri, -tri * 0.45),
					p + Vector2(tri * 0.5, tri * 0.45)
				]
			)
		)
		draw_polyline(pts + PackedVector2Array([pts[0]]), Color(0, 0, 0, 0.92), 5.0, true)
		draw_colored_polygon(pts, c)

	func _speed(t: String) -> void:
		var fs := 24
		var w := UiDraw.heavy_font().get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		for i in 3:
			var y := -8.0 + i * 8.0
			draw_line(
				Vector2(-w * 0.5 - 26, y),
				Vector2(-w * 0.5 - 6 - i * 3, y),
				Color(0.85, 0.92, 1.0, 0.9),
				3.0
			)
		_text(t, fs, Color.WHITE)

	func _pill(t: String, c: Color) -> void:
		var fs := 20
		var w := UiDraw.text_width(t, fs, UiDraw.title_font()) + 26.0
		var h := fs + 12.0
		var r := Rect2(-w * 0.5, -h * 0.5, w, h)
		UiDraw.rounded(
			self, Rect2(r.position + Vector2(0, 3), r.size), Color(0, 0, 0, 0.4), h * 0.5
		)
		UiDraw.rounded(self, r, Color(UiDraw.INK, 0.86), h * 0.5, 2.0, Color(c, 0.9))
		UiDraw.text(
			self,
			Vector2(-w * 0.5 + 13, fs * 0.36),
			t,
			fs,
			c.lightened(0.2),
			3,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1.0,
			UiDraw.title_font()
		)


## Faixa de log da batalha (porte do battle_log.gd do original): pílula escura no topo, uma linha (a última),
## marca de cor por tipo e, no resultado do fim, a dica de tecla para continuar.
class BattleLogLine:
	extends Control
	const MAX_ENTRIES := 8
	const MAX_W := 560.0
	const PAD := 14.0
	const CHIP := 4.0
	const CHIP_GAP := 8.0
	const H := 32.0
	const TOP := 116.0
	const FONT_SIZE := 18
	const APPEAR := 0.25

	var entries: Array = []
	var hint_glyph := ""
	var hint_text := ""
	var hidden_by_banner := false
	var _age := APPEAR
	var _a := 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func push(text: String, kind := "info") -> void:
		entries.append({"text": text, "kind": kind})
		while entries.size() > MAX_ENTRIES:
			entries.pop_front()
		_age = 0.0
		queue_redraw()

	func last_text() -> String:
		return String(entries[-1].text) if not entries.is_empty() else ""

	func step(dt: float) -> void:
		_age += dt
		var want := 0.0 if hidden_by_banner or entries.is_empty() else 1.0
		_a = move_toward(_a, want, dt / 0.25)
		queue_redraw()

	static func chip_color(kind: String) -> Color:
		match kind:
			"exp":
				return UiDraw.PP_BLUE
			"level", "money":
				return UiDraw.AMBER
			"faint":
				return UiDraw.RED
			"catch", "item":
				return UiDraw.GREEN
			"move":
				return UiDraw.PAPER
			"trainer":
				return UiDraw.RED.lightened(0.35)
		return UiDraw.DIM

	func _fit(s: String) -> String:
		if UiDraw.text_width(s, FONT_SIZE) <= MAX_W:
			return s
		while s.length() > 1 and UiDraw.text_width(s + "…", FONT_SIZE) > MAX_W:
			s = s.substr(0, s.length() - 1)
		return s + "…"

	func _draw() -> void:
		if entries.is_empty() or _a <= 0.01:
			return
		var s := _fit(last_text())
		var a := _a * (0.55 + 0.45 * clampf(_age / APPEAR, 0.0, 1.0))
		var hint_w := 0.0
		if hint_text != "":
			hint_w = UiDraw.text_width(hint_text, 14) + 40.0
		var w := minf(UiDraw.text_width(s, FONT_SIZE) + PAD * 2.0 + CHIP + CHIP_GAP, MAX_W) + hint_w
		var x := size.x * 0.5 - w * 0.5
		var y := size.y * 0.5 - H * 0.5
		UiDraw.rounded(self, Rect2(x, y, w, H), Color(UiDraw.INK, 0.88 * a), 16)
		draw_rect(
			Rect2(x + PAD, y + 8.0, CHIP, H - 16.0), Color(chip_color(String(entries[-1].kind)), a)
		)
		UiDraw.text(
			self,
			Vector2(x + PAD + CHIP + CHIP_GAP, y + H * 0.5 + 6.0),
			s,
			FONT_SIZE,
			Color(UiDraw.PAPER, a),
			3
		)
		if hint_text != "":
			var hx := x + w - PAD - UiDraw.text_width(hint_text, 14)
			UiDraw.key_pill(self, Vector2(hx - 16.0, y + H * 0.5), hint_glyph, 18)
			UiDraw.text(
				self, Vector2(hx, y + H * 0.5 + 5.0), hint_text, 14, Color(UiDraw.PAPER, a), 3
			)
