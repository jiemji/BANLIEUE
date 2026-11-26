## Modale de gestion des 3 emplacements de sauvegarde manuels (Cassettes A, B, C) avec affichage du Scénario associé.
extends Control

signal slot_saved(slot_idx: int)
signal slot_loaded(slot_idx: int)
signal closed

var _mode: String = "load" # "load" | "save"
var _lbl_title: Label = null
var _lbl_feedback: Label = null
var _slots_box: VBoxContainer = null

var _confirm_overlay: ColorRect = null
var _lbl_confirm: Label = null
var _pending_action: String = ""
var _pending_slot: int = 0

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()
	visible = false

func _make_style(bg: Color, border: Color, border_w: int = 2, pad: int = 16) -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_w)
	sb.set_content_margin_all(pad)
	return sb

func _build_ui() -> void:
	var bg_shade: ColorRect = ColorRect.new()
	bg_shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg_shade.color = Color(0.03, 0.03, 0.05, 0.80)
	add_child(bg_shade)

	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = Vector2(820, 560)
	panel.add_theme_stylebox_override("panel", _make_style(Color(0.08, 0.08, 0.10, 0.97), Color(0.85, 0.17, 0.17), 3, 22))
	center.add_child(panel)

	var vb: VBoxContainer = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	panel.add_child(vb)

	_lbl_title = Label.new()
	_lbl_title.text = "CHARGER UNE PARTIE"
	_lbl_title.add_theme_font_size_override("font_size", 22)
	_lbl_title.add_theme_color_override("font_color", Color(0.95, 0.55, 0.16))
	vb.add_child(_lbl_title)

	var lbl_sub: Label = Label.new()
	lbl_sub.text = "3 emplacements manuels — Cassettes TDK (sauvegarde du scénario en cours et import inter-scénarios)."
	lbl_sub.add_theme_font_size_override("font_size", 12)
	lbl_sub.add_theme_color_override("font_color", Color(0.76, 0.78, 0.82))
	vb.add_child(lbl_sub)

	_slots_box = VBoxContainer.new()
	_slots_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_slots_box.add_theme_constant_override("separation", 10)
	vb.add_child(_slots_box)

	var footer: HBoxContainer = HBoxContainer.new()
	footer.add_theme_constant_override("separation", 12)
	vb.add_child(footer)

	_lbl_feedback = Label.new()
	_lbl_feedback.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lbl_feedback.add_theme_font_size_override("font_size", 12)
	_lbl_feedback.add_theme_color_override("font_color", Color(0.32, 0.68, 0.95))
	footer.add_child(_lbl_feedback)

	var btn_close: Button = Button.new()
	btn_close.text = "◄ Fermer [Échap]"
	btn_close.custom_minimum_size = Vector2(150, 38)
	btn_close.pressed.connect(func() -> void:
		AudioRadio.play_cassette_click()
		close_panel()
		closed.emit()
	)
	footer.add_child(btn_close)

	# Confirmation intégrée
	_confirm_overlay = ColorRect.new()
	_confirm_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_confirm_overlay.color = Color(0.02, 0.02, 0.04, 0.78)
	_confirm_overlay.visible = false
	add_child(_confirm_overlay)

	var c_center: CenterContainer = CenterContainer.new()
	c_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_confirm_overlay.add_child(c_center)

	var c_panel: PanelContainer = PanelContainer.new()
	c_panel.custom_minimum_size = Vector2(460, 175)
	c_panel.add_theme_stylebox_override("panel", _make_style(Color(0.09, 0.09, 0.12), Color(0.95, 0.55, 0.16), 3, 20))
	c_center.add_child(c_panel)

	var c_vb: VBoxContainer = VBoxContainer.new()
	c_vb.add_theme_constant_override("separation", 16)
	c_panel.add_child(c_vb)

	_lbl_confirm = Label.new()
	_lbl_confirm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lbl_confirm.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_lbl_confirm.add_theme_font_size_override("font_size", 14)
	_lbl_confirm.add_theme_color_override("font_color", Color(0.96, 0.94, 0.88))
	c_vb.add_child(_lbl_confirm)

	var c_row: HBoxContainer = HBoxContainer.new()
	c_row.alignment = BoxContainer.ALIGNMENT_END
	c_row.add_theme_constant_override("separation", 12)
	c_vb.add_child(c_row)

	var btn_no: Button = Button.new()
	btn_no.text = "Annuler"
	btn_no.custom_minimum_size = Vector2(110, 36)
	btn_no.pressed.connect(close_confirm)
	c_row.add_child(btn_no)

	var btn_yes: Button = Button.new()
	btn_yes.text = "Confirmer"
	btn_yes.custom_minimum_size = Vector2(120, 36)
	btn_yes.pressed.connect(_on_confirm_yes)
	c_row.add_child(btn_yes)

## Ouvre la modale des 3 cassettes en mode "load" ou "save" et reconstruit les cartes d'état.
func open_panel(mode: String) -> void:
	_mode = "save" if mode == "save" else "load"
	_lbl_title.text = "SAUVEGARDER LA PARTIE" if _mode == "save" else "CHARGER UNE PARTIE"
	_lbl_feedback.text = ""
	close_confirm()
	_rebuild_slots()
	visible = true

## Ferme la modale et toute confirmation en cours.
func close_panel() -> void:
	close_confirm()
	visible = false

## Indique si une boîte de confirmation (écrasement, chargement ou suppression) est ouverte.
func has_confirm_open() -> bool:
	return _confirm_overlay != null and _confirm_overlay.visible

## Ferme la boîte de confirmation sans appliquer l'opération en attente.
func close_confirm() -> void:
	if _confirm_overlay != null:
		_confirm_overlay.visible = false
	_pending_action = ""
	_pending_slot = 0

func _rebuild_slots() -> void:
	for child in _slots_box.get_children():
		child.queue_free()

	for slot_idx in range(1, SaveManager.SLOT_COUNT + 1):
		var meta: Dictionary = SaveManager.read_slot_meta(slot_idx)
		var is_empty: bool = meta.is_empty()
		var slot_label: String = SaveManager.get_slot_label(slot_idx)

		var card: PanelContainer = PanelContainer.new()
		card.custom_minimum_size = Vector2(0, 114)
		var border_col: Color = Color(0.95, 0.55, 0.16) if not is_empty else Color(0.28, 0.30, 0.35)
		card.add_theme_stylebox_override("panel", _make_style(Color(0.11, 0.11, 0.14), border_col, 2, 12))
		_slots_box.add_child(card)

		var hbox: HBoxContainer = HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 14)
		card.add_child(hbox)

		# Portrait miniature
		var thumb_frame: PanelContainer = PanelContainer.new()
		thumb_frame.custom_minimum_size = Vector2(82, 82)
		thumb_frame.add_theme_stylebox_override("panel", _make_style(Color(0.07, 0.07, 0.09), Color(0.32, 0.34, 0.38), 1, 2))
		hbox.add_child(thumb_frame)

		var port_path: String = str(meta.get("portrait_path", ""))
		var tex: Texture2D = DataLoader.load_texture_safe(port_path) if (not is_empty and port_path != "") else null
		if tex != null:
			var tr: TextureRect = TextureRect.new()
			tr.texture = tex
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			tr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			tr.size_flags_vertical = Control.SIZE_EXPAND_FILL
			thumb_frame.add_child(tr)
		else:
			var empty_lbl: Label = Label.new()
			empty_lbl.text = "TDK\nC-60"
			empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			empty_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			empty_lbl.add_theme_font_size_override("font_size", 11)
			empty_lbl.add_theme_color_override("font_color", Color(0.55, 0.58, 0.64))
			thumb_frame.add_child(empty_lbl)

		# Infos cassette
		var info_vb: VBoxContainer = VBoxContainer.new()
		info_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info_vb.add_theme_constant_override("separation", 4)
		hbox.add_child(info_vb)

		var top_row: HBoxContainer = HBoxContainer.new()
		info_vb.add_child(top_row)

		var lbl_slot: Label = Label.new()
		var scen_tag: String = (" — « %s »%s" % [
			str(meta.get("scenario_title", "")),
			(" [Terminé ★]" if bool(meta.get("scenario_completed", false)) else "")
		]) if not is_empty else ""
		lbl_slot.text = slot_label.to_upper() + scen_tag
		lbl_slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl_slot.add_theme_font_size_override("font_size", 13)
		lbl_slot.add_theme_color_override("font_color", Color(0.95, 0.55, 0.16))
		top_row.add_child(lbl_slot)

		var lbl_date: Label = Label.new()
		lbl_date.text = SaveManager.format_saved_at(str(meta.get("saved_at", ""))) if not is_empty else ""
		lbl_date.add_theme_font_size_override("font_size", 11)
		lbl_date.add_theme_color_override("font_color", Color(0.68, 0.72, 0.78))
		top_row.add_child(lbl_date)

		var lbl_main: Label = Label.new()
		lbl_main.add_theme_font_size_override("font_size", 15)
		if is_empty:
			lbl_main.text = "— Emplacement vierge —"
			lbl_main.add_theme_color_override("font_color", Color(0.60, 0.62, 0.68))
		else:
			lbl_main.text = "%s · %s" % [str(meta.get("leader_name", "Alex")), str(meta.get("archetype_title", ""))]
			lbl_main.add_theme_color_override("font_color", Color(0.96, 0.94, 0.88))
		info_vb.add_child(lbl_main)

		var lbl_det: Label = Label.new()
		lbl_det.add_theme_font_size_override("font_size", 12)
		lbl_det.add_theme_color_override("font_color", Color(0.78, 0.82, 0.88))
		if is_empty:
			lbl_det.text = "Clique sur Sauvegarder pour enregistrer la partie en cours." if _mode == "save" else "Aucune donnée enregistrée sur cette cassette."
		else:
			var ph: String = str(meta.get("phase", "day"))
			var ph_lbl: String = "NUIT" if ph == "night" else ("CRÉPUSCULE" if ph == "twilight" else "JOUR")
			lbl_det.text = "%s  |  %s · %s  |  %d membres · %d F" % [
				str(meta.get("location_name", "")),
				ph_lbl,
				str(meta.get("clock_text", "")),
				int(meta.get("squad_count", 3)),
				int(meta.get("francs", 0))
			]
		info_vb.add_child(lbl_det)

		# Boutons d'action
		var act_vb: VBoxContainer = VBoxContainer.new()
		act_vb.alignment = BoxContainer.ALIGNMENT_CENTER
		act_vb.add_theme_constant_override("separation", 6)
		hbox.add_child(act_vb)

		var idx_cap: int = slot_idx
		var btn_primary: Button = Button.new()
		btn_primary.custom_minimum_size = Vector2(138, 36)
		if _mode == "save":
			btn_primary.text = "Sauvegarder" if is_empty else "Écraser"
			btn_primary.pressed.connect(func() -> void: _on_save_clicked(idx_cap, not is_empty))
		else:
			btn_primary.text = "Charger"
			btn_primary.disabled = is_empty
			btn_primary.pressed.connect(func() -> void: _on_load_clicked(idx_cap))
		act_vb.add_child(btn_primary)

		var btn_del: Button = Button.new()
		btn_del.text = "Effacer"
		btn_del.custom_minimum_size = Vector2(138, 28)
		btn_del.visible = not is_empty
		btn_del.pressed.connect(func() -> void: _on_delete_clicked(idx_cap))
		act_vb.add_child(btn_del)

func _on_save_clicked(slot_idx: int, occupied: bool) -> void:
	AudioRadio.play_cassette_click()
	if occupied:
		_pending_action = "save"
		_pending_slot = slot_idx
		_lbl_confirm.text = "Enregistrer par-dessus %s ?\nL'ancienne sauvegarde sur cette cassette sera remplacée." % SaveManager.get_slot_label(slot_idx)
		_confirm_overlay.visible = true
	else:
		_perform_save(slot_idx)

func _on_load_clicked(slot_idx: int) -> void:
	AudioRadio.play_cassette_click()
	if GameState.has_active_session:
		_pending_action = "load"
		_pending_slot = slot_idx
		_lbl_confirm.text = "Charger %s ?\nLa progression non sauvegardée de la session en cours sera perdue." % SaveManager.get_slot_label(slot_idx)
		_confirm_overlay.visible = true
	else:
		_perform_load(slot_idx)

func _on_delete_clicked(slot_idx: int) -> void:
	AudioRadio.play_cassette_click()
	_pending_action = "delete"
	_pending_slot = slot_idx
	_lbl_confirm.text = "Effacer définitivement %s ?" % SaveManager.get_slot_label(slot_idx)
	_confirm_overlay.visible = true

func _on_confirm_yes() -> void:
	var act: String = _pending_action
	var slot_idx: int = _pending_slot
	close_confirm()
	AudioRadio.play_cassette_click()
	if act == "save":
		_perform_save(slot_idx)
	elif act == "load":
		_perform_load(slot_idx)
	elif act == "delete":
		if SaveManager.delete_slot(slot_idx):
			_lbl_feedback.text = "%s effacée." % SaveManager.get_slot_label(slot_idx)
			_rebuild_slots()

func _perform_save(slot_idx: int) -> void:
	if SaveManager.save_slot(slot_idx):
		_lbl_feedback.text = "Partie enregistrée sur %s !" % SaveManager.get_slot_label(slot_idx)
		_rebuild_slots()
		slot_saved.emit(slot_idx)
	else:
		_lbl_feedback.text = "Erreur lors de la sauvegarde sur %s." % SaveManager.get_slot_label(slot_idx)

func _perform_load(slot_idx: int) -> void:
	if SaveManager.load_slot(slot_idx):
		close_panel()
		slot_loaded.emit(slot_idx)
	else:
		_lbl_feedback.text = "Impossible de lire %s." % SaveManager.get_slot_label(slot_idx)
