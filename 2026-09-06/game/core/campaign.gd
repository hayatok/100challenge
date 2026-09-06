extends RefCounted
const DAYS=[45,49,53,56]
const PLANS={
"breakfast":{"name":"朝のよりみち便","needs":["rice light","bread","tea"],"cats":[0,1,2],"hour":8,"detail":"出勤前の小さな朝ごはん。軽いお米、パン、お茶を切らさず、朝の補充と会計を両立しよう。","ending":"朝の挨拶が、店の名物になった。パンより早起きの常連たちが、今日も扉を開ける。"},
"night":{"name":"夜勤のおかえり便","needs":["warm hearty","warm soup","coffee"],"cats":[6,5,2],"hour":2,"detail":"夜中にも帰る場所を。温かく満腹になる食事、スープ、コーヒーを用意。短い期限と深夜のシフトが鍵。","ending":"お疲れさまの声と、湯気の向こうの笑顔。夜の明かりが、この街の帰り道になった。"},
"treats":{"name":"冬のごほうび便","needs":["dessert","cookie","tea"],"cats":[4,3,2],"hour":17,"detail":"今日を頑張った人へ。スイーツ、焼き菓子、お茶を用意。午後便から夕方の山場まで、棚を空けない工夫を。","ending":"『見るだけ』と言いながら、今日も寄り道。ごほうびを選ぶ時間が、街の小さな楽しみになった。"}}
static func metrics(state:Dictionary) -> Dictionary:
	var plan=state.get("winter_plan","");var groups={};var completed=0;var served=0
	if PLANS.has(plan):
		for group in PLANS[plan].needs:groups[group]={"completed":0,"served":0}
	for report in state.get("reports",[]):
		if report.day>56:continue
		for group in report.get("winter_results",{}):
			if not groups.has(group):continue
			var tally=report.winter_results[group]
			groups[group].completed+=tally.completed;groups[group].served+=tally.served
	for tally in groups.values():completed+=tally.completed;served+=tally.served
	var rate=served/float(maxi(completed,1))
	return {"plan":plan,"groups":groups,"completed":completed,"served":served,"rate":rate,"pass":groups.size()==3 and groups.values().all(func(tally):return tally.served>=12) and completed>=60 and rate>=0.7}

static func ending_qualified(state:Dictionary) -> bool:
	if state.star!=5 or not metrics(state).pass:return false
	for report in state.reports:
		if report.day==56:return report.get("cash_close",-1)>=0
	return false
