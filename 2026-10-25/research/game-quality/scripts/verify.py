#!/usr/bin/env python3
"""Verify selection, case identity and recorded image provenance."""
import hashlib
import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]


def verify():
    selection = json.loads((ROOT/'selection.json').read_text())
    charts = json.loads((ROOT/'rankings.json').read_text())
    charts += json.loads((ROOT/'rankings-additional.json').read_text())
    appids = [row['appid'] for row in selection]
    assert len(appids) == len(set(appids)), 'Duplicate selected app'
    selected_cases = []
    unresolved = []
    for row in selection:
        chart = next(x for x in charts if x.get('tag') == row['tag'])
        entry = next(x for x in chart['entries'] if x['appid'] == row['appid'])
        assert entry['position'] == row['position'] <= 20, row['name']
        assert chart['retrieved_at'] == row['retrieved_at'], row['name']
        matches = list((ROOT/'cases').glob(f'{row["appid"]}-*.md'))
        assert len(matches) == 1, f'Expected exactly one case: {row["appid"]}'
        case = matches[0]
        text = case.read_text()
        definitions = set(re.findall(r'^\s*(?:[-*]\s*)?(?:#{1,6}\s*)?(?:\*\*)?(E\d{2})\b', text, re.M))
        references = set(re.findall(r'\bE\d{2}\b', text))
        missing = sorted(references-definitions)
        if missing:
            unresolved.append({'file': str(case.relative_to(ROOT)), 'evidence_ids': missing})
        selected_cases.append({'appid': row['appid'], 'file': str(case.relative_to(ROOT)),
                               'sha256': hashlib.sha256(case.read_bytes()).hexdigest(),
                               'evidence_definitions': sorted(definitions)})
    assert not unresolved, f'Undefined evidence references: {unresolved}'
    assert len(list((ROOT/'cases').glob('*.md'))) == len(selection), 'Unselected case exists'
    images = []
    for path in sorted((ROOT/'frames').glob('*.json')):
        data = json.loads(path.read_text())
        records = data.get('frames', data.get('images'))
        if records is None:
            records = [data] if 'file' in data and 'sha256' in data else []
        for row in records:
            file = ROOT/row['file']
            if not file.exists():
                file = ROOT/'frames'/row['file']
            assert file.resolve().is_relative_to(ROOT.resolve()), 'Image escaped research root'
            assert file.exists(), file
            digest = hashlib.sha256(file.read_bytes()).hexdigest()
            assert digest == row['sha256'], f'Image hash mismatch: {file}'
            if 'seconds' in row and 'duration_seconds' in data:
                assert 0 <= row['seconds'] < data['duration_seconds'], row
            images.append({'manifest': str(path.relative_to(ROOT)),
                           'file': str(file.relative_to(ROOT)), 'sha256': digest})
    output = {'selection_count': len(selection), 'case_count': len(selected_cases),
              'ranking_positions_match': True, 'undefined_evidence_ids': unresolved,
              'recorded_images': len(images), 'image_hashes_match': True,
              'cases': selected_cases, 'images': images,
              'limit': 'Referential and hash checks only; not a factual, readability or game-quality verdict'}
    target = ROOT/'verification'/'source-audit.json'
    target.write_text(json.dumps(output, ensure_ascii=False, indent=2)+'\n')
    print(json.dumps({k:v for k,v in output.items() if k not in ['cases','images']}, ensure_ascii=False))


if __name__ == '__main__':
    verify()
