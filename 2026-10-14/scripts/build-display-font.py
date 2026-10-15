"""Create the small renamed Black-weight display font. Requires fontTools for rebuilding only."""
from pathlib import Path
import hashlib
import json
import urllib.request
from fontTools import subset
from fontTools.ttLib import TTFont

APP = Path(__file__).resolve().parent.parent
SOURCE_REVISION = '165c01b46ea533872e002e0785ff17e44f6d97d8'
SOURCE_URL = f'https://raw.githubusercontent.com/notofonts/noto-cjk/{SOURCE_REVISION}/Sans/OTF/Japanese/NotoSansCJKjp-Black.otf'
SOURCE_SHA256 = 'cd66686594a861a42fe752990a406fcedafb51b3a91d6639f30f8948f7a10b4d'
source = APP / '.cache/fonts/NotoSansCJKjp-Black.otf'
source.parent.mkdir(parents=True, exist_ok=True)
if not source.exists():
    with urllib.request.urlopen(SOURCE_URL, timeout=90) as response:
        source.write_bytes(response.read())
assert hashlib.sha256(source.read_bytes()).hexdigest() == SOURCE_SHA256, 'Unexpected source font'

supplement = '''全力退勤定時だ。飛べ。退勤する再開するもう一度タイトルへ設定クレジット押す離す回復消火器残圧空不足高速噴射
離して回復壁、定時です！ドガァン!!シュゴーッ!!書類、全提出！総務、見てない！コピー用紙、放出！定時ラッシュ！
退勤成功！自己ベスト！爆速帰宅定時の覇者見事な退勤おつかれさま帰れたので勝ち被害総額最大連鎖退勤TIME EXIT
SPACE ENTER TAB R ESC A D B S SS SSS 0123456789%¥↑↓←→ⅠⅡⅢ×!?：.・/ -_ PRESS NO.017 JOB DONE TIME ATTACK
納品打刻残り領収書勤務終了準備復帰ベスト記録を保存できませんでした損害対応祝帰宅紙吹雪連鎖継続中連鎖終了
派手標準控えめひと休み一時停止音量効果音BGM閉じる秒万円再挑戦会社には内緒ポーズ保留中請求明細演出量''' 
text = supplement + ''.join(p.read_text() for folder in ('game', 'docs') for p in (APP / folder).rglob('*') if p.suffix in ('.gd', '.md'))
unicodes = {ord(c) for c in text} | set(range(0x20, 0x7f)) | set(range(0x3000, 0x3100)) | set(range(0xff00, 0xfff0))
font = TTFont(source, recalcTimestamp=False)
options = subset.Options()
options.name_IDs = ['*']
options.name_languages = ['*']
options.layout_features = ['*']
options.recalc_timestamp = False
subsetter = subset.Subsetter(options=options)
subsetter.populate(unicodes=unicodes)
subsetter.subset(font)
# Keep original copyright/license records, and replace reserved family/PS names.
names = {1:'TaikinComic', 2:'Black', 3:'TaikinComic Black v0.5', 4:'TaikinComic Black',
         6:'TaikinComic-Black', 16:'TaikinComic', 17:'Black'}
for record in font['name'].names:
    if record.nameID in names:
        record.string = names[record.nameID].encode(record.getEncoding())
cff = font['CFF '].cff
cff.fontNames = ['TaikinComic-Black']
cff.topDictIndex[0].FamilyName = 'TaikinComic'
cff.topDictIndex[0].FullName = 'TaikinComic Black'
destination = APP / 'game/assets/fonts/TaikinComic-Black.otf'
font.save(destination)
metadata = {'font':'TaikinComic Black', 'derived_from':'Noto Sans CJK JP Black 2.004',
            'license':'SIL Open Font License 1.1', 'source':SOURCE_URL, 'source_sha256':SOURCE_SHA256,
            'bytes':destination.stat().st_size, 'glyphs':len(font.getGlyphOrder()),
            'purpose':'Heavy readable comic HUD headings. Subset and renamed; normal game/CI uses the committed font.'}
(destination.parent / 'DISPLAY_FONT.json').write_text(json.dumps(metadata, ensure_ascii=False, indent=2) + '\n')
print(f"Display font: {metadata['glyphs']} glyphs, {metadata['bytes']:,} bytes")
