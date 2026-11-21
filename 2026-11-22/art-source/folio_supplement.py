"""Make the six-page art supplement. Coordinates are PDF points, measured from top left."""
from pathlib import Path
from io import BytesIO
import argparse,hashlib,json
from PIL import Image
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfgen.canvas import Canvas
from reportlab.lib.utils import ImageReader
from reportlab.lib.colors import HexColor

ap=argparse.ArgumentParser();ap.add_argument('project',type=Path);ap.add_argument('out',type=Path)
ap.add_argument('--fonts',type=Path,default=Path('C:/Windows/Fonts'));ap.add_argument('--overrides',type=Path)
args=ap.parse_args();root=args.project;out=args.out;replace=json.loads(args.overrides.read_text(encoding='utf-8')) if args.overrides else {}
W,H=960,632; bg='#F3EBDC';ink='#2C2523';muted='#625348';red='#853E3D'
for key,file in [('Min','yumin.ttf'),('Goth','YuGothM.ttc')]:
    pdfmetrics.registerFont(TTFont(key,str(args.fonts/file),subfontIndex=0))
c=Canvas(str(out),pagesize=(W,H),pageCompression=1);c.setTitle('金星の一夜　美術制作資料　高架線と翌朝');c.setAuthor('宵待町 美術制作')
used=[]
def txt(x,y,t,size=12,font='Goth',color=ink,maxw=None):
    if maxw:assert pdfmetrics.stringWidth(t,font,size)<=maxw,t
    c.setFont(font,size);c.setFillColor(HexColor(color));c.drawString(x,H-y-size,t)
def rule(y):c.setStrokeColor(HexColor('#B6A796'));c.line(32,H-y,928,H-y)
def start(n,title,sub):
    c.setFillColor(HexColor(bg));c.rect(0,0,W,H,fill=1,stroke=0)
    txt(32,18,'金星の一夜　　宵待町 美術制作資料',12,'Min',red)
    txt(765,19,'高架線と翌朝　／　補遺',12,'Goth',muted);rule(46)
    txt(32,58,title,30,'Min');txt(34,107,sub,13,'Goth',muted,890)
    c.bookmarkPage(str(n));c.addOutlineEntry(title,str(n))
def end(n,foot):
    rule(585);txt(32,598,foot,10,'Goth',muted,844);txt(899,594,f'{n:02}',16,'Min',red);c.showPage()
def fig(tag,source,caption,x,y,w,h,crop=None):
    if tag in replace:
        entry=replace[tag];source=entry['path'];caption=entry['caption'];crop=entry.get('crop')
    p=root/source;im=Image.open(p).convert('RGB')
    if crop:im=im.crop(tuple(int(f*v) for f,v in zip(crop,[im.width,im.height,im.width,im.height])))
    scale=min(w/im.width,h/im.height);iw,ih=im.width*scale,im.height*scale
    im.thumbnail((int(iw*2.8),int(ih*2.8)),Image.Resampling.LANCZOS)
    b=BytesIO();im.save(b,'JPEG',quality=94,subsampling=0);b.seek(0)
    c.drawImage(ImageReader(b),x+(w-iw)/2,H-y-h+(h-ih)/2,iw,ih)
    txt(x,y+h+5,caption,10.2,'Goth',ink,w)
    used.append(dict(figure=tag,file=source,caption=caption,crop=crop,sha256=hashlib.sha256(p.read_bytes()).hexdigest()))
A='art-source/';E='evidence/';G='Game/Assets/Resources/'
start(16,'宵待西口から、送像所前へ','西駅で乗った真壁が、36メートル先の東駅へ着く。車窓を横切るのは、地上から見上げた同じ集合住宅だ。')
fig('rail-study',A+'railway/studies/car-at-night.jpg','MOSS設定画　夜の客室。吊革と窓の上端をそろえた。',32,147,478,359)
fig('rail-inside',E+'v09/saloon-glass.png','Windows実機 v0.9　戸袋と座席に囲まれた乗降口',525,143,403,177)
fig('rail-window',E+'v09/window-glass.png','Windows実機 v0.9　走行中に車窓から見た住宅の窓灯',525,356,403,177)
end(16,'高架線の生成原画は5点。客室と昇降機のほか、路線札・硬券・座席モケットに展開した。')
start(17,'車両の両端で読む、町の四つの広告','針音堂の交換針、共同送像所のテレビ電話、ロータスの珈琲、金星の公開録音。二両の電車の妻壁に1面ずつ掲示した。')
fig('ads',G+'KinseiPrintworks/CarAdvertisements.png','MOSS図案・後組版　車内掲出用の完成原稿。各枠は1024 × 400ピクセル。',32,151,896,369)
end(17,'候補版までの生成累計はGPT Image 8点、MOSS-Image 75点。計83点のうち印刷の初校2点を外し、81点を採用。')
start(18,'澄子から届いた「堺の朝」','共同放送の翌朝、真壁はロータスで依頼を引き受け、送像所へ歩く。送出すると、番組札とVU計の針が演奏を知らせる。')
fig('lotus-study',A+'dawnworld/lotus-request-morning.png','GPT Image設定画　澄子が客席へ依頼札を差し出す。',32,152,502,340)
fig('lotus-work',E+'v010/coffee-joint.png','Windows実機 v0.10　サイフォンの前で手を動かす澄子',548,140,380,182)
fig('joint-signal',E+'v10rc1/live-card-dawnjoint.png','Windows実機 1.0候補　演奏中の番組札とVU計',548,356,380,182)
end(18,'設定画では受け取る客の目線、実機では澄子の作業と送像卓の掲示を記録した。')
start(19,'一番券を預かる針音堂','専属興行の翌朝、真壁は金星の帳場から券を運ぶ。兵藤へ渡すと、手から券が離れ、針音堂が前売りを始める。')
fig('needle-study',A+'dawnworld/needle-first-ticket.png','GPT Image設定画　兵藤が一番券を真鍮皿に収める。',32,150,502,350)
fig('ticket-hand',E+'v010/give-exclusive.png','Windows実機 v0.10・部分　受け渡し直前の真壁の左手',548,140,380,182,(.29,.46,.63,.88))
fig('needle-sale',E+'v10rc1/advance-ticket-dawnexclusive.png','Windows実機 1.0候補　前売り札と皿の一番券',548,356,380,182)
end(19,'実機では帳場で券を受け取り、針音堂のカウンターまで自分で歩いて届ける。')
start(20,'話すときの唇、働くときの手','店主三人の口元を安静と開口で比べる。澄子の唇中央の間隔は、実寸モデルで1.58 mmから7.48 mmへ変わる。')
fig('lips',A+'resident-acting/source-lip-comparison.png','CPU形状図　上から澄子、兵藤、村瀬。各列は同じ顔の状態違い。',32,142,488,385)
fig('acting-live',E+'v10rc1/owner-dawnjoint.png','Windows実機 1.0候補・部分　話しかけた澄子の表情',538,152,390,260,(.21,.14,.77,.86))
txt(539,467,'口元を測る基準は唇中央の縁。',13,'Min');txt(539,491,'店の仕事は手と道具の位置でも読む。',13,'Min')
end(20,'CPU図は造形を同じ条件で比較するための資料。右はロータスの左通路から澄子に話しかけ、その場で撮影した。')
start(21,'石柱の灯と、修理台の管面','西は欄干の両端に乳白ガラスの灯を4基、東は庇の下に直管を2本。作業台の受像機3台に別々の調整信号を入れた。')
fig('canal-live',E+'v10rc1/bridge-nighttrain.png','Windows実機 1.0候補　石柱の灯が欄干と橋面を照らす。',32,143,439,205)
fig('repair-live',E+'v10rc1/repair-nighttrain.png','Windows実機 1.0候補　庇の直管と修理中の受像機',489,143,439,205)
fig('canal-geometry',E+'v10rc1/bridge-dawnjoint.png','Windows実機 1.0候補　翌朝の欄干と石柱',32,387,439,145)
fig('repair-geometry',E+'v10rc1/repair-dawnjoint.png','Windows実機 1.0候補　翌朝の作業台',489,387,439,145)
end(21,'上段は夜、下段は共同放送の翌朝。同じ場所と方角で街路灯と作業灯の状態を比べた。')
start(22,'七三の分け目から、耳の後ろへ','真壁の左の分け目から頭頂を横切り、耳際と襟足へ毛束を流した。車内の暗い背景でも、耳輪に沿って生え際が見える。')
fig('groom-geometry',A+'makabe-groom/comparison.png','CPU形状図　上段が旧髪型、下段が新髪型。耳際・襟足・分け目の順。',32,142,529,352)
fig('groom-live',E+'v10/other-ads-firstcar.png','Windows実機 v1.0・部分　車内で見る右耳と襟足',578,146,350,330,(.07,.21,.49,.84))
end(22,'単体比較は同じ頭部・同じ照明。新しい髪は、頭皮に沿う土台と110本の立体の毛束で構成した。')
start(23,'十八メートルの壁に突板を割り付ける','金星の奥壁は幅18 m。突板を33列・3段に割り付け、木目の長さを一反復80 cmに戻した。階段は踏板の幅に沿う横目にした。')
fig('wood-geometry',A+'cabinetry/comparison.jpg','CPU材質図　左が旧UV、右が新UV。上から客席奥壁・店の腰板・踏板。',32,143,512,369)
fig('wood-live',E+'v10/west-lane-nighttrain.png','Windows実機 v1.0・部分　楽屋通路の縦目と継ぎ目',561,145,367,332,(.45,.12,.99,.85))
end(23,'板の目地は幅2.2 mm、深さ1.5 mm。CPU図は同じウォルナットの拡散色を、旧・新のUVで読み出して比較した。')
c.save();out.with_suffix('.sources.json').write_text(json.dumps(used,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
