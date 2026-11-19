namespace Evac
{
    internal enum StreetEvent { Bell, Shutter, Lamp, Cart, Water, Points }

    internal sealed class StreetCase
    {
        internal readonly StreetEvent kind;
        internal readonly string objectName, quick, refuge, message;
        internal StreetCase(StreetEvent kind,string name,string quick,string refuge,string message)
        { this.kind=kind;objectName=name;this.quick=quick;this.refuge=refuge;this.message=message; }
    }

    internal static class StreetCases
    {
        const StreetEvent B=StreetEvent.Bell,S=StreetEvent.Shutter,L=StreetEvent.Lamp,C=StreetEvent.Cart,W=StreetEvent.Water,P=StreetEvent.Points;
        internal static readonly StreetCase[][] Operations={
            new[]{
                new StreetCase(B,"店先の呼び鈴","荷受け口を呼ぶ","店内放送を使う","呼び鈴の音を聞き、店の奥から人が出てきた"),
                new StreetCase(S,"勝手口の巻き戸","裏戸を巻き上げる","表通りへ誘導","抜け道の扉が上がり、出口が見えた"),
                new StreetCase(C,"停留所の荷車","荷車で集積所へ","乗り場へ付き添う","荷車を歩けない住民のもとへ寄せた")
            },
            new[]{
                new StreetCase(L,"薬局の非常灯","薬箱に灯りを当てる","避難灯を点ける","暗い調剤室から人の返事が届いた"),
                new StreetCase(S,"西口の防火戸","荷捌き口を開ける","外廊下を通す","西口の戸が動き、二つの出口が使える"),
                new StreetCase(C,"屋台の平台車","台車を引く","店主と支える","屋台の脚を畳み、横になれる場所を作った"),
                new StreetCase(B,"会館の放送器","搬入口へ呼ぶ","玄関へ呼ぶ","館内放送を聞いた住民が階段を下りてきた")
            },
            new[]{
                new StreetCase(P,"荷受けの転線レバー","積込線へ切替","歩廊へ切替","荷受け場の進路表示が変わった"),
                new StreetCase(S,"冷蔵庫の外扉","搬出扉を開ける","前室を経由","冷気が流れ出し、前室に作業員の姿が見えた"),
                new StreetCase(B,"搬入口の呼出ベル","車寄せへ集める","歩道へ分散","誘導員の合図が奥の運転席まで届いた"),
                new StreetCase(C,"桟橋の手押し車","荷台を引き戻す","岸側で引き渡す","外れた車輪が溝に戻った")
            },
            new[]{
                new StreetCase(S,"整備棟の巻き上げ機","作業扉を開ける","側扉を確保","巻き上げ機が動き、工具台の向こうに出口が見えた"),
                new StreetCase(P,"資材庫の分岐台","支柱を送り出す","歩行帯を空ける","支柱の台車が隣のレーンに移った"),
                new StreetCase(L,"仮眠室の枕元灯","名札を照らす","足元を照らす","毛布の間から夜勤者の返事が聞こえた"),
                new StreetCase(B,"北門の構内マイク","通用口へ呼ぶ","詰所へ呼ぶ","北門の構内放送に返事があった"),
                new StreetCase(C,"出荷口の移載台","荷台で搬出","橋の手前で引継","出荷口の移載台に担架を載せられる")
            },
            new[]{
                new StreetCase(P,"改札の行先表示","貨物階段へ切替","改札内を開放","改札の矢印が変わり、乗客が進み始めた"),
                new StreetCase(S,"西階段の仕切り戸","搬送路を開ける","東の踊り場へ","仕切り戸が動き、階段の列が分かれた"),
                new StreetCase(C,"待合室の搬送椅子","椅子を集積所へ","改札で引継","待合室に車輪の付いた椅子が届いた"),
                new StreetCase(L,"機械室の検査灯","電源盤を照らす","出口を照らす","機械室の通路に反射テープが浮かんだ"),
                new StreetCase(W,"東地下道の排水弁","資材側を排水","高い通路へ","排水弁を開ける音が地下道に響いた")
            },
            new[]{
                new StreetCase(W,"入口の逆流弁","低い通路を排水","上段へ迂回","逆流が弱まり、階段の段差が見え始めた"),
                new StreetCase(P,"連絡口の配電台","荷役線に接続","案内灯に接続","連絡口の行先灯に電気が戻った"),
                new StreetCase(S,"商業通路の隔壁","荷捌き口を開ける","連絡階へ逃がす","隔壁の横に避難できる幅ができた"),
                new StreetCase(C,"階段下の搬送台","台車で引き上げる","踊り場で引継","避難階段の下まで搬送台が届いた"),
                new StreetCase(L,"保守通路の作業灯","配線を照らす","路肩を照らす","作業灯に保守員の反射帯が光った"),
                new StreetCase(W,"広場の排水ポンプ","排水して搬出","上階へ誘導","ポンプが水を吸い込み始めた")
            },
            new[]{
                new StreetCase(L,"中継所の信号灯","受信盤を照らす","窓に合図を出す","中継所から点滅で返答があった"),
                new StreetCase(B,"堤防の警鐘","桟橋へ呼ぶ","堤防上へ呼ぶ","河川敷を歩く住民に警鐘が届いた"),
                new StreetCase(C,"観測小屋の荷車","荷車で迎える","堤防で引継","観測小屋の前に荷車を付けた"),
                new StreetCase(W,"艇庫の排水口","桟橋を排水","斜路へ回す","排水口の浮きが下がり始めた"),
                new StreetCase(P,"陸橋下の転轍器","側線へ切替","横断路を固定","車止めの標識が回り、横断方向を示した")
            },
            new[]{
                new StreetCase(P,"基地の進路てこ","積載線へ切替","待機線を開放","基地の進路標識が切り替わった"),
                new StreetCase(B,"待避所の呼出器","整備口へ呼ぶ","待避帯へ呼ぶ","遅れていた一団が呼び声に返事をした"),
                new StreetCase(L,"工場の非常投光器","補給棚を照らす","足場を照らす","暗い構内に古い通路線が現れた"),
                new StreetCase(C,"救護所の搬送車","荷車で後送","車列で引継","救護テントの入り口に搬送車が着いた"),
                new StreetCase(W,"堤防門の排水弁","門前を排水","上の道へ回す","堤防門の水位計が下がり始めた"),
                new StreetCase(S,"終点の車庫扉","車庫扉を開ける","待合へ通す","最後の車庫扉が開き、待合へ人の列が続いた")
            }
        };
    }
}
