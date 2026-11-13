class_name ShineButton
extends BaseButton
## Botão de papel recortado com o "plin": no hover cresce, troca de cor e uma barra branca
## cruza da esquerda pra direita. No clique afunda na direção da sombra.
## Formato: `shape` (frações do tamanho) ou, se vazio, um retângulo inclinado em `skew` graus.

var text := "": set = _redraw_s
var font_px := 16
var fill := Paper.GOLD
var fill_hover := Paper.CREAM
var fg := Paper.INK
var fg_hover := Paper.INK
var border := 3.0
var skew := 10.0
var shape: Array = []
## -1 = seta pra esquerda, 1 = pra direita, 0 = sem seta. Com texto, a seta vai antes dele.
var chevron := 0
var chevron_px := 20.0
var text_rot := 0.0
## Rosto (seletor de herói): a textura ocupa o miolo e acende no hover.
var texture: Texture2D
## Rosto mais apagado (tank que não está na party).
var dim := false
## Pulsa parado e solta o brilho sozinho a cada `idle_every` segundos (READY FOR BATTLE).
var idle := false
var idle_every := 3.2
var hover_scale := 1.08

var _shine := -1.0
var _hot := false
var _tw: Tween
var _clock := 0.0
var _home := Vector2.ZERO
var _home_set := false
var _base_rot := 0.0


func _redraw_s(v: String) -> void:
	text = v
	queue_redraw()


func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	pivot_offset = size * 0.5
	_base_rot = rotation
	mouse_entered.connect(_on_hover.bind(true))
	mouse_exited.connect(_on_hover.bind(false))
	button_down.connect(_on_press.bind(true))
	button_up.connect(_on_press.bind(false))
	set_process(true)


func _on_hover(on: bool) -> void:
	_hot = on
	if on:
		_shine = 0.0
	_to(Vector2.ONE * (hover_scale if on else 1.0), Vector2.ZERO, 0.14)
	queue_redraw()


func _on_press(on: bool) -> void:
	if on:
		_to(Vector2.ONE * 0.94, Vector2(2, 3), 0.08)
	else:
		_to(Vector2.ONE * (hover_scale if _hot else 1.0), Vector2.ZERO, 0.14)


func _to(sc: Vector2, off: Vector2, t: float) -> void:
	if not _home_set:
		_home = position
		_home_set = true
	if _tw != null:
		_tw.kill()
	_tw = create_tween().set_parallel(true)
	_tw.tween_property(self, "scale", sc, t).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tw.tween_property(self, "position", _home + off, t)


func _process(delta: float) -> void:
	if _shine >= 0.0:
		_shine += delta / 0.45
		if _shine >= 1.0:
			_shine = -1.0
		queue_redraw()
	if idle and is_visible_in_tree():
		_clock += delta
		if _hot or button_pressed:
			rotation = _base_rot
		else:
			# respira: 1 -> 1.03 e uma inclinada de 0,6 grau, num ciclo de 1,6 s
			var k := 0.5 - 0.5 * cos(TAU * _clock / 1.6)
			if _tw == null or not _tw.is_running():
				scale = Vector2.ONE * (1.0 + 0.03 * k)
			rotation = _base_rot + deg_to_rad(-0.6) * k
			if fmod(_clock, idle_every) < delta and _shine < 0.0:
				_shine = 0.0


func _outline() -> PackedVector2Array:
	return Paper.poly(size, shape) if shape.size() > 0 else Paper.skew_rect(size, skew)


func _has_point(p: Vector2) -> bool:
	return Geometry2D.is_point_in_polygon(p, _outline())


func _draw() -> void:
	var pts := _outline()
	var inner := Paper.inset(pts, border)
	draw_colored_polygon(pts, Paper.INK)
	if texture != null:
		var r := Rect2(Vector2(border, border), size - Vector2(border, border) * 2.0)
		draw_texture_rect(texture, r, false, Color(1, 1, 1, 1.0 if _hot else (0.28 if dim else 0.6)))
	else:
		draw_colored_polygon(inner, fill_hover if _hot else fill)
	var col := fg_hover if _hot else fg
	var f := Paper.display()
	var tw := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_px).x if text != "" else 0.0
	var cw := chevron_px * 0.55 if chevron != 0 else 0.0
	var gap := 6.0 if (text != "" and chevron != 0) else 0.0
	var x := (size.x - (tw + cw + gap)) * 0.5
	var cy := size.y * 0.5
	if text_rot != 0.0:
		draw_set_transform(size * 0.5, deg_to_rad(text_rot), Vector2.ONE)
		x -= size.x * 0.5
		cy = 0.0
	if chevron != 0:
		var h := chevron_px * 0.375
		var a := Vector2(x + (cw if chevron < 0 else 0.0), cy - h)
		var m := Vector2(x + (0.0 if chevron < 0 else cw), cy)
		var b := Vector2(x + (cw if chevron < 0 else 0.0), cy + h)
		draw_polyline(PackedVector2Array([a, m, b]), col, chevron_px * 0.21, true)
		x += cw + gap
	if text != "":
		draw_string(f, Vector2(x, cy + f.get_ascent(font_px) * 0.5 - f.get_descent(font_px) * 0.5), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_px, col)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if _shine >= 0.0:
		# o brilho: uma barra inclinada, recortada no formato do botão
		var w := size.x
		var left := lerpf(-0.6 * w, 1.6 * w, _shine)
		var d := tan(deg_to_rad(22.0)) * size.y * 0.8
		var bar := PackedVector2Array([Vector2(left + d, -size.y * 0.3), Vector2(left + d + 0.28 * w, -size.y * 0.3), Vector2(left - d + 0.28 * w, size.y * 1.3), Vector2(left - d, size.y * 1.3)])
		for piece in Geometry2D.intersect_polygons(bar, inner):
			draw_colored_polygon(piece, Color(1, 1, 1, 0.8))
