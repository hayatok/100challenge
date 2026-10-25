#!/usr/bin/env python3
"""Build the proposal sources, inspectable phone mockups and seven PDFs."""
import argparse
import html
import json
import math
from pathlib import Path
from xml.sax.saxutils import escape
from reportlab.pdfgen import canvas
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.lib.colors import HexColor, Color, white
from reportlab.lib.pagesizes import A4
from reportlab.platypus import Paragraph
from reportlab.lib.styles import ParagraphStyle
from reportlab.lib.utils import ImageReader

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'output' / 'pdf'
W, H = A4
INK = '#20252C'
MUTED = '#56606C'
PAPER = '#FAF8F3'
BOUNDS = []
MOCK = {
 '01-rail': ['工事点 3 / 残弾 1', 'レールを防壁へ', '補給2が停止。砲台は無傷、反撃後の残弾は0。', ['線路を選ぶ','防壁にする','取消'], 'セナ', 'その線を閉じるなら、次の一手まで一緒に考えよう。'],
 '02-beast': ['行動点 2 / 命令 3', '獣を待機させる', '命令を1回使い、見張りが過ぎるまで穴の手前で待つ。', ['未来を比べる','待機を命令','取消'], 'ミオ', '今日はあの子も、あなたの帰りを待っていたみたい。'],
 '03-garden': ['樹液 3 / 木材 0', '剪定中・時間停止', '木材2を得る。この近道を失い、作業台で衝撃ガードへ。', ['枝を選ぶ','剪定する','取消'], 'コトネ', 'これ、余った花で作ったの。……余ったから、だけじゃないけど。'],
 '04-inn': ['食数 2 / 明夜空室 2', '契約B：二夜で120', '食数を残す代わりに、明夜の空室は1になる。', ['条件を比べる','契約する','取消'], 'マオ', '閉店後まで支配人でいなくても、いいでしょう？'],
 '05-detective': ['調査枠 6 / 工房在庫 2', '工房印の矛盾を公表', '謝礼80を得る。翌朝の在庫評価は計60下がる。', ['証拠を見る','公開する','保留'], 'スイ', '見抜かれるのは得意じゃないの。あなたには、特に。'],
 '06-auction': ['食料 6 / 資金 8', '港の通行権に入札', '畑を担保にすると、返済まで収穫が2減る。', ['担保を選ぶ','入札する','取消'], 'リゼ', '今夜くらい、計算書は閉じましょう。二人分の時間は、残してあります。'],
}

def data():
    return [json.loads(p.read_text()) for p in sorted((ROOT/'concepts').glob('*.json'))]

def style(size=10.5, color=INK, leading=None):
    return ParagraphStyle('JP', fontName='JP', fontSize=size, leading=leading or size*1.62,
                          textColor=HexColor(color), wordWrap='CJK', spaceAfter=0)

def para(c, text, x, top, width, size=10.5, color=INK, leading=None):
    if not text:
        return top
    p = Paragraph(escape(str(text)).replace('\n','<br/>'), style(size,color,leading))
    _, height = p.wrap(width, 2000)
    if top-height < 48:
        raise ValueError(f'Page overflow: {text[:45]} bottom={top-height:.1f}')
    p.drawOn(c,x,top-height)
    BOUNDS.append({'page':c.getPageNumber(),'bottom':round(top-height,2),'text':text[:35]})
    return top-height

def sections(c, items, x, top, width, accent, size=10.5, gap=17):
    for item in items:
        top=para(c,item['heading'],x,top,width,12,accent,17)-7
        top=para(c,item['text'],x,top,width,size)-gap
    return top

def frame(c,d,page):
    c.setFillColor(HexColor(PAPER)); c.rect(0,0,W,H,fill=1,stroke=0)
    c.setFillColor(HexColor(d['accent'])); c.rect(0,H-10,W,10,fill=1,stroke=0)
    c.setFont('Helvetica',9); c.setFillColor(HexColor(MUTED))
    c.drawString(40,H-36,f'100CHALLENGE / CONCEPT {d["id"][:2]} / 2026.10.25')
    title=d['pages'][page]['title']
    title_size=min(22,(W-80)/pdfmetrics.stringWidth(title,'JP',1))
    para(c,title,40,H-57,W-80,title_size,INK,29)
    para(c,d['pages'][page]['lead'],40,H-103,W-80,10.5,MUTED)
    c.setStrokeColor(HexColor('#D9D9D3')); c.line(40,43,W-40,43)
    c.setFont('JP',7.5); c.setFillColor(HexColor(MUTED))
    c.drawString(40,28,'企画イメージ・未実装 / 面白さと性能は試作で確認する設計仮説')
    c.drawRightString(W-40,28,f'{page+1:02d} / 06')

def art(c,path,x,y,w,h,panel=None,focus=0.5):
    img=ImageReader(str(path)); iw,ih=img.getSize()
    c.saveState(); p=c.beginPath(); p.rect(x,y,w,h); c.clipPath(p,stroke=0)
    if panel is None:
        scale=max(w/iw,h/ih); dw,dh=iw*scale,ih*scale
        c.drawImage(img,x+(w-dw)/2,y+(h-dh)/2,dw,dh)
    else:
        pw=iw/3; scale=max(w/pw,h/ih); dw,dh=iw*scale,ih*scale
        c.drawImage(img,x+(w-pw*scale)/2-panel*pw*scale,y+h/2-dh*focus,dw,dh)
    c.restoreState()

def choice_diagram(c,d):
    spec=MOCK[d['id']]; y=570; cw=(W-94)/2
    for j,(head,body) in enumerate([('選んだ操作',spec[1]),('確定後の変化',spec[2])]):
        x=40+j*(cw+14)
        c.setFillColor(HexColor('#EEECE6')); c.roundRect(x,y,cw,102,7,fill=1,stroke=0)
        para(c,head,x+14,y+86,cw-28,10,d['accent'])
        para(c,body,x+14,y+60,cw-28,11)

def sources_md(d):
    result=[]
    for a in d['assets']:
        result.append(f'- {a["name"]} / {a["license"]} / {a["role"]}')
        if a['url']:
            result.append(f'  {a["url"]}')
    for a in d['comparables']:
        result += [f'- 比較作：{a["name"]}。{a["difference"]}',f'  {a["url"]}']
    return '\n'.join(result)

def source_files(all_data):
    for d in all_data:
        lines=[f'# {d["title"]}',d['genres'],'','企画イメージ・未実装。設計目標と見積は実測ではない。','',d['pitch'],'',
               f'![3面の企画イメージ](../art/{d["id"]}.png)','']
        for i,p in enumerate(d['pages']):
            lines += [f'## {i+1}. {p["title"]}','',p['lead'],'']
            if i==3:
                for h in d['heroes']:
                    lines += [f'### {h["name"]}（{h["age"]}歳）','',h['appearance'],h['work'],h['private'],h['dialogue'],'']
            for s in p['sections']:
                lines += [f'### {s["heading"]}','',s['text'],'']
        lines += ['## 素材・比較作の出典','',sources_md(d),'','確認日：2026-10-25。素材本体の同梱ライセンスは採用時に再照合する。']
        (ROOT/'concepts'/f'{d["id"]}.md').write_text('\n'.join(lines)+'\n')

def mock_html(d,mode):
    s=MOCK[d['id']]; esc=html.escape
    dialog=mode=='talk'; idx=2 if dialog else 1
    title='帰還後の交流' if dialog else s[0]
    focus=s[4] if dialog else s[1]
    desc=s[5] if dialog else s[2]
    buttons=['返事をする','ログ','設定'] if dialog else s[3]
    return f'''<!doctype html><html lang="ja"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover"><title>{esc(d['title'])}・画面モック</title>
<style>*{{box-sizing:border-box}}html,body{{margin:0;width:100%;height:100%;overflow:hidden;background:#151a22;color:#fff;font-family:'Noto Sans JP','Hiragino Kaku Gothic ProN',sans-serif}}main{{height:100dvh;display:grid;grid-template-rows:44px minmax(0,1fr) 195px;padding-bottom:env(safe-area-inset-bottom)}}header{{display:flex;align-items:center;justify-content:space-between;padding:0 14px;background:#171d25;font-size:13px;gap:6px}}header span{{white-space:nowrap}}header small{{font-size:10px;color:#d7dce3}}.scene{{position:relative;overflow:hidden;min-height:0}}.art{{position:absolute;inset:0;background-image:url('../../art/{d['id']}.png');background-size:300% 100%;background-position:{idx*50}% 50%}}.scene:after{{content:'';position:absolute;inset:0;box-shadow:inset 0 -80px 60px -30px #10151aa0;pointer-events:none}}.badge{{position:absolute;z-index:1;top:12px;left:12px;background:#14202eea;border:1px solid #ffffff70;border-radius:4px;padding:7px 10px;font-size:12px}}.select{{position:absolute;z-index:2;left:40%;top:48%;width:64px;height:64px;border:3px solid #ffe7a2;border-radius:12px;background:#ffd96724;color:#fff;font-size:12px;box-shadow:0 0 0 7px #161f2970}}.panel{{padding:14px 16px 12px;background:#f7f2e9;color:#20252c;display:flex;flex-direction:column;gap:8px;min-height:0}}h1{{margin:0;font-size:17px;line-height:1.4}}p{{margin:0;font-size:14px;line-height:1.5;min-height:42px}}.actions{{display:flex;gap:8px;margin-top:auto}}button{{font:inherit;min-height:46px;border:2px solid #293440;border-radius:5px;background:#fffdf8;color:#20252c;font-size:13px;font-weight:600}}.actions button{{flex:1;padding:5px}}.actions .confirm{{background:{d['accent']};color:white;border-color:{d['accent']}}}button:focus-visible{{outline:3px solid #116daf;outline-offset:2px}}.notice{{font-size:10px;color:#5a626c;line-height:1.2}}.chosen{{background:#d5ad4345;border-color:#fff}}@media(max-height:740px){{main{{grid-template-rows:40px minmax(0,1fr) 187px}}.panel{{padding:10px 14px}}}}</style>
<main><header><span>{esc(title)}</span><small>企画画面・未実装</small></header><section class="scene"><div class="art"></div><div class="badge">{esc('交流ログを任意に開ける' if dialog else '選択中も結果を確認')}</div>{'' if dialog else '<button class="select" aria-label="対象を選択">選択</button>'}</section><section class="panel"><h1>{esc(focus)}</h1><p id="description">{esc(desc)}</p><div class="actions">{''.join(f'<button class="{ "confirm" if n==1 else ""}">{esc(b)}</button>' for n,b in enumerate(buttons))}</div><div class="notice">静止画と選択表示のモック。ゲームの進行処理はありません。</div></section></main>
<script>const original={json.dumps(desc,ensure_ascii=False)};const p=document.querySelector('#description');document.querySelectorAll('button').forEach((b)=>b.addEventListener('click',()=>{{if(['取消','保留'].includes(b.textContent)){{p.textContent=original;document.querySelector('.select')?.classList.remove('chosen')}}else if(b.classList.contains('select')){{b.classList.toggle('chosen');p.textContent='対象を選択中。下部で影響を読み、確定か取消を選びます。'}}else{{p.textContent='表示確認用のモックです。選択した操作：'+b.textContent;}}}}));</script></html>'''

def html_files(all_data):
    target=ROOT/'output'/'mocks'; target.mkdir(parents=True,exist_ok=True)
    for d in all_data:
        for mode in ['play','talk']:
            (target/f'{d["id"]}-{mode}.html').write_text(mock_html(d,mode))
    cards=''.join(f'<article><img src="art/{d["id"]}.png" alt="{html.escape(d["title"])}の3面企画イメージ"><h2>{html.escape(d["title"])}</h2><p>{html.escape(d["genres"])}</p><p>{html.escape(d["facts"]["mechanic"])}</p><a href="output/pdf/{d["id"]}.pdf">6ページの企画書PDF</a> · <a href="concepts/{d["id"]}.md">編集元</a> · <a href="output/mocks/{d["id"]}-play.html">プレイ画面モック</a> · <a href="output/mocks/{d["id"]}-talk.html">交流画面モック</a></article>' for d in all_data)
    (ROOT/'index.html').write_text(f'''<!doctype html><html lang="ja"><meta charset="utf-8"><meta name="viewport" content="width=device-width"><title>6つのゲーム企画</title><style>body{{font-family:system-ui,sans-serif;background:#f4f0e8;color:#20252c;max-width:1100px;margin:32px auto;padding:0 20px;line-height:1.7}}h1{{font-size:32px}}.grid{{display:grid;grid-template-columns:repeat(auto-fit,minmax(280px,1fr));gap:24px}}article{{background:#fffdf8;padding:20px;border-top:4px solid #b73529}}img{{width:100%;height:auto}}a{{color:#9c3028}}h2{{margin:12px 0 4px}}.intro{{max-width:760px}}</style><h1>6つのゲーム企画</h1><p class="intro">スマホWeb・片手縦持ち・1回10〜20分。ジャンルの掛け算と、成人ヒロインとの濃い交流を比較する企画資料です。掲載画面は未実装のイメージです。</p><p><a href="output/pdf/00-comparison.pdf">最初に比較資料を読む（2ページ）</a></p><div class="grid">{cards}</div></html>''')

def proposals(all_data):
    for d in all_data:
        c=canvas.Canvas(str(OUT/f'{d["id"]}.pdf'),pagesize=A4)
        c.setTitle(d['title']+' / ゲーム企画書'); c.setAuthor('100challenge / Codex')
        image=ROOT/'art'/f'{d["id"]}.png'
        for i,p in enumerate(d['pages']):
            frame(c,d,i)
            if i==0:
                para(c,d['title'],40,689,W-80,30,INK,39)
                para(c,d['genres'],40,638,W-80,11,d['accent'])
                art(c,image,40,372,W-80,229)
                para(c,'左：キーアート / 中：プレイ美術案 / 右：交流案（配置・装備は省略）',40,359,W-80,8.5,MUTED)
                y=para(c,d['pitch'],40,332,W-80,11)-22
                sections(c,p['sections'],40,y,W-80,d['accent'],10.5,13)
            elif i==1:
                choice_diagram(c,d)
                sections(c,p['sections'],40,542,W-80,d['accent'],10.5,16)
            elif i==2:
                for j,(head,key) in enumerate([('最初の15分','early'),('中盤の15分','mid')]):
                    x=40+j*(W-65)/2; bw=(W-95)/2
                    c.setFillColor(HexColor('#EEECE6'));c.roundRect(x,574,bw,103,7,fill=1,stroke=0)
                    para(c,head,x+12,661,bw-24,11,d['accent'])
                    para(c,d['facts'][key],x+12,635,bw-24,10)
                sections(c,p['sections'],40,546,W-80,d['accent'],10.5,16)
            elif i==3:
                art(c,image,40,386,210,282,2)
                y=674
                for h in d['heroes']:
                    y=para(c,f'{h["name"]} / {h["age"]}歳',270,y,W-310,14,d['accent'])-5
                    y=para(c,h['appearance']+' '+h['work'],270,y,W-310,9.7)-8
                    y=para(c,h['dialogue'],270,y,W-310,10.2)-18
                para(c,'交流イメージ。表情・衣装・演出は制作前の方向性。',40,373,W-80,8.3,MUTED)
                sections(c,p['sections'],40,345,W-80,d['accent'],10.3,14)
            elif i==4:
                for j,mode in enumerate(['play','talk']):
                    x=73+j*252
                    shot=ROOT/'output'/'mocks'/f'{d["id"]}-{mode}-390.png'
                    c.setFillColor(HexColor('#19232F'));c.roundRect(x-4,337,168,354,13,fill=1,stroke=0)
                    art(c,shot,x,341,160,346.25)
                    para(c,'プレイ / 390×844' if j==0 else '交流 / 390×844',x,329,190,9,MUTED)
                for j in range(2):
                    sections(c,p['sections'][j*2:j*2+2],40+j*(W-65)/2,305,(W-95)/2,d['accent'],9.3,12)
            else:
                y=sections(c,p['sections'],40,687,W-80,d['accent'],9.8,13)
                y=para(c,'素材と比較作 / 一次資料・確認日 2026-10-25',40,y+1,W-80,11,d['accent'])-7
                for a in d['assets']:
                    y=para(c,a['name']+' / '+a['license']+' / '+a['role'],40,y,W-80,8.2,INK,11.5)
                    y=link(c,a['url'],40,y-2,W-80)-5
                for a in d['comparables']:
                    y=para(c,'比較：'+a['name']+'。'+a['difference'],40,y,W-80,8.2,INK,11.5)
                    y=link(c,a['url'],40,y-2,W-80)-5
            c.showPage()
        c.save()

def link(c,url,x,y,width):
    # Avoid long URLs overflowing: the visible label is short and the annotation carries the full URL.
    from urllib.parse import urlsplit
    u=urlsplit(url); label=u.netloc+u.path
    if len(label)>83: label=label[:80]+'...'
    top=y
    y=para(c,label,x,y,width,7.8,'#315B82',10)
    c.linkURL(url,(x,y,x+width,top),relative=0,thickness=0)
    return y

def comparison(all_data):
    c=canvas.Canvas(str(OUT/'00-comparison.pdf'),pagesize=A4)
    c.setTitle('6つのゲーム企画 / 比較と選定');c.setAuthor('100challenge / Codex')
    for page in range(2):
        c.setFillColor(HexColor(PAPER));c.rect(0,0,W,H,fill=1,stroke=0)
        para(c,'6つのゲーム企画' if page==0 else '次に試す企画を選ぶ',40,798,W-80,26,INK,36)
        para(c,'スマホWeb / 片手縦持ち / 10〜20分 / ゲーム中心の濃い交流' if page==0 else '評価は企画者の設計判断。面白さ・制作期間・実機性能は未検証。',40,751,W-80,10.5,MUTED)
        if page==0:
            for i,d in enumerate(all_data):
                y=695-i*103
                art(c,ROOT/'art'/f'{d["id"]}.png',40,y-77,112,77,0,focus=0.7)
                para(c,d['id'][:2]+'  '+d['title'],165,y,W-205,14,d['accent'])
                para(c,d['genres'],165,y-26,W-205,9.5,MUTED)
                para(c,d['facts']['mechanic'],165,y-46,W-205,10,INK,14)
                c.linkURL(d['id']+'.pdf',(40,y-78,W-40,y+5),relative=1,thickness=0)
        else:
            rows=[('総合の第一候補：六部屋の約束','空間と契約の損得が読みやすく、共同生活とヒロイン交流を自然につなげられる。最大の難所は契約条件のUI。まず一晩の予約調整を試す。'),
                  ('戦略の手応えを優先：線路の砦','輸送と防壁が同じ設備を取り合うため、ジャンルの干渉を説明しやすい。閉鎖が緊急ボタンだけにならず、攻めの選択にもなるかを試す。'),
                  ('相棒への愛着を優先：忍び獣の飼い方','獣の成長とヒロインとの共有体験がつながる。習慣の違いが解法の違いになり、命令を聞かない苛立ちにならないかが採否を決める。'),
                  ('探索と手触りを優先：枝を刈る冒険者','道と装備を同じ植物から作る冒険。縦画面での移動と剪定の切替、退路を失う判断の楽しさを先に確認する。'),
                  ('謎解きと会話を優先：値札の裏の探偵','真実の公開が経営に跳ね返る。事件分岐と価格変化の説明に制作量がかかるため、一つの品物で複数の納得できる選択を作れるかを見る。'),
                  ('経済の駆け引きを優先：競売国家','拡張と生産停止が衝突する。競売AI、独走防止、返済予測が難所。19区画程度の小さな盤面で判断が成立するかを見る。')]
            y=700
            for heading,body in rows:
                y=para(c,heading,40,y,W-80,12,'#B73529')-5
                y=para(c,body,40,y,W-80,10.3)-16
            y=para(c,'共通の採否基準',40,y,W-80,12,'#B73529')-5
            para(c,'最初と中盤で判断が変わるか。片手で予測・確定・訂正できるか。失敗後も交流が続くか。ヒロインの表情や会話を量産できるか。初期装備でも本編を進め、好感度稼ぎを戦力の条件にしないか。',40,y,W-80,10.3)
        c.setFont('JP',8);c.setFillColor(HexColor(MUTED));c.drawString(40,27,'企画比較 / 全案未実装 / 2026-10-25');c.drawRightString(W-40,27,f'{page+1} / 2');c.showPage()
    c.save()
    text=['# 6つのゲーム企画の比較','','共通条件：スマホWeb、片手縦持ち、1回10〜20分。ゲーム中心の濃い交流。成人ヒロイン各2人。全案未実装。','']
    for d in all_data:
        text += [f'## {d["title"]}',d['genres'],d['facts']['mechanic'],d['facts']['moe'],d['facts']['hardest'],d['facts']['effort'],'']
    text += ['## 推奨と評価の限界','総合の第一候補は六部屋の約束。戦略優先なら線路の砦、愛着優先なら忍び獣の飼い方。これは設計上の判断であり、面白さを実証した順位ではない。','実機操作、長時間プレイ、アセットのインポートと量産、制作期間は未確認。','']
    (ROOT/'concepts'/'00-comparison.md').write_text('\n'.join(text))

def main():
    ap=argparse.ArgumentParser();ap.add_argument('--prepare-only',action='store_true');ap.add_argument('--font',default='/Library/Fonts/Arial Unicode.ttf');args=ap.parse_args()
    all_data=data();assert len(all_data)==6,'Expected six concept JSON files'
    for d in all_data:
        assert len(d['pages'])==6 and len(d['heroes'])==2
        assert all(h['age']>=20 for h in d['heroes'])
    OUT.mkdir(parents=True,exist_ok=True)
    source_files(all_data);html_files(all_data)
    if args.prepare_only:return
    pdfmetrics.registerFont(TTFont('JP',args.font))
    proposals(all_data);comparison(all_data)
    (ROOT/'docs'/'verification'/'layout-bounds.json').write_text(json.dumps(BOUNDS,ensure_ascii=False,indent=2))
    print(json.dumps({'pdfs':len(list(OUT.glob('*.pdf'))),'text_blocks':len(BOUNDS),'minimum_text_bottom':min(x['bottom'] for x in BOUNDS)}))

if __name__=='__main__':main()
