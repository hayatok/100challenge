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
DEFAULT_SOURCE = ROOT.parent / '2026-10-16'
EXPECTED = {'statistics': 41, 'observations': 14083, 'events': 177,
            'living': 85, 'sources': 213, 'gaps': 107}
INPUTS = {'statistics': 'data/statistics.json', 'observations': 'data/observations.json',
          'events': 'data/events.json', 'living': 'data/living_materials.json',
          'sources': 'data/sources.json', 'gaps': 'data/gaps.json',
          'editorial': 'app/data/editorial.json'}


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
    return observation['statistic_id'], canonical(dims)


def build(source):
    originals = {name: read(source / path) for name, path in INPUTS.items()}
    for name, expected in EXPECTED.items():
        assert len(originals[name]) == expected, (name, len(originals[name]), expected)
    assert len({o['id'] for o in originals['observations']}) == EXPECTED['observations']
    source_ids = {s['id'] for s in originals['sources']}
    statistics_by_id = {s['id']: s for s in originals['statistics']}
    fixtures = ROOT / 'tests/fixtures'
    evidence = []
    evidence_lookup = {}
    for index, path in enumerate(sorted({o['evidence_path'] for o in originals['observations']})):
        original_file = source / path
        receipt_path = original_file.with_suffix('.receipt.json')
        receipt = read(receipt_path)
        assert receipt['exit_code'] == 0 and receipt['json_valid']
        assert Path(receipt['command'][0]).name == 'estat'
        output_sha = sha(original_file.read_bytes())
        assert output_sha == receipt['sha256'], path
        target = fixtures / path
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(original_file, target)
        shutil.copyfile(receipt_path, target.with_suffix('.receipt.json'))
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
    for (stat_id, dims_json), observations in sorted(groups.items()):
        stat = statistics_by_id[stat_id]
        first = observations[0]
        dims = json.loads(dims_json)
        labels = {key: first['dimensions'][key].get('name', code) for key, code in dims.items()}
        sid = stat_id + ':' + ':'.join(f'{key}={code}' for key, code in sorted(dims.items()))
        units = sorted({o['unit'] for o in observations})
        points = []
        for o in sorted(observations, key=lambda o: (o['year'] if o['year'] is not None else -1, o['time_code'], o['id'])):
            point = copy.deepcopy(o)
            point.update({'timeCode': o['time_code'], 'timeLabel': o['time_label'],
                          'kind': o['value_kind'], 'evidenceId': evidence_lookup[o['evidence_path']]})
            points.append(point)
        numeric_years = sorted({o['year'] for o in observations if o['year'] is not None and o['value_kind'] == 'number'})
        series.append({'id': sid, 'statId': stat_id, 'sourceId': stat['source_id'],
                       'tableId': stat['table_id'], 'label': ' / '.join(labels.values()),
                       'unit': units[0] if len(units) == 1 else '・'.join(units), 'units': units,
                       'geography': first['geography'], 'dimensions': dims, 'labels': labels,
                       'timeDimension': 'cat03' if stat_id == 'EST06' else first['time_dimension'],
                       'sourceTimeDimension': first['time_dimension'], 'points': points,
                       'numericStart': min(numeric_years) if numeric_years else None,
                       'numericEnd': max(numeric_years) if numeric_years else None,
                       'numericCount': sum(o['value_kind'] == 'number' for o in observations),
                       'notes': [stat['population_definition'], *stat['comparability_breaks'],
                                 '値が返らない年と原表の記号を区別し、補間や0への置換をしない。']})

    events = []
    for event in originals['events']:
        e = copy.deepcopy(event)
        ed = originals['editorial']['events'][e['id']]
        e['originalSummary'] = e['summary']
        e['summary'] = ed['summary']
        e['qualification'] = ed['qualification']
        e['locator'] = ed['locator']
        e['editorial'] = copy.deepcopy(ed)
        events.append(e)

    archive = {'version': 1, 'cutoff': '2026-10-16', 'counts': EXPECTED,
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

    by_id = {s['id']: s for s in series}
    def find(stat_id, **dimensions):
        return [s['id'] for s in series if s['statId'] == stat_id and
                all(s['dimensions'].get(key) == value for key, value in dimensions.items())]
    def driver(id, label, target, choices, notes, boundaries=None):
        ids = [sid for choice in choices for sid in find(choice[0], **choice[1])]
        assert ids, id
        return {'id': id, 'label': label, 'status': 'allowed_with_notes', 'worldTarget': target,
                'seriesIds': ids, 'notes': notes,
                'boundaries': boundaries or [],
                'selectionPolicy': {'exactYearFirst': True, 'allowHistoricalSnapshot': True,
                                    'showObservationYear': True, 'treatSnapshotAsCurrent': False,
                                    'interpolate': False, 'missingRawStopsSnapshot': True},
                'authorRuleNote': '描画の数や縮尺は作者が設定する。全国値を架空個人の確率に変換しない。'}
    drivers = [
        driver('population', '人口', '模型に描く人の規模',
               [('SD-STAT016', {'area': '00000', 'cat01': 'A1101'})],
               ['各年10月1日の総人口。年度平均人口ではない。',
                '国勢調査と人口推計を含む。外国人の範囲、基準人口の補正・組替えの詳細は原注記を留保。',
                '1975年より前の人口は作らない。最新観測より後は観測年付きの過去の模型としてのみ参照。']),
        driver('industry', '働く場所', '田畑・工房・工場の量',
               [('SD2-STAT001', {'cat02': '100', 'cat01': '120'}),
                ('SD2-STAT001', {'cat02': '100', 'cat01': '180'}),
                ('SD-STAT005', {'cat01': '001'}),
                ('SD2-STAT002', {'cat01': 'A009'}),
                ('SD-STAT005', {'cat01': '010'})],
               ['国勢調査の旧産業1920/1930/1940/1950と労働力調査は別系列。',
                '人と万人を同じ数として混ぜない。旧*製造業A009と010製造業も接続しない。',
                '労働力調査は対象年齢・対象領域等の詳細が未確定。全国の掲載値を示す過去の断面に限定。',
                '農業・製造業だけでは全産業の構成にならない。他産業の人数を差引きで作らない。'],
               [{'year': 1953, 'reason': '国勢調査と労働力調査の別系列'},
                {'year': 2003, 'reason': '*製造業A009から010への分類境界、接続禁止'}]),
        driver('housing', '住まい', '家の数と空き家の灯り',
               [('EST13', {'area': '00000', 'cat01': 'H1100'}),
                ('EST13', {'area': '00000', 'cat01': 'H110202'})],
               ['1978～2023年の5年刻みの取得値。毎年の戸数を補間しない。',
                'SSD年度表示と住宅・土地統計調査の原調査日の対応は未確定。',
                '空き家数から実在の場所・個人の不在を割り当てない。']),
        driver('water', '水道', '町の水道設備の模型',
               [('EST13', {'area': '00000', 'cat01': 'H530101'})],
               ['1975～2023年度の上水道給水人口。電化率や全水道普及率ではない。',
                '原調査日とSSD年度ラベルの対応は未確認。人口と安易に割って普及率を作らない。']),
        driver('education', '学ぶ場所', '学校と通学の模型',
               [('SD-STAT003', {'cat01': '0000000020'}),
                ('SD-STAT003', {'cat01': '0000000120'})],
               ['1948～2016年、国公私立合計の小学校/大学の在学者数を別系列。',
                '大学には大学院・専攻科・別科などを含み、通信教育を含まない。',
                '学校種の変更を無条件接続せず、個人の進学率・試験合格確率にしない。']),
        driver('rice', '食の供給', '米屋や食卓の米の模型',
               [('E2ST02', {'cat01': '1002'})],
               ['国民1人1年当たり供給純食料の米、kg。摂取量・購入量ではない。',
                '1971年度以前は沖縄除外。2024年調査表の最終収録は2023年度。',
                '食品成分表等の改定境界と2018年度の純旅客用控除で比較を切る。'],
               [{'year': year, 'reason': reason} for year, reason in
                [(1965, '成分表改定'), (1972, '沖縄の対象範囲変更'), (1985, '成分表改定'),
                 (2009, '成分表改定'), (2014, '成分表改定'), (2018, '純旅客用控除'),
                 (2019, '成分表改定'), (2022, '成分表改定')]]),
        driver('prices', '買物と物価', '商店の値札の表示',
               [('E2ST01', {'cat01': '0001'}), ('E2ST01', {'cat01': '0002'})],
               ['全国・暦年平均、2025年=100の公式接続指数。金額ではない。',
                '1970～2025年だけ。旧2005/2020年基準とは別系列。品目とウエイトは変わる。',
                '個人の家計・購買量や商店の工事費へ変換しない。']),
        driver('bus', '移動', '走る乗合バスの模型',
               [('EST05', {'area': '00001', 'cat01': '00001'})],
               ['合計区分の乗合バス輸送人員。単位原表は「千」、千人の輸送人員を表す。',
                '2010年10月～2020年3月の月次114観測。区域コードを都道府県コードと混同しない。',
                '年平均や年計を独自算出しない。選択年の末月など参照する月と原timeLabelを明示する。'])
    ]
    limitations = {
        'population': '10月1日の全国人口。1975年より前の値は、この資料にはありません。',
        'industry': '調査や産業の分け方が変わります。違う分類の値をひと続きにはしません。',
        'housing': '住宅と空き家の数は5年ごとの値。間の年の戸数は分かりません。',
        'water': '上水道で給水される人口。電気の普及や、水道全体の普及率ではありません。',
        'education': '全国の在学者数。模型の一人ひとりが進学する確率ではありません。',
        'rice': '国内に供給された米の量。実際に一人が食べた量ではありません。',
        'prices': '2025年を100とした物価の指数。値札の金額ではありません。',
        'bus': '乗合バスの月ごとの輸送人員。年の合計や平均ではありません。',
    }
    for d in drivers:
        d['limitation'] = limitations[d['id']]
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
                                       '携帯電話の構成は2002～2004年だけで全通信普及の長期系列にはならない。',
                                       '家庭電力・燃料は2015年試験調査の1期で、長期の電化率にはしない。',
                                       '国勢人口長期表は歴史的領域・調査基準の留保があるため主駆動は保留。']}
    save(ROOT / 'app/data/archive.json', archive, compact=True)
    save(ROOT / 'app/data/drivers.json', driver_doc)
    snapshot = {'version': 1, 'inputs': {name: {'path': path, 'sha256': sha((source / path).read_bytes()),
                 'canonicalSha256': digest(originals[name])} for name, path in INPUTS.items()},
                'observationHashes': {o['id']: digest(o) for o in originals['observations']},
                'counts': EXPECTED}
    save(fixtures / 'source_snapshot.json', snapshot, compact=True)
    print(f"Exported {len(series)} series / {len(originals['observations'])} cells, {len(evidence)} CLI output-receipt pairs, {len(drivers)} drivers")


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path, default=DEFAULT_SOURCE)
    build(parser.parse_args().source.resolve())
