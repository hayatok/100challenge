extends RefCounted
## Harbor logbook surfaces. Buttons dispatch pure rules actions through Main.
const Data = preload("res://scripts/rules.gd")
const Palette = preload("res://scripts/ui_theme.gd")

static func build(body: VBoxContainer, state: Dictionary, page: String, host: Control) -> void:
	if not host.harbor_feedback.is_empty():
		body.add_child(host._label(host.harbor_feedback, 14, Palette.SUCCESS))
	match page:
		"routes": _routes(body, state, host)
		"exchange": _exchange(body, state, host)
		"crew": _crew(body, state, host)
		_: _jobs(body, state, host)

static func _card(parent: Control, host: Control) -> VBoxContainer:
	var box: VBoxContainer = host._panel(parent, 12)
	box.add_theme_constant_override("separation", 9)
	return box

static func _routes(body: VBoxContainer, state: Dictionary, host: Control) -> void:
	body.add_child(host._label("行き先によって、道と潮、拾える物が変わります。出発前に選ぼう。", 14, Palette.MUTED))
	for id: String in Data.Campaign.DISTRICTS:
		var district: Dictionary = Data.Campaign.DISTRICTS[id]
		var unlocked: bool = Data.Campaign.unlocked(state, id)
		var card := _card(body, host)
		var title: String = district.name + (" / 選択中" if state.profile.selectedDistrict == id else "")
		card.add_child(host._section(title, "map"))
		card.add_child(host._label(district.subtitle, 14))
		card.add_child(host._label(district.objective if unlocked else district.lockReason, 14, Palette.MUTED if unlocked else Palette.GOLD))
		var select: Button = host._button("この地区へ向かう" if unlocked else "航路は未開通", func(): host._campaign_action({"type":"choose_district", "district":id}, "routes"), unlocked)
		select.set_meta("district_id",id)
		select.disabled = not unlocked or state.profile.selectedDistrict == id
		if state.profile.selectedDistrict == id:
			select.text = "次の遠征の行き先"
		card.add_child(select)

static func _jobs(body: VBoxContainer, state: Dictionary, host: Control) -> void:
	var progress: Dictionary = Data.campaign_summary(state)
	body.add_child(host._label("港の復興  %d / %d" % [progress.completed, progress.total], 18))
	body.add_child(host._label("依頼の品は倉庫から渡します。装備や道具を手元に残すか、届けるかを選ぼう。", 14, Palette.MUTED))
	var contracts: Array = Data.contracts(state)
	contracts.sort_custom(func(a:Dictionary,b:Dictionary) -> bool: return _job_rank(a) < _job_rank(b))
	for row: Dictionary in contracts:
		var card := _card(body, host)
		var heading := HBoxContainer.new()
		card.add_child(heading)
		heading.add_child(host._avatar(row.character, 42))
		var words := VBoxContainer.new()
		words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		heading.add_child(words)
		words.add_child(host._label(row.title, 19))
		var statuses := {"locked":"まだ届いていない依頼", "available":"受けられます", "ready":"倉庫の品を届けられます", "claimed":"完了"}
		words.add_child(host._label("追跡中" if row.accepted and row.status != "claimed" else statuses[row.status], 13, Palette.SUCCESS if row.status in ["ready","claimed"] else Palette.GOLD))
		card.add_child(host._label(row.description, 14))
		if row.status == "locked":
			card.add_child(host._label(row.lockReason, 13, Palette.GOLD))
		else:
			card.add_child(host._label("向かう地区：%s" % Data.Campaign.DISTRICTS[row.district].name, 13, Palette.MUTED))
		for requirement: Dictionary in row.requirements:
			var line := HBoxContainer.new()
			line.add_child(host._icon(requirement.kind, 26))
			var text: String = "%s × %d / 納品済み" % [Data.ITEMS[requirement.kind].name,requirement.count] if row.status == "claimed" else "%s   %d / %d" % [Data.ITEMS[requirement.kind].name,requirement.owned,requirement.count]
			var label: Label = host._label(text,14,Palette.SUCCESS if row.status == "claimed" or requirement.owned >= requirement.count else Palette.INK)
			label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			line.add_child(label)
			card.add_child(line)
		var rewards: Array[String] = ["%d G" % row.reward.credits]
		for kind: String in row.reward.items:
			rewards.append(Data.ITEMS[kind].name)
		if not str(row.reward.unlock).is_empty():
			rewards.append("%sへの航路" % Data.Campaign.DISTRICTS[row.reward.unlock].name)
		card.add_child(host._label("お礼：" + " / ".join(rewards), 13, Palette.GOLD))
		if row.status == "claimed":
			continue
		var actions := HBoxContainer.new()
		card.add_child(actions)
		var follow: Button = host._button("追跡中" if row.accepted else "この依頼を追う",func(): host._campaign_action({"type":"accept_contract","id":row.id},"jobs"))
		follow.set_meta("contract_id",row.id)
		follow.disabled = row.accepted or row.status == "locked"
		actions.add_child(follow)
		var deliver: Button = host._button("品を届ける",func(): host._confirm_delivery(row), true)
		deliver.set_meta("delivery_id",row.id)
		deliver.disabled = row.status != "ready"
		actions.add_child(deliver)

static func _job_rank(row: Dictionary) -> int:
	if row.accepted and row.status != "claimed":
		return 0
	return {"ready":1,"available":2,"locked":3,"claimed":4}.get(row.status,4)

static func _exchange(body: VBoxContainer, state: Dictionary, host: Control) -> void:
	body.add_child(host._label("港の所持金  %d G" % int(state.profile.credits), 20))
	body.add_child(host._label("倉庫の品を売って、次の遠征の道具を揃えられます。依頼に使う品まで売らないように。",14,Palette.MUTED))
	body.add_child(host._section("道具を買う", "bag"))
	for item: Dictionary in Data.shop_rows(state):
		var row := HBoxContainer.new()
		row.add_child(host._icon(item.kind, 36))
		var label: Label = host._label(Data.ITEMS[item.kind].name, 15)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		var buy: Button = host._button("%d Gで買う" % item.price,func(): host._campaign_action({"type":"buy","kind":item.kind},"exchange"))
		buy.set_meta("buy_kind",item.kind)
		buy.size_flags_horizontal = Control.SIZE_SHRINK_END
		buy.custom_minimum_size.x = 127
		buy.disabled = not item.affordable
		row.add_child(buy)
		body.add_child(row)
	body.add_child(host._rule())
	body.add_child(host._section("倉庫の品を売る", "chest"))
	if state.profile.stash.is_empty():
		body.add_child(host._label("売れる品はありません。貸出ナイフで回収に出られます。",14,Palette.MUTED))
	for item: Dictionary in state.profile.stash:
		if item.kind == "loanKnife":
			continue
		var row := HBoxContainer.new()
		row.add_child(host._icon(item.kind, 32))
		var info: Label = host._label(Data.ITEMS[item.kind].name, 14)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info)
		var sell: Button = host._button("%d Gで売る" % Data.ITEMS[item.kind].value,func(): host._confirm_sale(item))
		sell.set_meta("sell_uid",item.uid)
		sell.size_flags_horizontal = Control.SIZE_SHRINK_END
		sell.custom_minimum_size.x = 127
		row.add_child(sell)
		body.add_child(row)

static func _crew(body: VBoxContainer, state: Dictionary, host: Control) -> void:
	var character: String = state.character
	var who: Dictionary = Data.CHARACTERS[character]
	var heading := HBoxContainer.new()
	heading.custom_minimum_size.y = 192
	body.add_child(heading)
	var portrait: TextureRect = host._portrait(character,Vector2(124,192),true)
	portrait.set_meta("crew_portrait",character)
	heading.add_child(portrait)
	var identity := VBoxContainer.new()
	identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	identity.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	heading.add_child(identity)
	identity.add_child(host._label(host.NAMES[character],12,Palette.GOLD))
	identity.add_child(host._label(who.name,28))
	identity.add_child(host._label(who.role,16,Palette.MUTED))
	identity.add_child(host._rule())
	identity.add_child(host._label(who.trait,14,Palette.SUCCESS))
	for line: String in Data.dialogue(state, character):
		body.add_child(host._label("「%s」" % line, 17))
	body.add_child(host._rule())
	for row: Dictionary in Data.contracts(state):
		if row.character != character or row.id in Data.Campaign.STORY_IDS:
			continue
		body.add_child(host._label(row.title, 18))
		body.add_child(host._label(row.description, 14, Palette.MUTED))
		if row.status == "claimed":
			body.add_child(host._label("この依頼は完了しました。",14,Palette.SUCCESS))
		else:
			body.add_child(host._button("依頼帳を開く",func(): host._campaign("jobs"),true))
