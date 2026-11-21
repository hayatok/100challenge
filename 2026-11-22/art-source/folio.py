"""Build the v0.8 art-department edition from checked-in art and native captures."""
from io import BytesIO
from pathlib import Path
import argparse
from PIL import Image, ImageOps
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.pdfgen.canvas import Canvas
from reportlab.lib.colors import HexColor
from reportlab.lib.utils import ImageReader

ROOT=Path(__file__).resolve().parents[1]
ART=ROOT/"art-source"
LIVE=ROOT/"evidence"
PRINT=ROOT/"Game"/"Assets"/"Resources"/"Art"
W,H=960,632
PAPER="#F3EBDC"; INK="#2C2523"; MUTED="#625348"; RULE="#B6A796"; RED="#853E3D"
def build(out,fonts):
    pdfmetrics.registerFont(TTFont("BookMin",str(fonts/"yumin.ttf")))
    pdfmetrics.registerFont(TTFont("BookGoth",str(fonts/"YuGothM.ttc"),subfontIndex=0))
    c=Canvas(str(out),pagesize=(W,H),pageCompression=1)
    c.setTitle("金星の一夜　美術制作資料 v0.8");c.setAuthor("宵待町 美術制作")
    page=0
    def box(x,y,w,h,colour):
        c.setFillColor(HexColor(colour));c.rect(x,H-y-h,w,h,stroke=0,fill=1)
    def label(x,y,value,size=13,color=INK,font="BookGoth",limit=None):
        if limit:
            assert pdfmetrics.stringWidth(value,font,size)<=limit,(page,value)
        c.setFont(font,size);c.setFillColor(HexColor(color));c.drawString(x,H-y-size,value)
    def pic(path,x,y,w,h,cover=None):
        with Image.open(path) as source: im=source.convert("RGB")
        if cover:
            im=ImageOps.fit(im,(round(w*2),round(h*2)),method=Image.Resampling.LANCZOS,centering=cover)
        else:
            im.thumbnail((round(w*2.5),round(h*2.5)),Image.Resampling.LANCZOS)
        scale=min(w/im.width,h/im.height);iw=im.width*scale;ih=im.height*scale
        stream=BytesIO();im.save(stream,format="JPEG",quality=92,subsampling=0);stream.seek(0)
        c.drawImage(ImageReader(stream),x+(w-iw)/2,H-y-(h+ih)/2,iw,ih)
    def header(title,caption):
        nonlocal page
        page+=1;box(0,0,W,H,PAPER)
        label(34,22,"宵待町　／　金星の一夜",13,RED,"BookMin")
        label(816,22,"美術制作資料　v0.8",11,MUTED)
        box(34,49,892,.8,RULE)
        label(34,64,title,29,INK,"BookMin",890);label(35,112,caption,13,MUTED,limit=890)
        c.bookmarkPage("p"+str(page));c.addOutlineEntry(title,"p"+str(page))
    def end():
        box(34,600,892,.7,RULE);label(35,608,"企画・美術　　Windows 版の制作記録",10,MUTED)
        label(901,605,f"{page:02}",13,RED,"BookMin");c.showPage()
    def cell(path,cap,x,y,w,h):
        box(x,y,w,h,"#271F21");pic(path,x+2,y+2,w-4,h-4)
        label(x,y+h+6,cap,11,INK,limit=w)
    def pair(title,desc,items):
        header(title,desc)
        cell(*items[0],34,151,436,398);cell(*items[1],490,151,436,398);end()
    def three(title,desc,hero,a,b):
        header(title,desc)
        cell(*hero,34,151,488,398);cell(*a,539,151,387,183);cell(*b,539,361,387,188);end()
    def plate(title,desc,path,cap):
        header(title,desc);cell(path,cap,34,146,892,423);end()
    page=1;box(0,0,W,H,"#1D191B");pic(PRINT/"kinsei-key.png",316,0,644,632,(.72,.49))
    box(307,0,3,H,"#AD8C5D");label(34,49,"大阪・宵待町　2026",14,"#D5BD97")
    label(32,144,"金星の一夜",42,"#F6E4BE","BookMin",273)
    label(35,216,"美術制作資料",26,"#F6E4BE","BookMin")
    label(36,289,"原画・造形・Windows 実機",15,"#DDCDBA")
    label(36,328,"v0.1 から v0.8",14,"#DDCDBA")
    box(36,474,228,1,"#886A56")
    label(36,491,"GPT Image　6点",14,"#E5D0AD")
    label(36,518,"ComfyUI・MOSS-Image　66点",14,"#E5D0AD",limit=250)
    label(36,551,"生成72点のうち、美術に70点を採用。",12,"#D3C0AA",limit=263)
    label(36,589,"表紙　GPT Imageによる金星の基準画",11,"#D3C0AA",limit=267)
    c.bookmarkPage("cover");c.addOutlineEntry("金星の一夜　美術制作資料","cover");c.showPage()
    pair("万博のテレビ電話が、町の興行に残った","昭和45年の大阪を起点に、店主が自分の店の客席から金星の舞台へつなぐ町を設計した。",[
        (ART/"atelier/plates/facade.jpg","MOSS原画　キャバレー金星の表構え"),(LIVE/"v04/first-broadcast-joint.png","実機　共同送像所から店の受像機に番組が届く")])
    pair("辰が話す相手を、真壁が地上から確かめる","銅色の上着で辰を見分ける。肩越しでは兄弟の視線と、受像機が肌に返す光を読めるようにした。",[
        (ART/"atelier/plates/table-read.jpg","MOSS原画　二階の席で話す辰と梶"),(LIVE/"v05/mirror-gaze-final-mirror.png","実機　兄弟を結ぶ中継")])
    three("柄の太さに合わせて、親指を曲げる","澄子のスプーンは半径3 mm、村瀬の調整具は半径9 mm。手首から前腕へ続く面と、袖の折り返しを点検した。",
        (ART/"residents/portraits.jpg","3D造形検査　澄子と村瀬の顔・髪"),
        (LIVE/"v051/coffee-release-cycle-detail.png","実機の等倍部分　スプーンとカップ"),
        (LIVE/"v051/operator-release-cycle-detail.png","実機の等倍部分　調整具と白い袖口"))
    three("歌手の顔の横に、実寸のマイクを置く","高さ118.4 mmのヘッドを14部品に分けた。宣材の銘板を下部に貼り、街頭テレビ越しに歌手の顔との比率を確かめた。",
        (ART/"microphone/reference.png","GPT Image　商品撮影風の設計原画"),
        (ART/"microphone/assembly.jpg","3D造形検査　組み立てた状態と分解した状態"),
        (LIVE/"v07/ribbon-surface.png","実機　街頭テレビの舞台中継"))
    three("裏口の写真と札を、路地で読む","真壁は舞台の袖からも入店できる。組員が緑の札を出し、真壁が戸を引くと、通路の奥にホールが見える。",
        (ART/"backstage/studies/alley-evening.jpg","MOSS原画　防音戸と濡れた通路"),
        (LIVE/"v07/costume-surface.png","実機　歌手の宣材写真と衣裳札"),
        (LIVE/"v07/crossing-surface.png","実機　開いている戸を歩いて通る"))
    three("真壁の上着を、肩越しで仕立て直す","濃紺の杉綾に、肩甲骨から脇へ抜ける布の余りを作った。腕を出した側の袖山と裾が引かれる。",
        (ART/"makabe/fitting.jpg","3D造形検査　旧版と新版を同じ姿勢で比較"),
        (ART/"makabe/seams.jpg","3D造形検査　襟と背面のベント"),
        (LIVE/"v08/hand-weave.png","実機　楽屋口で腕を伸ばす真壁"))
    pair("決着した翌朝を、二つの場所で描く","梶と弟が帰った朝は喫茶ロータスを、興行を取り戻した朝は片付けの進む金星を描いた。",[
        (PRINT/"lotus-dawn.png","GPT Image　開店前のロータス"),(PRINT/"kinsei-ledger-dawn.png","GPT Image　興行帳に名前を記す真壁")])
    three("金星の客席で手に取れるもの","舞台の基準画を、客席の張地、壁の印刷、卓上で使う紙の色へ展開した。",
        (PRINT/"kinsei-poster.png","MOSS原画　金星の印刷ポスター"),
        (PRINT/"house-print-atlas.png","GPT Image　マッチ箱・コースター・伝票・菊飾り"),
        (PRINT/"kinsei-oxblood-vinyl.png","MOSS原画　客席の型押しビニール"))
    plate("金星の人物、衣裳、小道具　16点","屋号と印刷面は3D空間に使い、真壁、辰、梶と弟の原画は衣裳と人物の造形に使った。",ART/"atelier/index.jpg","MOSS-Image　金星の美術部")
    plate("三つの商いを一日追う　16点","喫茶ロータス、針音堂、共同送像所を開店から店仕舞いまで描いた。店の札や紙片は実物のサイズで置いた。",ART/"district/index.jpg","MOSS-Image　宵待町の商店")
    plate("棚と機械に仕込む町の印刷物　16点","レコード、瓶ラベル、計器盤を同じ印刷所の仕事として揃えた。読ませる日本語、数値、目盛は別に組んだ。",ART/"printworks/index.jpg","MOSS-Image原画と組版　初校2点を採用から外した")
    pair("窓の奥と夜の空　6点","元の窓ガラスに生活の気配を残し、列車とその向こうの雲を別々に作った。",[
        (ART/"nightscape/index.jpg","MOSS-Image　ガラス4面と夜空2面"),(LIVE/"v03/elevated-train-final.png","実機　高架の二両編成")])
    plate("楽屋口の張地、札、路地の参照画　8点","上段の4面を通路に使った。下段は取手の手擦れ、雨上がりの灯り、出演者の持ち物を決めるための図版。",ART/"backstage/index.jpg","MOSS-Image原画と組版　金星の楽屋口")
    pair("生中継の送出画と受像機","堺の元奏者は、外出できない夜も店に顔を出せる。町で人が中継を使い続ける理由を、受像機の映像で示した。",[
        (PRINT/"sakai-broadcast.png","GPT Image　元奏者の送出画"),(LIVE/"v05/meter-final-light.png","実機　共同送像所の音楽回線とVU計")])
    c.save()
if __name__=="__main__":
    parser=argparse.ArgumentParser()
    parser.add_argument("out",type=Path)
    parser.add_argument("--fonts",type=Path,default=Path("C:/Windows/Fonts"))
    args=parser.parse_args();build(args.out,args.fonts)
