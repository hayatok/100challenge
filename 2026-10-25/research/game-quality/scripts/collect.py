#!/usr/bin/env python3
"""Capture public Steam source metadata and selected research frames."""
import argparse
import concurrent.futures
import datetime as dt
import hashlib
import html
import json
from pathlib import Path
import re
import subprocess
from urllib.parse import urlencode, urljoin
from urllib.request import Request, urlopen
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
TAGS = {'deckbuilding': 32322, 'action-roguelike': 42804,
        'colony-sim': 220585, 'automation': 255534,
        'farming-sim': 87918, 'soulslike': 29482,
        'story-rich': 1742, 'turn-based-strategy': 1741,
        'puzzle': 1664, 'visual-novel': 3799}


def now():
    return dt.datetime.now(dt.timezone.utc).isoformat()


def fetch(url):
    with urlopen(Request(url, headers={'User-Agent': 'Mozilla/5.0'}), timeout=40) as response:
        return response.read()


def save(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2)+'\n')


def rankings(requested=None, output='rankings.json'):
    url = 'https://api.steampowered.com/ISteamChartsService/GetMostPlayedGames/v1/'
    records = []
    if requested is None:
        raw = fetch(url)
        response = json.loads(raw)['response']
        records = [{'kind': 'global-most-played', 'source_url': url,
                'public_page': 'https://store.steampowered.com/charts/mostplayed',
                'retrieved_at': now(), 'rollup_date': response['rollup_date'],
                'sha256': hashlib.sha256(raw).hexdigest(), 'entries': response['ranks']}]
    def tag_snapshot(item):
        label, tagid = item
        query = {'start': 0, 'count': 50, 'tags': tagid, 'filter': 'topsellers',
                 'category1': 998, 'cc': 'us', 'l': 'english', 'infinite': 1}
        endpoint = 'https://store.steampowered.com/search/results/?'+urlencode(query)
        raw = fetch(endpoint)
        document = json.loads(raw)
        rows = re.findall(r'<a\b[^>]*class="[^"]*search_result_row[^>]*>.*?</a>', document['results_html'], re.S)
        entries = []
        for position, row in enumerate(rows, 1):
            app = re.search(r'data-ds-appid="(\d+)"', row)
            title = re.search(r'<span class="title">(.*?)</span>', row, re.S)
            if app and title:
                entries.append({'position': position, 'appid': int(app[1]),
                                'name': html.unescape(re.sub('<[^>]+>', '', title[1]))})
        if not entries:
            raise ValueError(f'No ranked app rows for {label}')
        return {'kind': 'tag-top-sellers', 'tag': label, 'tagid': tagid,
                'region': 'US', 'language': 'english', 'retrieved_at': now(),
                'source_url': endpoint,
                'public_page': 'https://store.steampowered.com/search/?'+urlencode({k:v for k,v in query.items() if k not in ['infinite','start','count']}),
                'sha256': hashlib.sha256(raw).hexdigest(), 'captured_rows': len(rows),
                'entries': [entry for entry in entries if entry['position'] <= 20]}
    tags = {name: TAGS[name] for name in requested} if requested else TAGS
    with concurrent.futures.ThreadPoolExecutor(max_workers=3) as pool:
        records.extend(pool.map(tag_snapshot, tags.items()))
    save(ROOT/output, records)
    for record in records:
        if record['kind'] != 'global-most-played':
            print(record['tag'], [(x['position'], x['name'], x['appid']) for x in record['entries']])


def catalog(appids):
    def one(appid):
        url = f'https://store.steampowered.com/api/appdetails?appids={appid}&cc=us&l=english'
        raw = fetch(url)
        response = json.loads(raw)[str(appid)]
        if not response.get('success'):
            raise ValueError(f'Steam metadata unavailable for {appid}')
        data = response['data']
        data['_source_url'] = url
        data['_retrieved_at'] = now()
        data['_response_sha256'] = hashlib.sha256(raw).hexdigest()
        save(ROOT/'raw'/f'app-{appid}.json', data)
        print(appid, data['name'], [(i, m.get('name'), list(m)) for i,m in enumerate(data.get('movies', []))])
    with concurrent.futures.ThreadPoolExecutor(max_workers=3) as pool:
        list(pool.map(one, appids))


def frames(appid, movie_index, times=None, fractions=None):
    data = json.loads((ROOT/'raw'/f'app-{appid}.json').read_text())
    movie = data['movies'][movie_index]
    urls = movie.get('mp4') or movie.get('webm') or {}
    url = urls.get('max') or urls.get('480')
    stream = None
    if not url:
        url = movie.get('dash_h264')
        if not url:
            raise ValueError(f'No supported public movie URL: {movie}')
        raw_manifest = fetch(url)
        tree = ET.fromstring(raw_manifest)
        ns = {'d': 'urn:mpeg:dash:schema:mpd:2011'}
        duration_parts = re.fullmatch(r'PT(?:(\d+(?:\.\d+)?)H)?(?:(\d+(?:\.\d+)?)M)?(?:(\d+(?:\.\d+)?)S)?', tree.attrib['mediaPresentationDuration'])
        if not duration_parts:
            raise ValueError('Unsupported DASH duration')
        hours, minutes, seconds = [float(x or 0) for x in duration_parts.groups()]
        duration = hours*3600+minutes*60+seconds
        representations = [rep for rep in tree.findall('.//d:Representation', ns) if rep.attrib.get('mimeType') == 'video/mp4']
        eligible = [rep for rep in representations if int(rep.attrib['width']) <= 1280]
        rep = max(eligible or representations, key=lambda x: int(x.attrib['width']))
        template = rep.find('d:SegmentTemplate', ns)
        if template is None or template.find('d:SegmentTimeline', ns) is not None:
            raise ValueError('Only fixed-duration public DASH segments are supported')
        segment_duration = int(template.attrib['duration'])/int(template.attrib['timescale'])
        stream = (rep.attrib['id'], template.attrib, segment_duration)
        movie_hash = hashlib.sha256(raw_manifest).hexdigest()
        (ROOT/'raw'/f'{appid}-{movie["id"]}.mpd').write_bytes(raw_manifest)
    else:
        movie_path = ROOT/'raw'/f'{appid}-{movie["id"]}.video'
        if not movie_path.exists():
            movie_path.write_bytes(fetch(url))
        probe = subprocess.run(['ffprobe', '-v', 'quiet', '-show_format', '-show_streams', '-of', 'json', str(movie_path)], check=True, capture_output=True, text=True)
        duration = float(json.loads(probe.stdout)['format']['duration'])
        movie_hash = hashlib.sha256(movie_path.read_bytes()).hexdigest()
    if fractions is not None:
        if any(x < 0 or x >= 1 for x in fractions):
            raise ValueError('Fractions must be >= 0 and < 1')
        times = [round(duration*x, 2) for x in fractions]
    rows = []
    for seconds in times:
        if seconds < 0 or seconds >= duration:
            raise ValueError(f'Frame time outside movie: {seconds}/{duration}')
        offset = seconds
        segment_info = None
        if stream:
            repid, template, segment_duration = stream
            segment_index = int(seconds // segment_duration)
            number = int(template.get('startNumber', 1))+segment_index
            init = template['initialization'].replace('$RepresentationID$', repid)
            media = template['media'].replace('$RepresentationID$', repid)
            media = re.sub(r'\$Number%0(\d+)d\$', lambda m: f'{number:0{m[1]}d}', media).replace('$Number$', str(number))
            init_url, segment_url = urljoin(url, init), urljoin(url, media)
            init_path = ROOT/'raw'/f'{appid}-{movie["id"]}-init-{repid}.m4s'
            if not init_path.exists():
                init_path.write_bytes(fetch(init_url))
            segment_path = ROOT/'raw'/f'{appid}-{movie["id"]}-{repid}-{number}.m4s'
            if not segment_path.exists():
                segment_path.write_bytes(fetch(segment_url))
            movie_path = ROOT/'raw'/f'{appid}-{movie["id"]}-{repid}-{number}.mp4'
            movie_path.write_bytes(init_path.read_bytes()+segment_path.read_bytes())
            offset = seconds-segment_index*segment_duration
            segment_info = {'url': segment_url, 'segment_start_seconds': segment_index*segment_duration,
                            'sha256': hashlib.sha256(segment_path.read_bytes()).hexdigest()}
        target = ROOT/'frames'/f'{appid}-{seconds:06.2f}.jpg'
        subprocess.run(['ffmpeg', '-hide_banner', '-loglevel', 'error', '-y', '-ss', str(offset), '-i', str(movie_path), '-frames:v', '1', '-vf', 'scale=min(1280\\,iw):-2', '-q:v', '2', str(target)], check=True)
        if not target.exists():
            raise ValueError(f'No decoded frame for {seconds}')
        rows.append({'id': f'{appid}@{seconds:.2f}', 'seconds': seconds,
                     'file': str(target.relative_to(ROOT)), 'sha256': hashlib.sha256(target.read_bytes()).hexdigest(),
                     'segment': segment_info})
    manifest = {'appid': appid, 'name': data['name'], 'store_page': f'https://store.steampowered.com/app/{appid}/',
                'retrieved_at': now(), 'source_metadata': data['_source_url'],
                'movie_name': movie.get('name'), 'movie_id': movie['id'], 'movie_url': url,
                'media_source_sha256': movie_hash, 'hash_scope': 'DASH manifest' if stream else 'full source video',
                'duration_seconds': duration, 'source_kind': 'publisher Steam store video; edited trailer',
                'observation_limit': 'selected still frames only; no full playback or player-input observation',
                'frames': rows}
    save(ROOT/'frames'/f'{appid}.json', manifest)
    print(appid, duration, [r['id'] for r in rows])


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    sub = parser.add_subparsers(dest='mode', required=True)
    r = sub.add_parser('rankings'); r.add_argument('--only', nargs='+', choices=list(TAGS)); r.add_argument('--output', default='rankings.json')
    c = sub.add_parser('catalog'); c.add_argument('appids', type=int, nargs='+')
    f = sub.add_parser('frames'); f.add_argument('appid', type=int); f.add_argument('--movie', type=int, default=0)
    time_group = f.add_mutually_exclusive_group(required=True)
    time_group.add_argument('--at', type=float, nargs='+')
    time_group.add_argument('--fractions', type=float, nargs='+')
    args = parser.parse_args()
    if args.mode == 'rankings': rankings(args.only, args.output)
    elif args.mode == 'catalog': catalog(args.appids)
    else: frames(args.appid, args.movie, args.at, args.fractions)
