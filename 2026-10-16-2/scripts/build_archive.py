#!/usr/bin/env python3
"""Export the fixed research ledger without network access or changing its source."""
from __future__ import annotations
import argparse
import copy
import hashlib
import json
import shutil
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
EVIDENCE_ROOT = ROOT.parent / '2026-10-16'
DEFAULT_SOURCE = EVIDENCE_ROOT / 'data/revisions/20261016-v3/merged'
EXPECTED = {'statistics': 53, 'observations': 15728, 'events': 184,
            'living': 105, 'sources': 259, 'gaps': 115}
INPUTS = {'statistics': 'statistics.json', 'observations': 'observations.json',
          'events': 'events.json', 'living': 'living_materials.json',
          'sources': 'sources.json', 'gaps': 'gaps.json'}


def read(path):
    return json.loads(path.read_text())


def normalized(value):
    # JSON numeric equality is retained; raw original numeric spelling lives in raw.
    if isinstance(value, float) and value.is_integer():
        return int(value)
    if isinstance(value, dict):
        return {key: normalized(item) for key, item in value.items()}
    if isinstance(value, list):
        return [normalized(item) for item in value]
    return value


def canonical(value):
    return json.dumps(normalized(value), ensure_ascii=False, sort_keys=True, separators=(',', ':'))


def sha(data):
    return hashlib.sha256(data).hexdigest()


def digest(value):
    return sha(canonical(value).encode())


def save(path, value, compact=False):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, ensure_ascii=False,
                              separators=(',', ':') if compact else None,
                              indent=None if compact else 2) + '\n')


def series_key(observation):
    time_axis = 'cat03' if observation['statistic_id'] == 'EST06' else observation['time_dimension']
    dims = {key: value['code'] for key, value in observation['dimensions'].items()
            if key != time_axis}
    return observation['statistic_id'], canonical(dims), time_axis, observation.get('observation_frequency')


def build(source):
    originals = {name: read(source / path) for name, path in INPUTS.items()}
    editorial_file = EVIDENCE_ROOT / 'app/data/editorial.json'
    editorial = read(editorial_file)
    manifest = read(source / 'manifest.json')
    for name, expected in EXPECTED.items():
        assert len(originals[name]) == expected, (name, len(originals[name]), expected)
    assert len({o['id'] for o in originals['observations']}) == EXPECTED['observations']
    source_ids = {s['id'] for s in originals['sources']}
    statistics_by_id = {s['id']: s for s in originals['statistics']}
    fixtures = ROOT / 'tests/fixtures'
    # Preserve the existing v2 audit baseline before adding a v3 snapshot.
    old_snapshot = fixtures / 'source_snapshot.json'
    v2_snapshot = fixtures / 'source_snapshot.v2.json'
    if not v2_snapshot.exists():
        assert read(old_snapshot)['counts']['observations'] == 14083
        shutil.copyfile(old_snapshot, v2_snapshot)
    v2 = read(v2_snapshot)
    observed = {o['id']: o for o in originals['observations']}
    assert all(digest(observed[id]) == expected for id, expected in v2['observationHashes'].items())
    evidence = []
    evidence_lookup = {}
    for index, path in enumerate(sorted({o['evidence_path'] for o in originals['observations']})):
        original_file = EVIDENCE_ROOT / path
        receipt_path = original_file.with_suffix('.receipt.json')
        receipt = read(receipt_path)
        assert receipt['exit_code'] == 0 and receipt['json_valid']
        assert Path(receipt['command'][0]).name == 'estat'
        output_sha = sha(original_file.read_bytes())
        assert output_sha == receipt['sha256'], path
        target = fixtures / path
        target.parent.mkdir(parents=True, exist_ok=True)
        for origin, destination in [(original_file, target), (receipt_path, target.with_suffix('.receipt.json'))]:
            if destination.exists():
                assert destination.read_bytes() == origin.read_bytes(), f'Existing fixture changed: {destination}'
            else:
                shutil.copyfile(origin, destination)
        item = {'id': f'CLI{index + 1:03}', 'originalPath': path,
                'fixturePath': 'tests/fixtures/' + path,
                'receiptPath': 'tests/fixtures/' + str(Path(path).with_suffix('.receipt.json')),
                'sha256': output_sha, 'receipt': receipt,
                'recordCount': len(read(original_file)['records'])}
        evidence.append(item)
        evidence_lookup[path] = item['id']

    groups = defaultdict(list)
    for o in originals['observations']:
        assert o['source_id'] in source_ids
        groups[series_key(o)].append(o)
    series = []
    for (stat_id, dims_json, time_axis, frequency), observations in sorted(groups.items(), key=lambda item: str(item[0])):
        stat = statistics_by_id[stat_id]
        first = observations[0]
        dims = json.loads(dims_json)
        labels = {key: first['dimensions'][key].get('name', code) for key, code in dims.items()}
        sid = stat_id + ':' + ':'.join(f'{key}={code}' for key, code in sorted(dims.items()))
        if time_axis != 'time' and frequency is not None:
            sid += ':axis=' + time_axis
        if frequency is not None:
            sid += ':frequency=' + frequency
        units = sorted({o['unit'] for o in observations})
        points = []
        for o in sorted(observations, key=lambda o: (o['year'] if o['year'] is not None else -1, o['time_code'], o['id'])):
            point = copy.deepcopy(o)
            point.update({'timeCode': o['time_code'], 'timeLabel': o['time_label'],
                          'kind': o['value_kind'], 'evidenceId': evidence_lookup[o['evidence_path']]})
            points.append(point)
        numeric_years = sorted({o['year'] for o in observations if o['year'] is not None and o['value_kind'] == 'number'})
        display_labels = [f'収録版：{name}' if key == 'time' and time_axis != 'time' else name
                          for key, name in labels.items()]
        series.append({'id': sid, 'statId': stat_id, 'sourceId': stat['source_id'],
                       'tableId': stat['table_id'], 'label': ' / '.join(display_labels),
                       'unit': units[0] if len(units) == 1 else '・'.join(units), 'units': units,
                       'geography': first['geography'], 'dimensions': dims, 'labels': labels,
                       'timeDimension': time_axis, 'frequency': frequency or stat['frequency'],
                       'sourceTimeDimension': first['time_dimension'], 'points': points,
                       'numericStart': min(numeric_years) if numeric_years else None,
                       'numericEnd': max(numeric_years) if numeric_years else None,
                       'numericCount': sum(o['value_kind'] == 'number' for o in observations),
                       'notes': [stat['population_definition'], *stat['comparability_breaks'],
                                 '値が返らない年と原表の記号を区別し、補間や0への置換をしない。']})

    events = []
    for event in originals['events']:
        e = copy.deepcopy(event)
        ed = editorial['events'].get(e['id'])
        e['editorialSource'] = 'v2_reader_edit' if ed else 'v3_research_summary'
        if ed is None:
            ed = {'summary': e['summary'], 'qualification': e.get('disputed_or_qualified'),
                  'locator': e['source_locator']}
        e['originalSummary'] = e['summary']
        e['summary'] = ed['summary']
        e['qualification'] = ed['qualification']
        e['locator'] = ed['locator']
        e['editorial'] = copy.deepcopy(ed)
        events.append(e)

    archive = {'version': 1, 'cutoff': manifest['cutoff_date'], 'counts': EXPECTED,
               'edition': '20261016-v3', 'baselineEdition': '20261016-v2',
               'statistics': copy.deepcopy(originals['statistics']), 'series': series,
               'events': events, 'living': copy.deepcopy(originals['living']),
               'sources': copy.deepcopy(originals['sources']), 'gaps': copy.deepcopy(originals['gaps']),
               'evidence': evidence,
               'scopeNote': '取得済みの調査資料を収録。日本の全史や全住民の経験の調査完了を意味しない。'}
    for stat in archive['statistics']:
        stat['seriesIds'] = [s['id'] for s in series if s['statId'] == stat['id']]
        points = [p for s in series if s['statId'] == stat['id'] for p in s['points']]
        years = [p['year'] for p in points if p['kind'] == 'number' and p['year'] is not None]
        stat['actualNumericPeriod'] = [min(years), max(years)] if years else [None, None]
        stat['exportedCells'] = len(points)
        stat['exportedNumericCells'] = sum(p['kind'] == 'number' for p in points)

    def find(stat_id, **dimensions):
        found = [s['id'] for s in series if s['statId'] == stat_id and
                 all(s['dimensions'].get(key) == value for key, value in dimensions.items())]
        assert found, (stat_id, dimensions)
        return found
    def ids(choices):
        return [sid for stat_id, dimensions in choices for sid in find(stat_id, **dimensions)]
    def segment(start, end, choices, label, limitation):
        return {'from': start, 'through': end, 'seriesIds': ids(choices),
                'label': label, 'limitation': limitation}
    def driver(id, label, target, choices, notes, boundaries=None, segments=None, limitation=''):
        selected = ids(choices)
        for seg in segments or []:
            selected.extend(seg['seriesIds'])
        return {'id': id, 'label': label, 'status': 'allowed_with_notes', 'worldTarget': target,
                'seriesIds': list(dict.fromkeys(selected)), 'notes': notes,
                'boundaries': boundaries or [], 'segments': segments or [], 'limitation': limitation,
                'selectionPolicy': {'exactYearFirst': True, 'allowHistoricalSnapshot': True,
                                    'showObservationYear': True, 'treatSnapshotAsCurrent': False,
                                    'interpolate': False, 'missingRawStopsSnapshot': True},
                'authorRuleNote': '描画の数や縮尺は作者が設定する。全国値を架空個人の確率に変換しない。'}

    pop_basis = [('D3-ST001', {'cat01': '00100', 'tab': '10010'})]
    pop_ssd = [('SD-STAT016', {'area': '00000', 'cat01': 'A1101'})]
    pop_periods = [
        (1900,1919,'旧内地の内地人・1月1日の推計人口','国勢調査から遡った推計。樺太・台湾・朝鮮等を含む帝国全領域人口ではありません。'),
        (1920,1939,'外国人を含む旧内地人口','現在地人口。原則10月1日。現在の日本の領域とは異なります。'),
        (1940,1940,'1940年の基礎人口','銃後人口に内地軍人・軍属の推計を加えた人口です。'),
        (1941,1943,'外国人を含む旧内地人口','現在地人口。樺太を含まず、帝国全領域の人口ではありません。'),
        (1944,1944,'1944年2月22日の人口','陸海軍の部隊・艦船にある人と外国人を除きます。'),
        (1945,1945,'1945年11月1日の人口','軍隊・外国人を除き、沖縄と北海道・東京・九州の一部も対象外です。'),
        (1946,1946,'1946年4月26日の人口','外国人と外国人世帯にいる人を除くなど、前年と対象が違います。'),
        (1947,1949,'戦後の現在地人口','沖縄等を除き、外国軍隊・公館員とその家族を含みません。'),
        (1950,1951,'常住人口へ変わった基礎人口','1950年から常住人口。沖縄等の地域を除きます。'),
        (1952,1953,'十島村が加わった基礎人口','対象地域が変わります。地域の復帰日と統計へ加わる年は同じとは限りません。'),
        (1954,1966,'奄美が加わった基礎人口','外国人を含む総人口。沖縄・小笠原等はまだ対象外です。'),
        (1967,1967,'日本人人口へ変わった基礎人口','この年から外国人を含む総人口ではなく、日本人人口です。'),
        (1968,1972,'小笠原が加わった日本人人口','沖縄はまだ対象外です。現在の総人口と同じ対象ではありません。'),
        (1973,1974,'沖縄が加わった日本人人口','外国人を含む総人口とは別の対象です。'),
    ]
    pop_segments = [segment(f'{start}-01',f'{end}-12',pop_basis,label,limit)
                    for start,end,label,limit in pop_periods]
    pop_segments.append(segment('1975-01','2026-10',pop_ssd,'10月1日の総人口',
                                '国勢調査と人口推計による総人口。前の日本人人口とつなげて増減を比べません。'))
    old_industry=[('SD2-STAT001',{'cat02':'100','cat01':'120'}),('SD2-STAT001',{'cat02':'100','cat01':'180'})]
    labor_legacy=[('SD-STAT005',{'cat01':'001'}),('SD2-STAT002',{'cat01':'A009'})]
    labor_2003=[('SD-STAT005',{'cat01':'001'}),('SD-STAT005',{'cat01':'010'})]
    labor_2007=[('D3-ST003',{'area':'00000','cat01':'01','cat02':'0','cat03':'00'}),
                ('D3-ST003',{'area':'00000','cat01':'10','cat02':'0','cat03':'00'})]
    labor_2011=[('D3-ST004',{'area':'00000','cat01':'01','cat02':'0','cat03':'00','cat04':'00'}),
                ('D3-ST004',{'area':'00000','cat01':'10','cat02':'0','cat03':'00','cat04':'00'})]
    industry_segments=[
        segment('1920-01','1952-12',old_industry,'国勢調査の旧産業分類','実際の観測は1920・1930・1940・1950年。人の単位で、後年の労働力調査とは別です。'),
        segment('1953-01','2002-12',labor_legacy,'労働力調査の旧製造業','旧製造業は現在の同名分類と内容が違います。農業と製造業だけで全産業の構成にはなりません。'),
        segment('2003-01','2006-12',labor_2003,'産業分類を改めた就業者数','万人の年平均。旧製造業の値へ継ぎ足しません。'),
        segment('2007-01','2010-12',labor_2007,'第12回改定の産業分類','以前の分類と別の資料です。年平均と月次を混ぜません。'),
        segment('2011-01','2026-10',labor_2011,'15歳以上の就業者数','2011年は震災で全国年平均がありません。記号を0や2010年の値へ置き換えません。'),
    ]
    education_old=[('SD-STAT003',{'cat01':'0000000020'}),('SD-STAT003',{'cat01':'0000000120'})]
    education_new=[('D3-ST002',{'area':'00000','cat01':'E2501'}),('D3-ST002',{'area':'00000','cat01':'E6302'})]
    bus_old=[('EST05',{'area':'00001','cat01':'00001'})]
    bus_new=[('E3-ST001',{'cat01':'00030','tab':'00040'})]
    pc_old=[('E3-ST003',{'cat01':'110','cat04':'100','cat08':'290'})]
    mobile_old=[('E3-ST003',{'cat01':'110','cat04':'100','cat08':'170'})]
    pc_2005=[('E3-ST004',{'cat01':'290','cat04':'100'})]
    mobile_2005=[('E3-ST004',{'cat01':'170','cat04':'100'})]
    pc_new=[('E3-ST005',{'cat01':'290','cat04':'100'})]
    smartphone=[('E3-ST005',{'cat01':'260','cat04':'100'})]
    drivers = [
        driver('population','人口','模型に描く人の規模',pop_ssd,
               ['1900～1974年は人口動態の基礎人口。国籍・対象地域・基準日・現在地/常住の違いを区切る。',
                '1975年以後は従来のSSD総人口。日本人人口と同じ量として増減率を計算しない。',
                '人口から架空個人の出生・死亡・寿命の確率を作らない。'],
               [{'year':start,'reason':label} for start,_,label,_ in pop_periods[1:]]+
               [{'year':1975,'reason':'人口動態の基礎人口からSSD総人口へ対象を切替'}],pop_segments,
               '人口に含まれる人や地域、数える日は年代で変わります。観測年と対象を添えています。'),
        driver('industry','働く場所','田畑・工房・工場の量',old_industry+labor_legacy+labor_2003,
               ['国勢/労働力調査、旧新産業分類、年齢区分を別系列に保持。人と万人を混ぜない。',
                '2011年の原記号を保持。2026年平均を作らず、古い断面には観測年を表示する。',
                '農業と製造業から他産業の人数や個人の就業確率を作らない。'],
               [{'year':y,'reason':r}for y,r in [(1953,'国勢調査から労働力調査'),(2003,'旧製造業から別分類'),
                                              (2007,'第12回産業分類'),(2011,'年齢・分類を区別、震災による欠測')]],
               industry_segments,'調査や産業の分け方が変わります。2011年の値はなく、前後をつなぎません。'),
        driver('housing','住まい','家の数と空き家の灯り',
               [('EST13',{'area':'00000','cat01':'H1100'}),('EST13',{'area':'00000','cat01':'H110202'})],
               ['原単位は戸。世帯数や人数ではない。1978～2023の5年刻み。',
                '原調査日と年度ラベルの対応は未確定。間の年を補間しない。'],
               limitation='住宅と空き家の数は5年ごとの値。間の年の戸数は分かりません。'),
        driver('water','水道','町の水道設備の模型',[('EST13',{'area':'00000','cat01':'H530101'})],
               ['1975～2023年度の上水道給水人口。電化率や全水道普及率ではない。',
                '原調査日との対応は未確認。人口と安易に割って普及率を作らない。'],
               limitation='上水道で給水される人口。電気の普及や、水道全体の普及率ではありません。'),
        driver('education','学ぶ場所','学校と通学の模型',education_old,
               ['1948～2016の旧在学者と、2017以後に参照するSSD小学生/大学学部を別対象にする。',
                '大学は旧DBが大学院等を含み、新SSDは学部のみ。旧DBの単位文字列は未取得のまま。',
                '小学校2016は旧DBとSSDの値が一致せず未解決。変更を成長/減少の実態と断定しない。',
                'SSDは5月1日の断面。個人の進学・合格確率へ使わない。'],
               [{'year':2017,'reason':'対象の違う学校統計へ切替。大学は学部のみ'}],
               [segment('1948-01','2016-12',education_old,'従来の在学者統計','大学は大学院等を含み、単位文字列の確認が残ります。'),
                segment('2017-01','2026-10',education_new,'小学生と大学学部の学生','大学は学部のみで前の資料と別対象。小学校の2016年不一致も未解決です。')],
               '学校に数える学生の範囲が変わります。大学院を含む資料と学部だけの資料を分けています。'),
        driver('rice','食の供給','米屋や食卓の米の模型',[('E2ST02',{'cat01':'1002'})],
               ['国民1人1年当たり供給純食料の米、kg。摂取量・購入量ではない。',
                '1971年度以前は沖縄除外。最終取得2023年度。成分表と純旅客用控除の境界を切る。'],
               [{'year':y,'reason':r}for y,r in [(1965,'成分表改定'),(1972,'沖縄の対象範囲変更'),(1985,'成分表改定'),
                                              (2009,'成分表改定'),(2014,'成分表改定'),(2018,'純旅客用控除'),
                                              (2019,'成分表改定'),(2022,'成分表改定')]],
               limitation='国内に供給された米の量。実際に一人が食べた量ではありません。'),
        driver('prices','買物と物価','商店の値札の表示',
               [('E2ST01',{'cat01':'0001'}),('E2ST01',{'cat01':'0002'})],
               ['全国・暦年平均、2025年=100の公式接続指数。金額ではない。',
                '1970～2025だけ。旧基準や個人家計・商店工事費へ変換しない。'],
               limitation='2025年を100とした物価の指数。値札の金額ではありません。'),
        driver('bus','移動','走る乗合バスの模型',bus_old,
               ['旧表は2010-10～2020-03、原単位は千。新表は2020-04～2026-03、千人。',
                '2020年4月に調査/集計変更。前後の公表値を無条件に接続しない。',
                '月次の輸送人員で、実車両数・利用者の実人数・年平均ではない。'],
               [{'year':2020,'month':4,'reason':'調査・集計方法を改めた乗合バス統計'}],
               [segment('2010-10','2020-03',bus_old,'旧方法の乗合バス輸送','月次。合計区域を県コードと混同しません。'),
                segment('2020-04','2026-10',bus_new,'新方法の乗合バス輸送','2020年4月より前と比較をつなぎません。過去の月の資料はその月を表示します。')],
               '乗合バスの月ごとの輸送人員。2020年4月の調査方法変更で区切っています。'),
        driver('rail','鉄道','動く鉄道の模型',[('E3-ST002',{'tab':'110','cat01':'100','cat02':'160'})],
               ['2020-04～2026-06月次、千人。旅客数量は総流動で事業者間の重複を含む。',
                '実人数・実車両数・地方別路線の分布を推計しない。月報と年報再集計の版を分ける。'],
               segments=[segment('2020-04','2026-10',[('E3-ST002',{'tab':'110','cat01':'100','cat02':'160'})],
                                 '鉄・軌道の月間旅客数量','同じ人の複数の利用や事業者間の重複を含みます。')],
               limitation='輸送した旅客の数量。利用者の実人数や列車の台数ではありません。'),
        driver('communication','通信の道具','家の通信機器の模型',pc_old+mobile_old,
               ['世帯の保有割合で、個人の所有率や利用率ではない。PCと携帯/スマホを足さない。',
                '2005の断面と2006以後の複数回答を分ける。携帯の包含が異なる4分類は混ぜない。',
                '2017～2025のCSV数値は未採用。以後は2016年の過去資料を示す場合に限る。'],
               [{'year':2005,'reason':'2005年の別保有表'}, {'year':2006,'reason':'複数回答の全世帯保有表'},
                {'year':2010,'reason':'PCとスマートフォンを別チャネルに表示'}],
               [segment('1996-01','2004-12',pc_old+mobile_old,'PCと携帯電話の世帯保有','実観測は1996～2000年。後の年は観測年付きの過去の資料です。'),
                segment('2005-01','2005-12',pc_2005+mobile_2005,'2005年の世帯保有','この表は2005年だけ。前後の質問・分類と別に扱います。'),
                segment('2006-01','2009-12',pc_new,'PCの世帯保有','携帯の包含範囲が異なる分類をつないでいません。'),
                segment('2010-01','2026-10',pc_new+smartphone,'PCとスマートフォンの世帯保有','最終観測は2016年。最新の所有状況に置き換えず、観測年を表示します。')],
               '世帯が持つ機器の割合。個人の所有や利用の確率ではありません。'),
        driver('energy','家庭のエネルギー','家のエネルギーの模型',
               [('E3-ST007',{'area':'00100','cat01':'0680','time':'000107'})],
               ['2017～2023年度の全国平均GJ/世帯・年。電気/都市ガス/LPガス/灯油の合計。',
                '非使用世帯を含む。電気は二次換算。自動車用ガソリン/軽油を含まない。',
                '2015試験調査と接続しない。2024年度以後の偶数年度は非実施で、欠測0にしない。',
                'cat02が観測年度。timeの令和5年度は版であり、全値の観測年ではない。'],
               segments=[segment('2017-01','2026-10',[('E3-ST007',{'area':'00100','cat01':'0680','time':'000107'})],
                                 '世帯当たりの年間エネルギー','電気・ガス・灯油の合計。最新観測は2023年度で、2024年度は調査していません。')],
               limitation='世帯当たりの年間平均。自動車の燃料を含まず、個々の家の使用量ではありません。')
    ]
    selected = {sid for d in drivers for sid in d['seriesIds']}
    for stat in archive['statistics']:
        used = [sid for sid in stat['seriesIds'] if sid in selected]
        stat['worldUse'] = {'status': 'selected_series' if used else 'archive_only', 'seriesIds': used,
                            'reason': '全国の一部系列を観測年付きの模型へ参照。' if used else
                            '原値・範囲・出典を閲覧できる。対象/頻度/定義の確認範囲から主描画の量には直接使わない。'}
    driver_doc = {'version': 1, 'cutoff': archive['cutoff'], 'drivers': drivers,
                  'rules': ['史実と統計は固定。seedは架空の模型の暮らしだけを変える。',
                            '過去の観測を参照する模型には、観測年・原時間ラベルを表示する。',
                            '原表の欠測記号と未取得年は0にせず、境界をまたぐ補間・外挿をしない。'],
                  'archiveOnlyNotes': ['旧CPI、家計円、熱量は基準・量の違いを保持した別系列。',
                                       '通信の最新CSV値や所有と利用を同一の普及率へ混ぜない。',
                                       '電灯需要の口/MWhと世帯エネルギーのGJは別量。月・年度・半期も別系列。',
                                       '国勢人口長期表は対象・基準の留保があり主駆動は保留。']}
    save(ROOT / 'app/data/archive.json', archive, compact=True)
    save(ROOT / 'app/data/drivers.json', driver_doc)
    snapshot = {'version': 1, 'inputs': {name: {'path': str((source / path).relative_to(EVIDENCE_ROOT)), 'sha256': sha((source / path).read_bytes()),
                 'canonicalSha256': digest(originals[name])} for name, path in INPUTS.items()},
                'observationHashes': {o['id']: digest(o) for o in originals['observations']},
                'counts': EXPECTED}
    snapshot['inputs']['editorial'] = {'path': 'app/data/editorial.json', 'sha256': sha(editorial_file.read_bytes()), 'canonicalSha256': digest(editorial)}
    snapshot['baselineSnapshot'] = 'source_snapshot.v2.json'
    save(fixtures / 'source_snapshot.v3.json', snapshot, compact=True)
    print(f"Exported {len(series)} series / {len(originals['observations'])} cells, {len(evidence)} CLI output-receipt pairs, {len(drivers)} drivers")


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path, default=DEFAULT_SOURCE)
    build(parser.parse_args().source.resolve())
