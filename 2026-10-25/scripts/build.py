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
from reportlab.platypus import (Paragraph, Spacer, Table, TableStyle, Flowable, KeepTogether,
                               BaseDocTemplate, PageTemplate, Frame, PageBreak,
                               NextPageTemplate)
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
 '01-rail': ['工事点3 / 砲台の弾1', '線路を壁に変える', 'この線路の補給は止まります。砲台は攻撃を防げますが、反撃後の弾は0になります。', ['線路を選ぶ','壁に変える','取り消す'], 'セナ', 'その線路を壁に変えるなら、その後の補給も一緒に考えよう。'],
 '02-beast': ['行動点2 / 命令あと3回', '獣に待つよう命令する', '命令を1回使います。獣は穴の手前で待ち、見張りをやり過ごします。', ['行動を比べる','待機を命令','取り消す'], 'ミオ', '今日はあの子も、あなたの帰りを待っていたみたい。'],
 '03-garden': ['樹液3 / 木材0', '枝を切る前に確認', '木材を2個得ますが、この近道は消えます。木材は衝撃ガードの材料になります。', ['枝を選ぶ','この枝を切る','取り消す'], 'コトネ', 'これ、余った花で作ったの。……余ったから、だけじゃないけど。'],
 '04-inn': ['食事あと2食 / 明日の空室2', '120で今夜と明日を貸す', '客が120を払い、2泊します。食事は付きません。明日の空室は1室になります。', ['条件を比べる','契約する','取り消す'], 'マオ', '閉店後まで支配人でいなくても、いいでしょう？'],
 '05-detective': ['調査あと6回 / 同工房の品2点', '鑑定結果を公表する', '謝礼80を受け取ります。翌朝には在庫2点の相場が下がり、合計60の値下がりになります。', ['証拠を見る','公表する','保留する'], 'スイ', '見抜かれるのは得意じゃないの。あなたには、特に。'],
 '06-auction': ['現金6 / 食料2', '畑を担保に10で入札', '落札した場合、畑の収穫が止まり、食料が1足りなくなります。食料を買うと現金は0になり、借りた4の返済が残ります。', ['担保を選ぶ','入札する','取り消す'], 'リゼ', '今夜くらい、計算書は閉じましょう。二人分の時間は、残してあります。'],
}

def data():
    return [json.loads(p.read_text()) for p in sorted((ROOT/'concepts').glob('*.json'))]

def style(size=10.5, color=INK, leading=None):
    return ParagraphStyle('JP', fontName='JP', fontSize=size, leading=leading or size*1.62,
                          textColor=HexColor(color), wordWrap='CJK', spaceAfter=0)

class ArtBlock(Flowable):
    def __init__(self, path, width, height, panel=None):
        super().__init__()
        self.path, self.width, self.height, self.panel = path, width, height, panel

    def draw(self):
        art(self.canv, self.path, 0, 0, self.width, self.height, self.panel)

def paragraph(text, size=11.2, color=INK, heading=False):
    spec = style(size, color, size*1.65)
    spec.spaceAfter = 8 if not heading else 5
    spec.spaceBefore = 9 if heading else 0
    spec.keepWithNext = heading
    spec.allowWidows = 0
    spec.allowOrphans = 0
    return Paragraph(escape(str(text)).replace('\n', '<br/>'), spec)

def text_sections(items, accent, size=11.2):
    flows=[]
    for item in items:
        flows.append(paragraph(item['heading'], 12.5, accent, heading=True))
        flows.extend(paragraph(part, size) for part in item['text'].split('\n\n') if part.strip())
    return flows

def chapter_header(c, doc, d, chapter):
    c.setFillColor(HexColor(PAPER)); c.rect(0,0,W,H,fill=1,stroke=0)
    c.setFillColor(HexColor(d['accent'])); c.rect(0,H-8,W,8,fill=1,stroke=0)
    c.setFillColor(HexColor(MUTED)); c.setFont('Helvetica',8.5)
    c.drawString(40,H-34,f'100CHALLENGE / CONCEPT {d["id"][:2]} / 2026.10.25')
    title=d['pages'][chapter]['title']
    size=min(21,(W-80)/pdfmetrics.stringWidth(title,'JP',1))
    para(c,title,40,H-54,W-80,size,INK,28)
    para(c,d['pages'][chapter]['lead'],40,H-96,W-80,10.5,MUTED,16)
    c.setStrokeColor(HexColor('#D9D9D3')); c.line(40,42,W-40,42)
    c.setFillColor(HexColor(MUTED)); c.setFont('JP',7.7)
    c.drawString(40,27,'開発前の企画案です。ゲームの動作や面白さは、試作後に確認します。')
    c.drawRightString(W-40,27,str(doc.page))

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
        lines=[f'# {d["title"]}',d['genres'],'','開発前の企画案です。画像は完成後の画面を想像するためのもので、ゲームはまだ実装していません。プレイ時間と開発期間は目標です。','',d['pitch'],'',
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
    title='仕事のあとの会話' if dialog else s[0]
    focus=s[4] if dialog else s[1]
    desc=s[5] if dialog else s[2]
    buttons=['返事をする','ログ','設定'] if dialog else s[3]
    return f'''<!doctype html><html lang="ja"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover"><title>{esc(d['title'])}・画面モック</title>
<style>*{{box-sizing:border-box}}html,body{{margin:0;width:100%;height:100%;overflow:hidden;background:#151a22;color:#fff;font-family:'Noto Sans JP','Hiragino Kaku Gothic ProN',sans-serif}}main{{height:100dvh;display:grid;grid-template-rows:56px minmax(0,1fr) 230px;padding-bottom:env(safe-area-inset-bottom)}}header{{display:flex;align-items:center;justify-content:space-between;padding:0 14px;background:#171d25;font-size:13px;gap:6px}}header span{{max-width:65%;font-size:12px;line-height:1.4}}header small{{max-width:35%;font-size:9px;color:#d7dce3;text-align:right}}.scene{{position:relative;overflow:hidden;min-height:0}}.art{{position:absolute;inset:0;background-image:url('../../art/{d['id']}.png');background-size:300% 100%;background-position:{idx*50}% 50%}}.scene:after{{content:'';position:absolute;inset:0;box-shadow:inset 0 -80px 60px -30px #10151aa0;pointer-events:none}}.badge{{position:absolute;z-index:1;top:12px;left:12px;background:#14202eea;border:1px solid #ffffff70;border-radius:4px;padding:7px 10px;font-size:12px}}.select{{position:absolute;z-index:2;left:40%;top:48%;width:64px;height:64px;border:3px solid #ffe7a2;border-radius:12px;background:#ffd96724;color:#fff;font-size:12px;box-shadow:0 0 0 7px #161f2970}}.panel{{padding:14px 16px 12px;background:#f7f2e9;color:#20252c;display:flex;flex-direction:column;gap:8px;min-height:0}}h1{{margin:0;font-size:17px;line-height:1.4}}p{{margin:0;font-size:14px;line-height:1.5;min-height:42px}}.actions{{display:flex;gap:8px;margin-top:auto}}button{{font:inherit;min-height:46px;border:2px solid #293440;border-radius:5px;background:#fffdf8;color:#20252c;font-size:13px;font-weight:600}}.actions button{{flex:1;padding:5px}}.actions .confirm{{background:{d['accent']};color:white;border-color:{d['accent']}}}button:focus-visible{{outline:3px solid #116daf;outline-offset:2px}}.notice{{font-size:10px;color:#5a626c;line-height:1.2}}.chosen{{background:#d5ad4345;border-color:#fff}}@media(max-height:740px){{main{{grid-template-rows:52px minmax(0,1fr) 226px}}.panel{{padding:10px 14px}}}}</style>
<main><header><span>{esc(title)}</span><small>開発前の画面イメージ</small></header><section class="scene"><div class="art"></div><div class="badge">{esc(s[4]+'との会話' if dialog else '確定前に結果を確認')}</div>{'' if dialog else '<button class="select" aria-label="対象を選択">選択</button>'}</section><section class="panel"><h1>{esc(focus)}</h1><p id="description">{esc(desc)}</p><div class="actions">{''.join(f'<button class="{ "confirm" if n==(0 if dialog else 1) else ""}">{esc(b)}</button>' for n,b in enumerate(buttons))}</div><div class="notice">画面構成を確認する見本です。ゲームは進行しません。</div></section></main>
<script>const original={json.dumps(desc,ensure_ascii=False)};const p=document.querySelector('#description');document.querySelectorAll('button').forEach((b)=>b.addEventListener('click',()=>{{if(['取り消す','保留する'].includes(b.textContent)){{p.textContent=original;document.querySelector('.select')?.classList.remove('chosen')}}else if(b.classList.contains('select')){{b.classList.toggle('chosen');p.textContent='対象を選びました。下の説明を読んで、実行するか取り消すかを決めてください。'}}else{{p.textContent='画面の表示例です。選んだ操作：'+b.textContent;}}}}));</script></html>'''

def html_files(all_data):
    target=ROOT/'output'/'mocks'; target.mkdir(parents=True,exist_ok=True)
    for d in all_data:
        for mode in ['play','talk']:
            (target/f'{d["id"]}-{mode}.html').write_text(mock_html(d,mode))
    cards=''.join(f'<article><img src="art/{d["id"]}.png" alt="{html.escape(d["title"])}の3面企画イメージ"><h2>{html.escape(d["title"])}</h2><p>{html.escape(d["genres"])}</p><p>{html.escape(d["facts"].get("summary", d["pitch"]))}</p><a href="output/pdf/{d["id"]}.pdf">企画書PDF</a> · <a href="concepts/{d["id"]}.md">編集元</a> · <a href="output/mocks/{d["id"]}-play.html">プレイ画面モック</a> · <a href="output/mocks/{d["id"]}-talk.html">交流画面モック</a></article>' for d in all_data)
    (ROOT/'index.html').write_text(f'''<!doctype html><html lang="ja"><meta charset="utf-8"><meta name="viewport" content="width=device-width"><title>6つのゲーム企画</title><style>body{{font-family:system-ui,sans-serif;background:#f4f0e8;color:#20252c;max-width:1100px;margin:32px auto;padding:0 20px;line-height:1.7}}h1{{font-size:32px}}.grid{{display:grid;grid-template-columns:repeat(auto-fit,minmax(280px,1fr));gap:24px}}article{{background:#fffdf8;padding:20px;border-top:4px solid #b73529}}img{{width:100%;height:auto}}a{{color:#9c3028}}h2{{margin:12px 0 4px}}.intro{{max-width:760px}}</style><h1>6つのゲーム企画</h1><p class="intro">スマホWeb・片手縦持ち・1回10〜20分。ジャンルの掛け算と、成人ヒロインとの濃い交流を比較する企画資料です。掲載画面は未実装のイメージです。</p><p><a href="output/pdf/00-comparison.pdf">最初に比較資料を読む（2ページ）</a></p><div class="grid">{cards}</div></html>''')

def proposals(all_data):
    for d in all_data:
        doc=BaseDocTemplate(str(OUT/f'{d["id"]}.pdf'), pagesize=A4,
                            title=d['title']+' / ゲーム企画書', author='100challenge / Codex',
                            leftMargin=40,rightMargin=40,topMargin=148,bottomMargin=54)
        templates=[]
        for i in range(6):
            frame=Frame(40,54,W-80,H-202,leftPadding=0,rightPadding=0,topPadding=0,bottomPadding=0)
            templates.append(PageTemplate(id=f'chapter-{i}',frames=[frame],
                onPage=lambda c,document,chapter=i:chapter_header(c,document,d,chapter)))
        source_header={**d,'pages':d['pages']+[{'title':'素材と参考作品','lead':'使用候補の素材と、比較のために参照した作品を示します。'}]}
        source_frame=Frame(40,54,W-80,H-202,leftPadding=0,rightPadding=0,topPadding=0,bottomPadding=0)
        templates.append(PageTemplate(id='sources',frames=[source_frame],
            onPage=lambda c,document:chapter_header(c,document,source_header,6)))
        doc.addPageTemplates(templates)
        image=ROOT/'art'/f'{d["id"]}.png'
        story=[]
        for i,p in enumerate(d['pages']):
            if i:
                story.extend([NextPageTemplate(f'chapter-{i}'),PageBreak()])
            if i==0:
                story.extend([paragraph(d['title'],27),paragraph(d['genres'],11,d['accent']),
                    ArtBlock(image,W-80,215),Spacer(1,7),
                    paragraph('左は作品のイメージ、中央はプレイ画面の美術案、右は会話場面です。細かい配置や装備は本文と異なる場合があります。',9,MUTED),
                    paragraph(d['pitch'],11.2)])
            elif i==3:
                profiles=[]
                for h in d['heroes']:
                    profiles.extend([paragraph(f'{h["name"]}（{h["age"]}歳）',12.5,d['accent'],heading=True),
                                     paragraph(h['appearance'],10.7),paragraph(h['dialogue'],10.7)])
                table=Table([[ArtBlock(image,185,250,2),profiles]],colWidths=[200,W-280])
                table.setStyle(TableStyle([('VALIGN',(0,0),(-1,-1),'TOP'),('LEFTPADDING',(0,0),(-1,-1),0),
                    ('RIGHTPADDING',(0,0),(-1,-1),0),('TOPPADDING',(0,0),(-1,-1),0),('BOTTOMPADDING',(0,0),(-1,-1),6)]))
                story.extend([table,Spacer(1,4)])
            elif i==4:
                picture=[ArtBlock(ROOT/'output'/'mocks'/f'{d["id"]}-play-390.png',160,346),Spacer(1,5),paragraph('プレイ画面の例',9.5,MUTED)]
                table=Table([[picture,text_sections(p['sections'][:2],d['accent'])]],colWidths=[185,W-265])
                table.setStyle(TableStyle([('VALIGN',(0,0),(-1,-1),'TOP'),('LEFTPADDING',(0,0),(-1,-1),0),('TOPPADDING',(0,0),(-1,-1),0),('BOTTOMPADDING',(0,0),(-1,-1),8)]))
                story.append(table)
            story.extend(text_sections(p['sections'][2:] if i==4 else p['sections'],d['accent']))
            if i==5:
                story.extend([NextPageTemplate('sources'),PageBreak()])
                story.append(paragraph('以下は2026年10月25日に参照した情報です。素材を採用するときは、配布ファイルに付属する利用条件も確認します。',9.2,MUTED))
                for a in d['assets']:
                    block=[paragraph(a['name']+' / '+a['license']+'。'+a['role'],10.2)]
                    if a['url']:
                        label=escape(a['url'])
                        block.append(Paragraph(f'<link href="{label}" color="#315B82">{label}</link>',style(9.2,'#315B82',14)))
                    block.append(Spacer(1,10));story.append(KeepTogether(block))
                for a in d['comparables']:
                    block=[paragraph('参考作品：'+a['name']+'。'+a['difference'],10.2)]
                    label=escape(a['url'])
                    block.extend([Paragraph(f'<link href="{label}" color="#315B82">{label}</link>',style(9.2,'#315B82',14)),Spacer(1,10)])
                    story.append(KeepTogether(block))
        doc.build(story)


def comparison(all_data):
    c=canvas.Canvas(str(OUT/'00-comparison.pdf'),pagesize=A4)
    c.setTitle('6つのゲーム企画 / ゲーム内容の比較');c.setAuthor('100challenge / Codex')
    introduction='スマートフォンのブラウザで遊ぶ6案です。片手で操作し、1回10〜20分ずつ本編を進める想定です。登場するヒロインは全員成人で、各案に2人います。'
    recommendation='企画者としては「六部屋の約束」を第一候補とします。宿の仕事を一緒に進めることで、経営の判断とヒロインとの会話を結び付けやすいと考えています。実際に面白いかは、試作して確かめる必要があります。'
    for page in range(2):
        c.setFillColor(HexColor(PAPER));c.rect(0,0,W,H,fill=1,stroke=0)
        para(c,'6つのゲーム企画' if page==0 else '6つのゲーム企画（続き）',40,798,W-80,25,INK,34)
        para(c,introduction,40,749,W-80,10.5,MUTED,17)
        for i,d in enumerate(all_data[page*3:page*3+3]):
            y=683-i*190
            art(c,ROOT/'art'/f'{d["id"]}.png',40,y-154,112,145,0,focus=0.62)
            para(c,d['id'][:2]+'  '+d['title'],170,y,W-210,14,d['accent'],21)
            para(c,d['genres'],170,y-27,W-210,10,MUTED,15)
            body=d['facts']['summary']+'\n'+d['facts']['moe']
            bottom=para(c,body,170,y-52,W-210,11,INK,18)
            if bottom<y-185:raise ValueError('Comparison row too long: '+d['id'])
            c.linkURL(d['id']+'.pdf',(40,y-157,W-40,y+4),relative=1,thickness=0)
        para(c,'画像は開発前の画面イメージです。ゲーム本体は、まだ実装していません。' if page==0 else recommendation,40,95,W-80,10.2,MUTED,16)
        c.setFont('JP',8);c.setFillColor(HexColor(MUTED));c.drawString(40,27,'ゲーム企画の比較 / 2026-10-25');c.drawRightString(W-40,27,f'{page+1} / 2');c.showPage()
    c.save()
    text=['# 6つのゲーム企画の比較','',introduction,'']
    for d in all_data:
        text += [f'## {d["title"]}',d['genres'],'',d['facts']['summary'],'',d['facts']['moe'],'']
    text += ['## 最初に試作する案','',recommendation,'','掲載画像は開発前の画面イメージです。実機での操作、長時間のプレイ、素材の量産、開発期間はまだ確認していません。','']
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
