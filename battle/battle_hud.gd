class_name BattleHUD
extends CanvasLayer
## HUD da batalha no visual do original (ui/battle_hud.gd + fx_popups.gd + battle_intro.gd):
## cartões de lutador (retrato, nome, Lv, tipos, status, HP com rastro, PP, EXP), cartão do aliado,
## golpes em losango, banner em pílula, faixas de introdução + "Lutem!", popups de dano em tela e menu rápido.
## API usada pela arena: banner(text, secs), refresh(player, enemy, dt, ally, info), add_popup(...), intro_bars(on), fight_flash().

## Os quatro cartões da dupla têm o mesmo tamanho: desenhados no tamanho de projeto e reduzidos por escala.
const CARD_DESIGN_W := 506.0
const CARD_DESIGN_H := 92.0
const CARD_K := 0.8
const CARD_W := CARD_DESIGN_W * CARD_K
const CARD_H := CARD_DESIGN_H * CARD_K
const CARD_MARGIN := 14.0
const CARD_TOP := 12.0
## Espaço para a faixa de marcas/estágios entre os cartões empilhados (coluna da esquerda e da direita).
const ROW_GAP := 24.0
const MOVE_R := 42.0
const MOVE_DX := 92.0
const MOVE_DY := 68.0
const DIAMOND_AT := Vector2(-182.0, -134.0)
const BAR_H := 72.0
const HELP := "WASD anda  Shift corre  Espaço pula  1-4 golpes  E bolsa  Tab troca  F aliado  Q bola  Esc pausa"
const PAUSE_W := 300.0
## Pílulas de modo (OFENSIVO..LIVRE) em coluna ao lado do cartão: fora do meio da tela, sem tapar a luta.
const MODE_W := 84.0
const MODE_H := 16.0
const MODE_GAP := 2.0
const MODE_X := CARD_MARGIN + CARD_W + 8.0

## Clique numa pílula de modo: slot "player"/"ally", mode = índice em BattleHUD.arena_script().ALLY_MODE_NAMES.
signal mode_clicked(slot: String, mode: int)

var _root: Control
var _player_card: FighterCard
var _foe_card: FighterCard
var _foe2_card: FighterCard
var _viva: VivaLayer
var _ally_card: FighterCard
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
var _mode_btns := {"player": [], "ally": []}


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
	# Dupla em 2x2: direita os adversários (topo e abaixo), esquerda o jogador e o aliado.
	_foe_card = FighterCard.new()
	_foe_card.foe = true
	_place_card(
		_foe_card, Vector2(1, 0), Vector2(-CARD_MARGIN - CARD_W * 0.5, CARD_TOP + CARD_H * 0.5)
	)
	_foe2_card = FighterCard.new()
	_foe2_card.foe = true
	_place_card(
		_foe2_card,
		Vector2(1, 0),
		Vector2(-CARD_MARGIN - CARD_W * 0.5, CARD_TOP + CARD_H * 1.5 + ROW_GAP)
	)
	_player_card = FighterCard.new()
	_place_card(
		_player_card, Vector2(0, 0), Vector2(CARD_MARGIN + CARD_W * 0.5, CARD_TOP + CARD_H * 0.5)
	)
	_ally_card = FighterCard.new()
	_place_card(
		_ally_card,
		Vector2(0, 0),
		Vector2(CARD_MARGIN + CARD_W * 0.5, CARD_TOP + CARD_H * 1.5 + ROW_GAP)
	)
	_make_mode_buttons("player", CARD_TOP)
	_make_mode_buttons("ally", CARD_TOP + CARD_H + ROW_GAP)
	var offs := [
		Vector2(0, MOVE_DY), Vector2(MOVE_DX, 0), Vector2(-MOVE_DX, 0), Vector2(0, -MOVE_DY)
	]
	for i in 4:
		var b := MoveButton.new()
		b.index = i
		_place(b, Vector2(1, 1), Vector2(MOVE_R, MOVE_R) * 2.0, DIAMOND_AT + offs[i])
		_moves.append(b)
	_banner = BannerPill.new()
	# Avisos grandes ("vai mandar", desmaiou) embaixo, no lugar do log (o meio fica para a luta).
	_place(
		_banner,
		Vector2(0.5, 1),
		Vector2(900, 64),
		Vector2(0, -BattleLogLine.BOTTOM - BattleLogLine.H * 0.5)
	)
	_help = Label.new()
	_help.anchor_top = 1.0
	_help.anchor_bottom = 1.0
	_help.offset_left = 16
	_help.offset_top = -30
	_help.offset_right = 760
	_help.add_theme_font_override("font", UiDraw.font())
	_help.add_theme_font_size_override("font_size", 12)
	_help.add_theme_constant_override("outline_size", 4)
	_help.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_help.modulate = Color(1, 1, 1, 0.8)
	_help.text = HELP
	_root.add_child(_help)
	_menu_bg = PanelContainer.new()
	_menu_bg.offset_left = CARD_MARGIN
	_menu_bg.offset_top = CARD_TOP + CARD_H * 2.0 + ROW_GAP + 6.0
	var msb := UiDraw.glass_box(0.86, 12)
	msb.set_content_margin_all(12)
	_menu_bg.add_theme_stylebox_override("panel", msb)
	_menu = Label.new()
	_menu.add_theme_font_override("font", UiDraw.font())
	_menu.add_theme_font_size_override("font_size", 13)
	_menu_bg.add_child(_menu)
	_menu_bg.visible = false
	_root.add_child(_menu_bg)
	_log = BattleLogLine.new()
	# Embaixo no meio: no alto ela cobria o cartão do 2º adversário na dupla.
	_place(
		_log,
		Vector2(0.5, 1),
		Vector2(BattleLogLine.MAX_W + 220.0, BattleLogLine.H),
		Vector2(0, -BattleLogLine.BOTTOM - BattleLogLine.H * 0.5)
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
	_pause.add_theme_font_size_override("font_size", 16)
	_pause.add_theme_constant_override("line_spacing", 6)
	_pause_bg.add_child(_pause)
	_pause_bg.visible = false
	_root.add_child(_pause_bg)
	_viva = VivaLayer.new()
	_root.add_child(_viva)
	_viva.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


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


## A arena não tem class_name (e carrega o HUD): o script dela só é lido na hora de usar, sem preload circular.
static func arena_script() -> GDScript:
	return load("res://battle/battle_arena.gd")


func _make_mode_buttons(slot: String, top: float) -> void:
	for i in BattleHUD.arena_script().ALLY_MODE_NAMES.size():
		var b := ModeButton.new()
		b.slot = slot
		b.mode = i
		b.hud = self
		_root.add_child(b)
		b.offset_left = MODE_X
		b.offset_right = MODE_X + MODE_W
		b.offset_top = top + i * (MODE_H + MODE_GAP)
		b.offset_bottom = b.offset_top + MODE_H
		b.visible = false
		_mode_btns[slot].append(b)


## Cartão reduzido por CARD_K: a origem fica no canto de cima à esquerda (pivô padrão), então o centro visual é `center`.
func _place_card(c: Control, anchor: Vector2, center: Vector2) -> void:
	_root.add_child(c)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.scale = Vector2.ONE * CARD_K
	c.anchor_left = anchor.x
	c.anchor_right = anchor.x
	c.anchor_top = anchor.y
	c.anchor_bottom = anchor.y
	c.offset_left = center.x - CARD_W * 0.5
	c.offset_right = c.offset_left + CARD_DESIGN_W
	c.offset_top = center.y - CARD_H * 0.5
	c.offset_bottom = c.offset_top + CARD_DESIGN_H


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


## "Batalha Viva": balão grande com o nome do golpe, do lado do usuário (1.0 s). Novo substitui o do lado.
func callout(f: BattleFighter, text: String, col: Color) -> void:
	if is_instance_valid(f):
		_viva.add_callout(f.side, text, col)


## Faixa diagonal de impacto ("NOCAUTE!", "CRÍTICO!"); a arena congela a luta, o HUD só desenha.
func cut_in(text: String, col: Color, secs := 0.4) -> void:
	_viva.start_cut(text, col, secs)


## Popup grande central (reações, golpes de dupla), 0.8 s.
func combo(text: String, col: Color) -> void:
	_viva.start_combo(text, col)


## Aviso curto embaixo da arena, acima da faixa de log (CLASH, Ressonância, reações): não cobre a luta.
func warn(text: String, col: Color) -> void:
	_viva.add_warn(text, col)


func warn_text() -> String:
	return _viva.warn_text()


## Faixa "[Pokémon] — [HABILIDADE]" do lado do lutador (1.2 s).
func ability_banner(f: BattleFighter, ability_name: String) -> void:
	if is_instance_valid(f):
		_viva.add_ability(f.side, "%s — %s" % [f.mon.display_name, ability_name])


func callout_text(side: int) -> String:
	return _viva.callout_text(side)


func cut_in_text() -> String:
	return _viva.cut_text()


func ability_text(side: int) -> String:
	return _viva.ability_text(side)


func sync_shown(side: int) -> float:
	return _viva.sync_shown[clampi(side, 0, 1)]


## info: {ally_mode, item_cd, menu, foe_tag, foe_balls: Array[bool]}.
func refresh(
	player: BattleFighter, enemy: BattleFighter, dt: float, ally: BattleFighter = null, info := {}
) -> void:
	_banner.step(dt)
	_intro.step(dt)
	_viva.step(dt, info.get("sync", [0.0, 0.0]))
	# A faixa de log some enquanto a pílula de banner (abertura, troca do treinador) está no mesmo lugar.
	_log.hidden_by_banner = _banner.t > 0.0
	_log.step(dt)
	# a pílula fica exatamente onde está o log (o treino sobe o log acima do painel) e o log some na hora
	var mid := (_log.offset_top + _log.offset_bottom) * 0.5
	_banner.offset_top = mid - 32.0
	_banner.offset_bottom = mid + 32.0
	_log.visible = _banner.t <= 0.0
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
	var foe2: Variant = info.get("foe2")
	_foe2_card.body = foe2 if is_instance_valid(foe2) and foe2.active() else null
	_foe2_card.tag = _foe_card.tag
	var cmds: Dictionary = info.get("commands", {})
	var obey: Dictionary = info.get("obey", {})
	var marks: Dictionary = info.get("marks", {})
	_player_card.cmd = String(cmds.get("player", ""))
	_player_card.obey = bool(obey.get("player", true))
	_ally_card.cmd = String(cmds.get("ally", ""))
	_ally_card.obey = bool(obey.get("ally", true))
	_ally_card.visible = has_ally
	# Resultado do fim: a barra de EXP do cartão enche sob o controle da arena (begin_scripted/fill_to).
	var xs: Dictionary = info.get("exp_script", {})
	for c in [_player_card, _foe_card, _foe2_card, _ally_card]:
		c.script_xp = -1.0
		if not xs.is_empty() and c.body != null and c.body.mon == xs.get("mon"):
			c.script_xp = float(xs.xp)
			c.script_level = int(xs.level)
		c.visible = c.body != null
		c.marks = _marks_of(marks, c.body)
		c.step(dt)
	var cur := {"player": _player_card.cmd, "ally": _ally_card.cmd}
	var shown := {"player": _player_card.body != null, "ally": has_ally}
	for slot in _mode_btns:
		for b in _mode_btns[slot]:
			b.visible = shown[slot]
			b.current = cur[slot] == BattleHUD.arena_script().ALLY_MODE_NAMES[b.mode]
			b.queue_redraw()
	var icd := float(info.get("item_cd", 0.0))
	_help.text = HELP + ("   item %.1fs" % icd if icd > 0.0 else "")
	var mt := String(info.get("menu", ""))
	_menu_bg.visible = mt != ""
	_menu.text = mt
	for b in _moves:
		b.body = player if is_instance_valid(player) else null
		b.visible = b.body != null and bool(info.get("show_moves", true))
		b.queue_redraw()


func _marks_of(marks: Dictionary, f: BattleFighter) -> Array:
	if f == null:
		return []
	return marks.get(f.get_instance_id(), [])


func mode_buttons_visible(slot: String) -> bool:
	var l: Array = _mode_btns.get(slot, [])
	return not l.is_empty() and l[0].visible


func mode_button_rect(slot: String, mode: int) -> Rect2:
	var l: Array = _mode_btns.get(slot, [])
	if mode < 0 or mode >= l.size():
		return Rect2()
	return Rect2(l[mode].position, l[mode].size)


## Nome do modo destacado ("" se nenhum).
func highlighted_mode(slot: String) -> String:
	for b in _mode_btns.get(slot, []):
		if b.current:
			return BattleHUD.arena_script().ALLY_MODE_NAMES[b.mode]
	return ""


## Simula o clique numa pílula.
func press_mode(slot: String, mode: int) -> void:
	if (
		_mode_btns.has(slot)
		and mode >= 0
		and mode < BattleHUD.arena_script().ALLY_MODE_NAMES.size()
	):
		mode_clicked.emit(slot, mode)


## Para testes: o que os cartões mostram.
func card_text(which := "player") -> String:
	var c: FighterCard = _player_card
	if which == "foe":
		c = _foe_card
	elif which == "foe2":
		c = _foe2_card
	return c.body.mon.display_name if c.body != null and c.visible else ""


## Retângulos em tela para o holofote do tutorial (battle_hud.gd do original).
func card_rect(which: String) -> Rect2:
	var c: Control = _foe_card if which == "foe" else _player_card
	if which == "ally":
		c = _ally_card
	elif which == "foe2":
		c = _foe2_card
	return Rect2(c.position, c.size * c.scale) if c else Rect2()


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
	return (
		Rect2(_foe_card.position + c.position * CARD_K, c.size * CARD_K)
		if c.size.x > 0.0
		else Rect2()
	)


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
	var cmd := ""
	var obey := true
	## Modo do aliado ("OFENSIVO"...), escrito ao lado do nome; vazio no lutador controlado e nos adversários.
	var mode := ""
	var marks: Array = []
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
		VivaTags.draw_strip(self, body, 98.0 if not foe else 16.0, size, marks, cmd, obey, foe)
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
		var lvw := UiDraw.text_width(lv, 15, tf)
		if foe:
			UiDraw.text(
				self,
				Vector2(x0, NAME_Y),
				drawn_name,
				20,
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
				15,
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
				20,
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
				15,
				UiDraw.AMBER,
				4,
				HORIZONTAL_ALIGNMENT_LEFT,
				-1.0,
				tf
			)
			if mode != "":
				var mx := x0 + UiDraw.text_width(drawn_name, 20, tf) + 10.0
				UiDraw.text(self, Vector2(mx, NAME_Y), mode, 10, Color(1, 1, 1, 0.6), 3)
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
			Vector2(x1 - UiDraw.text_width(hp_s, 11), CHIP_Y + 14.0),
			hp_s,
			11,
			Color(1, 1, 1, 0.85),
			3
		)
		var base := maxf(body.pp_base, 1.0)
		UiDraw.bar(self, Rect2(x0, PP_ROW_Y, PP_W, 6), body.pp_max / base, UiDraw.PP_BLUE)
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
		if body.seeded:  # Leech Seed é volátil (convive com o status principal)
			tx += UiDraw.status_pill(self, Vector2(tx, CHIP_Y), "leech", 10) + gap
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


class ModeButton:
	extends Control
	var slot := ""
	var mode := 0
	var current := false
	var hud: BattleHUD

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		focus_mode = Control.FOCUS_NONE
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			accept_event()
			hud.mode_clicked.emit(slot, mode)

	func _draw() -> void:
		var col: Color = BattleHUD.arena_script().ALLY_MODE_COLORS[mode]
		var r := Rect2(Vector2.ZERO, size)
		if current:
			UiDraw.rounded(self, r, Color(col, 0.85), 8.0, 1.0, Color(1, 1, 1, 0.7))
		else:
			UiDraw.rounded(self, r, Color(UiDraw.INK, 0.55), 8.0, 1.0, Color(col, 0.35))
		var tc := Color(0.08, 0.08, 0.1) if current else Color(col, 0.9)
		UiDraw.text_center(
			self,
			Vector2(size.x * 0.5, size.y - 4.0),
			BattleHUD.arena_script().ALLY_MODE_NAMES[mode],
			10,
			tc,
			0
		)


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
		var fs := 14
		while fs > 9:
			var lines := _wrap(nm, fs)
			var ok := lines.size() <= 2
			for l in lines:
				if UiDraw.text_width(String(l), fs, UiDraw.title_font()) > NAME_W:
					ok = false
			if ok:
				return [lines, fs]
			fs -= 1
		return [_wrap(nm, 9), 9]

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
		var cost: float = body.pp_cost_of(mv)
		var afford := body.pp_max >= cost
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
			UiDraw.text_center(self, Vector2(c.x, c.y - 18.0), s, 10, name_col, 3, tf)
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
		UiDraw.text_center(
			self, Vector2(c.x, c.y + r - 14.0), "%d PP" % int(round(cost)), 10, cost_col, 3
		)
		UiDraw.key_pill(self, c + Vector2(-r + 6.0, -r + 6.0), str(index + 1), 22, not afford)
		if cd > 0.0:
			var total := (
				(Dex.GLOBAL_COOLDOWN if use_gcd else Dex.cooldown(mv))
				/ maxf(body.speed_factor(), 0.01)
			)
			draw_circle(c, r - 2.0, Color(0, 0, 0, 0.55 * clampf(cd / maxf(total, 0.01), 0.0, 1.0)))
			UiDraw.text_center(
				self, Vector2(c.x, c.y + 6.0), "%.1f" % cd, 16, Color(1, 1, 1, 0.95), 4
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
		var fs := 18
		var w := minf(UiDraw.text_width(text, fs, tf) + 56.0, size.x)
		var r := Rect2(Vector2(size.x * 0.5 - w * 0.5, size.y * 0.5 - 20.0), Vector2(w, 40.0))
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
		var fs := 84
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
		# "Interrompido!" sai junto do número de dano: fica embaixo dele.
		if style == "interrupted":
			side = Vector2(0.0, 40.0)
		position = screen + Vector2(jitter, stack - rise) + side
		# Fica abaixo dos cartões: os da direita (adversários) descem mais na dupla.
		var vw := get_viewport_rect().size.x
		var lim := 116.0
		if position.x > vw - CARD_MARGIN - CARD_W - 60.0:
			lim = CARD_TOP + CARD_H * 2.0 + ROW_GAP + 16.0
		elif position.x < CARD_MARGIN + CARD_W + 60.0:
			lim = CARD_TOP + CARD_H * 2.0 + ROW_GAP + 16.0
		position.y = maxf(position.y, lim)

	func _fs() -> int:
		match style:
			"damage":
				return 40 if scale_k > 1.45 else 30
			"weak":
				return 16
			"callout":
				return 20
		return 19

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
				_text(text, 40 if crit else 30, CRIT_TXT if crit else CREAM, 12)
			"crit":
				_text(text, 19, Color(1.0, 0.85, 0.2))
			"super":
				_text(text, 19, Color(1.0, 0.78, 0.15))
			"weak":
				_text(text, 16, Color(0.72, 0.74, 0.8))
			"stat_up":
				_stat(UiDraw.COL_BUFF)
			"stat_down":
				_stat(UiDraw.COL_DEBUFF)
			"miss", "dodge":
				_speed(text)
			"move", "callout":
				_pill(text, col)
			_:
				_text(text, 19, col)

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

	## Mudança de stat: "+1 ATK" / "-2 DEF" (sinal e sigla de 3 letras, sem seta).
	func _stat(c: Color) -> void:
		_text(text, 16, c)

	func _speed(t: String) -> void:
		var fs := 18
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
		var fs := 15
		var w := UiDraw.text_width(t, fs, UiDraw.title_font()) + 22.0
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
	const BOTTOM := 96.0  # acima da barra de status e do "Parar (Esc)" do treino
	const FONT_SIZE := 15
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
			hint_w = UiDraw.text_width(hint_text, 12) + 40.0
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
			var hx := x + w - PAD - UiDraw.text_width(hint_text, 12)
			UiDraw.key_pill(self, Vector2(hx - 16.0, y + H * 0.5), hint_glyph, 18)
			UiDraw.text(
				self, Vector2(hx, y + H * 0.5 + 5.0), hint_text, 12, Color(UiDraw.PAPER, a), 3
			)


## Etiqueta de comando, chips de marcas e tags de estágio dos cartões ("Batalha Viva").
class VivaTags:
	const CMD_COL := {
		"OFENSIVO": Color(0.91, 0.35, 0.28),
		"DEFENSIVO": Color(0.3, 0.55, 0.92),
		"SUPORTE": Color(0.3, 0.7, 0.4),
		"LIVRE": Color(0.6, 0.63, 0.68)
	}
	const STAGE_TAG := {
		"atk": "ATK", "def": "DEF", "spa": "SPA", "spd": "SPD", "spe": "SPE", "acc": "ACC"
	}
	const FS := 10
	const H := 14.0
	const ICON := 12.0
	const CMD_ICON := {
		"OFENSIVO": "cmd_ofensivo",
		"DEFENSIVO": "cmd_defensivo",
		"SUPORTE": "cmd_suporte",
		"LIVRE": "cmd_livre"
	}

	## Sigla de 3 letras de um stat ("atk" -> "ATK"), para os popups de mudança e os chips.
	static func short_stat(k: String) -> String:
		return STAGE_TAG.get(k, k.to_upper())

	## Tags "+2 ATK" a partir de f.stages (≠ 0): [{text, up}].
	static func stage_tags(f: BattleFighter) -> Array:
		var out: Array = []
		for k in STAGE_TAG:
			var v := int(f.stages.get(k, 0))
			if v != 0:
				out.append({"text": stage_text(k, v), "up": v > 0})
		return out

	static func stage_text(k: String, v: int) -> String:
		return "%s%d %s" % ["+" if v > 0 else "-", absi(v), short_stat(k)]

	## Chip de texto; `icon` = nome em assets/pixellab/icons (sem o arquivo, só o texto).
	static func chip(
		ci: CanvasItem, pos: Vector2, s: String, col: Color, filled := false, icon := ""
	) -> float:
		var tex: Texture2D = PixelFx.icon(icon) if icon != "" else null
		var ix := (ICON + 2.0) if tex else 0.0
		var w := UiDraw.text_width(s, FS) + 10.0 + ix
		var r := Rect2(pos, Vector2(w, H))
		UiDraw.rounded(
			ci, r, Color(col, 0.9) if filled else Color(UiDraw.INK, 0.9), H * 0.5, 1.5, col
		)
		if tex:
			ci.draw_texture_rect(
				tex, Rect2(pos + Vector2(4.0, (H - ICON) * 0.5), Vector2(ICON, ICON)), false
			)
		UiDraw.text(
			ci,
			pos + Vector2(5.0 + ix, H - 3.5),
			s,
			FS,
			UiDraw.INK if filled else col.lightened(0.25),
			0
		)
		return w + 4.0

	static func draw_strip(
		ci: CanvasItem,
		f: BattleFighter,
		x0: float,
		card: Vector2,
		marks: Array,
		cmd: String,
		obey: bool,
		_foe: bool
	) -> void:
		# O comando abre a fileira de baixo do cartão (no alto ele saía cortado na borda da tela).
		var x := x0
		var y := card.y - 1.0
		if cmd != "":
			var c: Color = CMD_COL.get(cmd, CMD_COL["LIVRE"])
			x += chip(
				ci,
				Vector2(x, y),
				cmd + ("" if obey else " ?"),
				c,
				true,
				String(CMD_ICON.get(cmd, "cmd_livre"))
			)
		for m in marks:
			var col: Variant = m.get("color", Color.WHITE)
			x += chip(
				ci,
				Vector2(x, y),
				String(m.get("name", m.get("id", ""))),
				col if col is Color else Color.WHITE,
				false,
				"mark_" + String(m.get("id", ""))
			)
		# os estágios já aparecem como chips dentro do cartão; aqui só o que o cartão não mostra (ACC)
		for k in STAGE_TAG:
			var v := int(f.stages.get(k, 0))
			if v == 0 or UiDraw.STAGE_SHORT.has(k):
				continue
			x += chip(
				ci, Vector2(x, y), stage_text(k, v), UiDraw.COL_BUFF if v > 0 else UiDraw.COL_DEBUFF
			)


## Camada de efeitos de tela: sintonia, balões de golpe, faixas de habilidade, cut-in e combo.
class VivaLayer:
	extends Control
	const CALLOUT_LIFE := 1.0
	const ABILITY_LIFE := 1.2
	const COMBO_LIFE := 0.8
	const WARN_LIFE := 1.0
	const SKEW := -0.2

	var sync_shown := [0.0, 0.0]
	var _sync := [0.0, 0.0]
	var _time := 0.0
	var _callouts := [{}, {}]
	var _abilities := [{}, {}]
	var _cut := {}
	var _combo := {}
	var _warn := {}

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func add_callout(side: int, text: String, col: Color) -> void:
		_callouts[clampi(side, 0, 1)] = {"text": text, "col": col, "age": 0.0}

	func add_ability(side: int, text: String) -> void:
		_abilities[clampi(side, 0, 1)] = {"text": text, "age": 0.0}

	func add_warn(text: String, col: Color) -> void:
		_warn = {"text": text, "col": col, "age": 0.0}

	func start_cut(text: String, col: Color, secs: float) -> void:
		_cut = {"text": text, "col": col, "age": 0.0, "life": maxf(secs, 0.05)}

	func start_combo(text: String, col: Color) -> void:
		_combo = {"text": text, "col": col, "age": 0.0}

	func callout_text(side: int) -> String:
		var c: Dictionary = _callouts[clampi(side, 0, 1)]
		return String(c.get("text", ""))

	func warn_text() -> String:
		return String(_warn.get("text", ""))

	func ability_text(side: int) -> String:
		var c: Dictionary = _abilities[clampi(side, 0, 1)]
		return String(c.get("text", ""))

	func cut_text() -> String:
		return String(_cut.get("text", ""))

	func _age(d: Dictionary, life: float, dt: float) -> Dictionary:
		if d.is_empty():
			return d
		d.age += dt
		return {} if d.age >= life else d

	func step(dt: float, sync: Array) -> void:
		_time += dt
		for i in 2:
			_callouts[i] = _age(_callouts[i], CALLOUT_LIFE, dt)
			_abilities[i] = _age(_abilities[i], ABILITY_LIFE, dt)
			_sync[i] = clampf(float(sync[i]) if sync.size() > i else 0.0, 0.0, 1.0)
			sync_shown[i] = move_toward(sync_shown[i], _sync[i], dt * 2.5)
		_combo = _age(_combo, COMBO_LIFE, dt)
		_warn = _age(_warn, WARN_LIFE, dt)
		_cut = _age(_cut, float(_cut.get("life", 0.4)), dt)
		queue_redraw()

	func _big(pos: Vector2, t: String, fs: int, c: Color, outline := 10) -> void:
		var f := UiDraw.heavy_font()
		draw_string_outline(
			f, pos, t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, outline, Color(0, 0, 0, 0.9)
		)
		draw_string(f, pos, t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, c)

	func _wid(t: String, fs: int) -> float:
		return UiDraw.heavy_font().get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x

	func _draw() -> void:
		_draw_sync()
		for i in 2:
			_draw_ability(i)
		for i in 2:
			_draw_callout(i)
		_draw_warn()
		_draw_combo()
		_draw_cut()

	func _draw_sync() -> void:
		for i in 2:
			var v: float = sync_shown[i]
			if v <= 0.01:
				continue
			var full: bool = v >= 0.999
			var w := BattleHUD.CARD_W
			var x := BattleHUD.CARD_MARGIN if i == 0 else size.x - BattleHUD.CARD_MARGIN - w
			var h := 4.0 + (2.0 * (0.5 + 0.5 * sin(_time * 14.0)) if full else 0.0)
			var col := UiDraw.AMBER if full else UiDraw.PP_BLUE
			if full:
				col = col.lightened(0.3 * (0.5 + 0.5 * sin(_time * 14.0)))
			UiDraw.rounded(self, Rect2(x, 4.0, w, h), Color(0, 0, 0, 0.45), 2)
			UiDraw.rounded(self, Rect2(x, 4.0, w * v, h), col, 2)
			var ic: Texture2D = PixelFx.icon("sync")
			if ic:
				var ix := maxf(x, x + w * v - 8.0)
				draw_texture_rect(ic, Rect2(ix, 4.0 + h * 0.5 - 8.0, 16.0, 16.0), false)
			if full and fmod(_time, 0.5) < 0.32:
				# Embaixo da arena, com os avisos, e não sobre a luta: a barra do jogador à esquerda, a do adversário à direita.
				var by := size.y - BattleHUD.BattleLogLine.BOTTOM - BattleHUD.BattleLogLine.H - 34.0
				var bx := x if i == 0 else x + w - UiDraw.text_width("SINTONIA!", 12)
				UiDraw.text(self, Vector2(bx, by), "SINTONIA!", 12, UiDraw.AMBER, 3)

	func _draw_callout(side: int) -> void:
		var c: Dictionary = _callouts[side]
		if c.is_empty():
			return
		var age: float = c.age
		var fs := 20
		var t: String = c.text
		var col: Color = c.col
		var w := _wid(t, fs) + 44.0
		var k := ease(clampf(age / 0.16, 0.0, 1.0), 0.3)
		var a := clampf((CALLOUT_LIFE - age) / 0.2, 0.0, 1.0)
		var sc := lerpf(1.35, 1.0, k)
		# Menor e longe dos cartões: o do jogador acima da faixa de log, o do adversário abaixo dos cartões.
		var y := size.y - 175.0 if side == 0 else CARD_TOP + CARD_H * 2.0 + ROW_GAP + 28.0
		var x := 28.0 if side == 0 else size.x - 28.0 - w
		x += (1.0 - k) * (-260.0 if side == 0 else 260.0)
		draw_set_transform(Vector2(x + w * 0.5, y), 0.0, Vector2(sc, sc))
		var sk := 12.0
		var pts := PackedVector2Array(
			[
				Vector2(-w * 0.5 + sk, -20),
				Vector2(w * 0.5 + sk, -20),
				Vector2(w * 0.5 - sk, 20),
				Vector2(-w * 0.5 - sk, 20)
			]
		)
		var shadow := pts.duplicate()
		for i in shadow.size():
			shadow[i] += Vector2(0, 5)
		draw_colored_polygon(shadow, Color(0, 0, 0, 0.4 * a))
		draw_colored_polygon(pts, Color(UiDraw.INK, 0.92 * a))
		draw_polyline(pts + PackedVector2Array([pts[0]]), Color(col, a), 4.0, true)
		draw_set_transform_matrix(
			Transform2D(Vector2(sc, 0), Vector2(SKEW * sc, sc), Vector2(x + w * 0.5, y))
		)
		_big(Vector2(-_wid(t, fs) * 0.5, fs * 0.35), t, fs, Color(col.lightened(0.55), a), 8)
		draw_set_transform(Vector2.ZERO)

	func _draw_ability(side: int) -> void:
		var c: Dictionary = _abilities[side]
		if c.is_empty():
			return
		var age: float = c.age
		var t: String = c.text
		var fs := 18
		var tf := UiDraw.title_font()
		var w := UiDraw.text_width(t, fs, tf) + 44.0
		var k := ease(clampf(age / 0.2, 0.0, 1.0), 0.3)
		var a := clampf((ABILITY_LIFE - age) / 0.25, 0.0, 1.0)
		var y := size.y * 0.5 + 40.0 if side == 0 else size.y * 0.5 - 100.0
		var home := 0.0 if side == 0 else size.x - w
		var from := -w if side == 0 else size.x
		var r := Rect2(lerpf(from, home, k), y, w, 36.0)
		UiDraw.rounded(self, Rect2(r.position + Vector2(0, 3), r.size), Color(0, 0, 0, 0.35 * a), 8)
		UiDraw.rounded(self, r, Color(UiDraw.INK, 0.9 * a), 8, 2.0, Color(UiDraw.AMBER, 0.9 * a))
		UiDraw.text(
			self,
			r.position + Vector2(22.0, 25.0),
			t,
			fs,
			Color(UiDraw.PAPER, a),
			4,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1.0,
			tf
		)

	func _draw_warn() -> void:
		if _warn.is_empty():
			return
		var t: String = _warn.text
		var col: Color = _warn.col
		var age: float = _warn.age
		var fs := 15
		var tf := UiDraw.title_font()
		var a := clampf((WARN_LIFE - age) / 0.25, 0.0, 1.0) * clampf(age / 0.1, 0.0, 1.0)
		var w := UiDraw.text_width(t, fs, tf) + 36.0
		var h := 28.0
		var x := size.x * 0.5 - w * 0.5
		var y := size.y - BattleHUD.BattleLogLine.BOTTOM - BattleHUD.BattleLogLine.H - 34.0 - h
		UiDraw.rounded(self, Rect2(x, y + 3.0, w, h), Color(0, 0, 0, 0.35 * a), h * 0.5)
		UiDraw.rounded(
			self, Rect2(x, y, w, h), Color(UiDraw.INK, 0.88 * a), h * 0.5, 2.0, Color(col, a)
		)
		UiDraw.text(
			self,
			Vector2(x + 18.0, y + h * 0.5 + fs * 0.36),
			t,
			fs,
			Color(col.lightened(0.3), a),
			3,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1.0,
			tf
		)

	func _draw_combo() -> void:
		if _combo.is_empty():
			return
		var age: float = _combo.age
		var t: String = _combo.text
		var col: Color = _combo.col
		var sc := 1.0
		if age < 0.1:
			sc = lerpf(0.4, 1.25, age / 0.1)
		elif age < 0.2:
			sc = lerpf(1.25, 1.0, (age - 0.1) / 0.1)
		var a := clampf((COMBO_LIFE - age) / 0.2, 0.0, 1.0)
		var fs := 50
		draw_set_transform_matrix(
			Transform2D(Vector2(sc, 0), Vector2(SKEW * sc, sc), Vector2(size.x * 0.5, size.y * 0.4))
		)
		_big(Vector2(-_wid(t, fs) * 0.5, fs * 0.35), t, fs, Color(col, a), 14)
		draw_set_transform(Vector2.ZERO)

	func _draw_cut() -> void:
		if _cut.is_empty():
			return
		var age: float = _cut.age
		var life: float = _cut.life
		var col: Color = _cut.col
		var t: String = _cut.text
		var k := ease(clampf(age / 0.1, 0.0, 1.0), 0.3)
		var a := clampf((life - age) / 0.08, 0.0, 1.0)
		draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.3 * a))
		var c := size * 0.5
		var ang := -0.2
		var bw := size.length() * 1.2
		var bh := 170.0 * k
		draw_set_transform(c, ang, Vector2.ONE)
		draw_rect(Rect2(-bw * 0.5, -bh * 0.5 - 8.0, bw, bh + 16.0), Color(1, 1, 1, 0.9 * a))
		draw_rect(Rect2(-bw * 0.5, -bh * 0.5, bw, bh), Color(col.darkened(0.45), a))
		# Linhas de velocidade correndo pela faixa.
		for i in 16:
			var ly := -bh * 0.5 + fmod(float(i) * 37.0, bh)
			var len_px := 160.0 + fmod(float(i) * 71.0, 240.0)
			var lx := fmod(float(i) * 233.0 + _time * 2600.0, bw + len_px) - bw * 0.5 - len_px
			draw_line(Vector2(lx, ly), Vector2(lx + len_px, ly), Color(1, 1, 1, 0.45 * a), 3.0)
		var fs := 80
		var shake := Vector2(sin(age * 90.0), cos(age * 70.0)) * 3.0 * (1.0 - k)
		var slide := (1.0 - k) * -420.0
		_big(Vector2(-_wid(t, fs) * 0.5 + slide, fs * 0.35) + shake, t, fs, Color(1, 1, 1, a), 16)
		draw_set_transform(Vector2.ZERO)
