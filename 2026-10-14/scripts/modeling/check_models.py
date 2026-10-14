"""Validate shipped GLBs, modeling references and editable sources without Blender."""
import argparse
import json
from pathlib import Path
from verify_glb import verify

APP = Path(__file__).resolve().parents[2]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--report', type=Path)
args = parser.parse_args()
manifest = json.loads((Path(__file__).parent / 'models.json').read_text())
rows = []
for model in manifest['models']:
    for key in ('reference', 'generator', 'blend', 'glb'):
        assert (APP / model[key]).is_file(), f"Missing {model['name']} {key}: {model[key]}"
    row = verify(APP / model['glb'], model['max_triangles'], model['required_nodes'])
    assert row['surfaces'] <= model['max_surfaces'], f"Too many surfaces: {model['name']}"
    row['path'] = model['glb']
    rows.append({'name': model['name'], 'reference': model['reference'], **row})
report = {'models': rows, 'total_triangles': sum(r['triangles'] for r in rows),
          'total_bytes': sum(r['bytes'] for r in rows)}
if args.report:
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n')
print(f"Model checks passed: {len(rows)} assets, {report['total_triangles']:,} triangles, {report['total_bytes']:,} bytes")
