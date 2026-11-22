"""Make the art supplement. Coordinates are PDF points, measured from top left."""
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
    txt(765,19,'雨上がりの通り　／　補遺' if n>=37 else '運河橋と西の湯　／　補遺' if n>=34 else 'ホールと実況卓　／　補遺' if n>=31 else '舞台と町内中継　／　補遺' if n>=27 else '高架線と翌朝　／　補遺',12,'Goth',muted);rule(46)
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
start(24,'舞台前の静けさを、二つの距離から','立会人がピアノ脇に着いた。舞台の下に真壁、上には白服の兄貴分。左手を差し出す同じ瞬間を、二つの設定画に描いた。')
fig('club-overlook',A+'club-two-views/stage-overlook.png','GPT Image設定画　指揮の引き。舞台右袖に立会人、右奥に二階桟敷。',32,155,440,319)
fig('club-shoulder',A+'club-two-views/stage-shoulder.png','GPT Image設定画　真壁の肩越し。兄貴分の左手と袖の立会人。',488,155,440,319)
end(24,'肩越しの原画には先に作った引きの原画を参照。段差、電球、舞台左手前の受像機を両方の視点で追える。')
start(25,'一番券が、金星の帳場から出る','左手につままれる紙の角から発券機を設計した。幅87 mmの券に対して左右のガイドの内幅は95 mm、片側の余裕は4 mm。')
fig('press-study',A+'ticket-and-car/ticket-pickup.png','GPT Image設定画　親指と人差し指が紙の同じ角を挟む。',32,145,475,336)
fig('press-cpu',A+'ticket-machine/press-inspection.png','CPU形状図　番号窓と出口。右は券を通した状態。',524,144,404,143)
fig('press-issued',E+'v12/issued-ticket.png','Windows実機 v1.2初版・部分　排出口を通った一番券',524,335,404,195,(.13,.14,.86,.86))
end(25,'CPU形状検査では126 mmの送り区間と交差する三角形は0。実機では番号窓の下から「0001」の一枚が出る。')
start(26,'側灯をひとつ、耳の高さへ','暗い車窓を残しながら、頬と耳の縁を見せたい。右の二枚は西駅から乗った第1車両で、同じ向きへ振り返った真壁。')
fig('coach-study',A+'ticket-and-car/car-sidelight.png','GPT Image設定画　耳の縁、こめかみの櫛目、後頭部の影。',32,145,465,343)
fig('coach-before',E+'v10/saloon-firstcar.png','Windows実機 v1.0・部分　左の窓を背にした横顔',511,141,417,174,(.18,.19,.72,.85))
fig('coach-after',E+'v11/saloon-occupied.png','Windows実機 v1.1直前版・部分　横灯が拾う頬と耳前の毛筋',511,353,417,174,(.18,.19,.72,.85))
end(26,'実機写真は同じ割合で切り出した。照明後は1.1最終版と車両コードが共通のb35ab7版で撮影。')
start(27,'扇の九枚を、客席の奥から読む','俯瞰の原画で、扇は兄貴分の立つ舞台の目印だった。金文字の正面を36度起こし、指揮視点からも「金星」の二字を追えるようにした。')
fig('club-fan-overlook-study',A+'club-two-views/stage-overlook.png','GPT Image設定画　先に制作した客席からの俯瞰',32,141,368,175)
fig('club-fan-geometry',A+'stage-broadcast/geometry.jpg','CPU形状図　客席側10度／指揮視点58.6度',32,365,368,157)
fig('club-fan-overlook-live',E+'v13/desk-air.png','Windows実機 v1.3　指揮視点から見た舞台と見物位置',420,146,508,303)
txt(421,494,'扇縁には乳白球が27灯、舞台の框には15灯。',13,'Min')
txt(421,519,'二列の灯で舞台奥と演者の足元を分ける。',13,'Min')
end(27,'扇板、縁金、ガラス、文字の厚みを別々に造形した。CPU図は二方向の正投影、右はゲーム内のカメラによる撮影。')
start(28,'肩の向こうの文字から、卓の管面へ','引きの原画を参照して、同じ舞台を真壁の肩越しに描いた。実機で卓をのぞくと、管面に兄貴分の白服とマイクが映る。')
fig('club-fan-shoulder-study',A+'club-two-views/stage-shoulder.png','GPT Image設定画　二枚目の肩越し。左手前が真壁。',32,141,382,194)
fig('club-desk-live',E+'v13/voice-end-air.png','Windows実機 v1.3・部分　卓の管面に映る兄貴分とマイク',32,376,382,153,(.10,.18,.91,.84))
fig('club-fan-shoulder-live',E+'v13/mic-hint-air.png','Windows実機 v1.3　真壁の肩越しに見た舞台',435,142,493,216)
fig('club-desk-post',E+'v13/mic-hint-air.png','同じ肩越し画面の部分　袖の見物人と実況卓に着いた係員',435,387,493,143,(.67,.36,.998,.84))
end(28,'舞台の再設計に使用した原画は24頁と同じ二点。Windows版の撮影元ZIPのSHA-256は補遺の出典目録に収録。')
for entry in used:
    if entry['file'].startswith('evidence/v13/'):
        entry['windows_zip_sha256']='dff59edd83b40bfc27ce51c1d9d223df9ef5aa6932a9750fc352bc1429202d04'
start(29,'送出つまみに、指が掛かる','原画では係員が右手を使う。実機の卓では、係員から見て右に管面、左に横並びのつまみが二つあり、左手で白い指掛けを回す。')
fig('level-hand-study',A+'broadcast-listeners/desk-hand.png','GPT Image原画　管面の右に縦に並ぶつまみ。右手で下の一つを回す。',32,149,448,337)
fig('level-hand-contact',E+'v13/rotation-dial.png','Windows実機 v1.3・部分　Cを押したまま見た源の左手と白い指掛け',502,143,426,177,(.19,.20,.79,.73))
fig('level-hand-released',E+'v13/release-dial.png','Windows実機 v1.3・同じ範囲　左手が離れ、指掛けの向きが見える。',502,354,426,177,(.19,.20,.79,.73))
end(29,'右の上下は同じ接写位置・同じ切り出し。手の甲が指先の一部を隠すため、手を引いた後の白い指掛けも並べた。')
start(30,'金星の声が届く、喫茶ロータス','カップに手を添えた店の人と、カウンターの常連が、右上の受像機へ顔を向ける。画面の中では兄貴分がマイクに向かっている。')
fig('lotus-listens-study',G+'Art/lotus-listens.png','GPT Image原画・全体　カウンター越しの二人と、壁掛けの受像機',32,145,437,322)
fig('lotus-broadcast-result',E+'v13/result-dial.png','Windows実機 v1.3・全画面　町内中継の決着「金星から町内へ」',488,145,440,322)
txt(33,504,'手元のカップと上向きの横顔が、テレビへ目を導く。',12,'Min')
txt(489,504,'左の暗部に結末と帳面を置き、右上の受像機を残した。',12,'Min')
end(30,'結果画面の左下には次の一夜と表題へ戻る操作が並ぶ。原画と実機で、テレビの中の人物とカウンターの二人を見比べられる。')
for entry in used:
    if entry['figure'] in ('level-hand-contact','level-hand-released','lotus-broadcast-result'):
        entry['windows_zip_sha256']='101235869c7ac3fb34280157968a6207cea12907b213e370de69bf39b04fa1ed'
start(31,'紺谷と浦、立ち姿から片膝へ','紺谷は細い縞の紺背広に眼鏡、浦は桑色の上着にチーフ。まず立ち姿で二人を描き分け、紺谷の降参を三コマに起こした。')
fig('hall-wardrobe-study',A+'hall-regulars/wardrobe.png','GPT Image 衣装原画　左に紺谷、右に浦。',32,139,435,231)
fig('hall-wardrobe-model',A+'hall-regulars/tailoring-offline.png','衣装モデルのオフライン描画　同じ二着を並べた。',504,139,424,231)
fig('hall-yield-study',A+'hall-regulars/kontani-movement.png','GPT Image 動作原画　紺谷が右足を踏み出し、左膝をつくまで。',32,400,505,152)
fig('hall-cuffs-study',A+'hall-regulars/ura-cuffs.png','GPT Image 接写原画　浦が上げた掌と、膝に置く手の袖口。',558,400,370,152)
end(31,'右上は書き出した衣装データをBlenderで描画したもの。頭部・眼鏡・手と、舞台の照明は実機の頁に収録した。')

start(32,'実況卓の黒と金を、四つの面に分ける','黒い琺瑯の前板と上蓋には別の原画を使った。つまみの正面は同心円の旋削痕、周面は指が擦った横帯で区別する。')
fig('hall-enamel-a',A+'broadcast-console/originals/enamel-a.png','MOSS原画　前板の塗り欠け',32,144,211,110)
fig('hall-enamel-b',A+'broadcast-console/originals/enamel-b.png','MOSS原画　上蓋と左右の返し',258,144,211,110)
fig('hall-brass-a',A+'broadcast-console/originals/brass-a.png','MOSS原画　つまみの正面',491,144,211,110)
fig('hall-brass-b',A+'broadcast-console/originals/brass-b.png','MOSS原画　つまみの周面',717,144,211,110)
fig('hall-console-model',A+'broadcast-console/console-geometry.jpg','実装メッシュのCPU描画　操作側と管面側。指掛けと管面の縁を、それぞれの角度から見る。',32,302,896,238)
end(32,'筐体は幅560 × 高さ160 × 奥行190 mm。つまみの直径は46 mm。周面36本の溝は形状で刻み、指掛けと軸が68度回る。')

start(33,'客席の二人と、送出卓の左手','客席中央でZを押し、降参した二人を順に見た。舞台袖ではCを押し、実況卓についた源が左手で送出つまみを回す様子を撮った。')
fig('hall-kontani-live',E+'v14/kontani-view-published.png','Windows実機 v1.4・Z視点　眼鏡の紺谷が左の掌を上げる。',32,144,436,220)
fig('hall-ura-live',E+'v14/ura-view-published.png','Windows実機 v1.4・Z視点　桑色の上着で片膝をつく浦。',492,144,436,220)
fig('hall-console-live',E+'v14/rotation-pubdesk.png','Windows実機 v1.4・C視点の部分　琺瑯の前板と源の左手',32,399,531,149,(.19,.2,.79,.73))
txt(589,421,'つまみを回す',19,'Min')
txt(589,459,'Cを保持すると、源の左手が白い指掛けに届く。',12,'Goth',ink,345)
txt(589,485,'左のつまみには、明るい縦溝が並ぶ。',12,'Goth',ink,345)
end(33,'上段はホール、下段は舞台袖の実況卓。図版ごとの撮影元ZIPと、切り出す前の画像のSHA-256は出典目録に収録した。')
console_runs={record['name']:record for record in json.loads((root/A/'broadcast-console/originals/runs.json').read_text(encoding='utf-8'))}
for entry in used:
    tag=entry['figure']
    if tag in ('hall-wardrobe-study','hall-yield-study'):
        entry['source_kind']='GPT Image concept'
        entry['prompt_file']=A+'hall-regulars/'+('prompt.txt' if tag=='hall-wardrobe-study' else 'movement-prompt.txt')
    elif tag=='hall-cuffs-study':
        entry.update(source_kind='GPT Image concept',prompt_file=A+'hall-regulars/cuffs-prompt.txt')
    elif tag in ('hall-enamel-a','hall-enamel-b','hall-brass-a','hall-brass-b'):
        record=console_runs[tag.removeprefix('hall-')]
        assert entry['sha256']==record['sha256'],tag
        entry.update(source_kind='MOSS-Image material study',prompt_id=record['prompt_id'],seed=record['seed'])
    elif tag in ('hall-wardrobe-model','hall-console-model'):
        entry['source_kind']='Offline rendering of model geometry'
    elif tag in ('hall-kontani-live','hall-ura-live','hall-console-live'):
        entry.update(source_kind='Windows Player capture',windows_zip_sha256='b0c1e4f5898e12341041d8da682a8ad4a5a36bffde2129734320023eb1759eaf')
start(34,'運河橋を渡って、西の湯へ','橋の先に葡萄色の暖簾と青緑の袖壁が見える。原画では入口の右にあった受像機が、実機では左の壁に収まり、金星の舞台を映す。')
fig('west-front-study',A+'west-bath/bath-frontage.png','GPT Image 全景原画　暖簾の下に二人の湯客。二階にも明かりがともる。',32,164,487,274)
fig('west-bridge-live',E+'v15/bridge-west15.png','Windows実機 v1.5　親柱の間から西岸の浴場を見る。',541,139,387,180)
fig('west-front-live',E+'v15/bath-front-west15.png','Windows実機 v1.5　外壁の受像機、暖簾、牛乳箱。',541,361,387,180)
txt(33,490,'湯客を迎える入口',19,'Min')
txt(33,525,'親柱に残る淡い石の色と、暖簾の白い「ゆ」を両方の画面で追える。',12,'Goth',ink,496)
end(34,'左は舞台美術を決めるための原画。右は西橋の歩行経路と、実際に立ち寄れる銭湯の正面。')

start(35,'玄関の釉薬、橋の骨材、暖簾の織り','玄関の焼き物、橋の石、暖簾の布、足元のゴム。さらに脱衣場への戸四枚と番台窓には、葉脈のような筋が流れる型板ガラスを使った。')
for key,caption,x in [('Tile','青緑の釉薬',32),('Terrazzo','洗い出し石の骨材',214),('Noren','葡萄色の木綿',396),('Mat','ゴムの畝',578),('Glass','型板ガラス',760)]:
    fig('west-moss-'+key,A+'west-bath/materials/'+key+'.png','MOSS 素材原画　'+caption,x,144,168,151)
fig('west-curtain-live',E+'v15/curtains-west15.png','Windows実機 v1.5・部分　壁の目地と、三枚の布にまたがる「ゆ」。',32,337,438,204,(.05,.14,.95,.86))
fig('west-lobby-live',E+'v15/lobby-west15.png','Windows実機 v1.5　戸の型板ガラスと、靴を収めた番号付きの下足箱。',491,337,437,204)
end(35,'原画はそれぞれ1024角。実装用の色画像は原本の両端40ピクセルをなじませ、反復したときの境目を抑えた。')

start(36,'湯籠を提げる文子と、洗面器を持つ喜一','文子は深緑のカーディガンに籐籠、喜一は茶の作業着に薄青の洗面器。西岸で二人を引き留める瀬尾には、オリーブがかった背広を着せた。')
fig('west-cast-study',A+'west-bath/residents-and-seo.png','GPT Image 衣装原画　左から文子、喜一、瀬尾。',32,152,491,286)
fig('west-guests-live',E+'v15/cast-side-west15.png','Windows実機 v1.5・部分　喜一の洗面器と文子の籐籠。',540,142,388,195,(.27,.13,.89,.92))
fig('west-crossing-live',E+'v15/bridge-walk-b-title15.png','Windows実機 v1.5・部分　橋を渡る二人。瀬尾は奥の西岸に残る。',540,372,388,177,(0,.11,.74,.94))
txt(33,491,'手と持ち物',18,'Min')
txt(33,523,'文子の右手から籠が下がり、喜一の左手が洗面器の縁を支える。',12,'Goth',ink,505)
end(36,'衣装は三人の体に合わせて仕立てたスキンメッシュ。籠にはタオルと石鹸箱、洗面器には折ったタオルを入れた。')

for entry in used:
    tag=entry['figure']
    if tag in ('west-front-study','west-cast-study'):
        prompt='frontage-prompt.txt' if tag=='west-front-study' else 'cast-prompt.txt'
        entry.update(source_kind='GPT Image concept',prompt_file=A+'west-bath/'+prompt)
    elif tag.startswith('west-moss-'):
        record=json.loads((root/entry['file']).with_suffix('.json').read_text(encoding='utf-8'))
        assert entry['sha256']==record['sha256'],tag
        entry.update(source_kind='MOSS-Image material master',prompt_id=record['prompt_id'],seed=record['seed'])
    elif tag.startswith('west-') and tag.endswith('-live'):
        entry.update(source_kind='Windows Player capture',windows_zip_sha256='f03c934064a9c03af6827df845f6e6f617ca05dd1bf4e3ea4ac3c6dd5a1d68db')

start(37,'庇の灯から、街頭テレビの逆像へ','靴の高さから見た原画では、庇の灯が濡れた舗装に伸びる。実機の金星前では、テレビ下部の明るい縁と選局器が水面に逆さに映る。')
fig('rain-shoes-study',A+'rain-street/street-at-shoe-level.png','GPT Image 照明原画　靴、さざ波、庇の電球。',32,144,455,310)
fig('rain-reflection-live',E+'v16/water-pixel1080.png','Windows実機 v1.6　足元の水に映る受像機の下縁。',515,144,413,310)
txt(33,495,'庇の黄、受像機の緑',18,'Min')
txt(33,527,'右の画面では、歩道の手前で水面の明かりが途切れる。',12,'Goth',ink,650)
end(37,'左は雨上がりの路面のための原画。右はゲーム内のカメラで撮影した通り。')

start(38,'骨材の山と、水の寄るくぼみ','路面を三つに分けて作った。骨材の粒、先に乾く高い部分、水面に残る細い波。')
for key,caption,x in [('Asphalt','舗装の骨材',32),('Basin','水のくぼみ',193),('Ripple','細かなさざ波',354)]:
    fig('rain-moss-'+key,A+'rain-street/'+key+'.png','MOSS 素材原画　'+caption,x,153,145,145)
fig('rain-people-live',E+'v16/second3-pixel1080.png','Windows実機 v1.6・部分　脚の逆像が選局器の手前に重なる。',522,145,406,327,(850/1920,570/1080,1350/1920,850/1080))
txt(33,363,'路面を読む三枚',18,'Min')
txt(33,402,'幅26センチ分の骨材が、水際を小さく割る。',12,'Goth',ink,464)
txt(33,428,'細かな波は、幅12センチ分の水面から起こした。',12,'Goth',ink,464)
end(38,'三枚の表面原本は各1024角。右の水面には赤茶のズボンが二筋映る。靴先だけの像はこの切り出しでは読み分けにくい。')

start(39,'街頭の受像機に、金星の舞台が映る','筐体を包む象牙色の琺瑯と、保護桟の奥の濃茶の織布。原画のある晩の光景から、受像機の前に立ったときに見える面を拾う。')
fig('rain-receiver-study',A+'rain-street/street-receiver.png','GPT Image 受像機原画　放送に見入る二人。',32,143,449,230)
fig('rain-receiver-live',E+'v16/dial-pixel1080.png','Windows実機 v1.6・C視点　管面と、その下の選局器・保護桟。',508,143,420,230)
for key,caption,x in [('Enamel','焼付琺瑯',32),('Grille','スピーカーの織布',255)]:
    fig('rain-moss-'+key,A+'rain-street/'+key+'.png','MOSS 素材原画　'+caption,x,407,206,132)
txt(508,423,'管面の下',18,'Min')
txt(508,462,'二つの丸いつまみの右に、横向きの保護桟が並ぶ。',12,'Goth',ink,415)
txt(508,492,'その右端にチャンネルの「3」が灯る。',12,'Goth',ink,415)
end(39,'左下は筐体と切替器のケースに使った塗膜、右隣はスピーカーを覆う布。')



for entry in used:
    tag=entry['figure']
    if tag in ('rain-shoes-study','rain-receiver-study'):
        prompt='street-prompt.txt' if tag=='rain-shoes-study' else 'receiver-prompt.txt'
        entry.update(source_kind='GPT Image concept',prompt_file=A+'rain-street/'+prompt)
    elif tag.startswith('rain-moss-'):
        record=json.loads((root/entry['file']).with_suffix('.json').read_text(encoding='utf-8'))
        assert record['sha256']==entry['sha256'],tag
        entry.update(source_kind='MOSS-Image material master',prompt_id=record['prompt_id'],seed=record['seed'])
    elif tag.startswith('rain-') and tag.endswith('-live'):
        entry.update(source_kind='Windows Player capture',windows_zip_sha256='4e6a1eef3a0d9ce8eabceb23a4e2cd774f3d5da32096dbe7a16499214167aba9')

c.save();out.with_suffix('.sources.json').write_text(json.dumps(used,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
